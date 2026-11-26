"""Event-driven kernel/systemd readiness engine (zero time.sleep polling).

Architecture (mediNix ADR-0010 / Task R98):
  1. Immediate non-blocking `selectors.EpollSelector` probe across all targets in parallel.
  2. For targets not yet listening (`ECONNREFUSED`), parks in `epoll_wait()` with 0% CPU
     and zero `time.sleep()`, woken in <1ms by:
       a) `JournalEventSource`: non-blocking pipe from `journalctl --follow --output=json`
          watching unit readiness lines (e.g. Kestrel "Now listening on:", SABnzbd
          "Starting web-interface", Seerr "Server ready") AND fail-fast crash events.
       b) `SignalWakeupPipe`: `signal.set_wakeup_fd` pipe registered in the same `epoll`
          reactor for instant `SIGINT`/`SIGTERM` cancellation.
       c) Adaptive monotonic-deadline safety guard inside `epoll.select(timeout=...)`
          (sparse 2.5s..5s safety net when journal stream is active; 50ms..1s exponential
          backoff fallback only when journal stream is unavailable, e.g. dev/tests).
"""

from __future__ import annotations

import dataclasses
import enum
import errno
import json
import logging
import os
import re
import selectors
import signal
import socket
import subprocess
import threading
import time
from collections.abc import Iterable, Mapping, Sequence
from typing import Any

logger = logging.getLogger(__name__)

# Default application readiness patterns emitted to systemd-journald.
DEFAULT_READY_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"Now listening on:\s*https?://", re.IGNORECASE),
    re.compile(r"Application started\.", re.IGNORECASE),
    re.compile(r"Starting web-interface on", re.IGNORECASE),
    re.compile(r"Server ready on", re.IGNORECASE),
    re.compile(r"Listening on\s+(?:http|port)", re.IGNORECASE),
    re.compile(r"Main:\s+Startup complete", re.IGNORECASE),
    re.compile(r"^Started\s+.+\.service", re.IGNORECASE),
)

# Reset-pattern: if a unit restarts in the same journal replay batch, earlier failure lines are stale.
_START_RESET_RE = re.compile(r"^Starting\s+", re.IGNORECASE)

# Fail-fast patterns: abort waiting immediately if a target unit crashes.
DEFAULT_FAIL_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"Failed with result\s+'[^']+'", re.IGNORECASE),
    re.compile(r"Main process exited,\s*code=(?:exited|killed|dumped)", re.IGNORECASE),
    re.compile(r"Hosting failed to start", re.IGNORECASE),
    re.compile(r"Unhandled exception\.", re.IGNORECASE),
)

_HTTP_STATUS_LINE_RE = re.compile(rb"^HTTP/1\.[01]\s+(\d{3})\b")
_MAX_HEADER_BYTES = 16384


class ReadinessStatus(enum.Enum):
    """Outcome of waiting for a target."""

    READY = "ready"
    TIMEOUT = "timeout"
    UNIT_FAILED = "unit_failed"
    HTTP_REJECTED = "http_rejected"
    ABORTED = "aborted"


@dataclasses.dataclass(frozen=True, slots=True)
class ReadinessTarget:
    """Declarative readiness specification for a single local service."""

    name: str
    host: str = "127.0.0.1"
    port: int = 0
    path: str = "/"
    headers: Mapping[str, str] = dataclasses.field(default_factory=dict)
    expected_statuses: frozenset[int] = frozenset(range(200, 400))
    fail_statuses: frozenset[int] = frozenset()
    systemd_unit: str | None = None
    probe_http: bool = True
    ready_patterns: tuple[re.Pattern[str], ...] = DEFAULT_READY_PATTERNS
    fail_patterns: tuple[re.Pattern[str], ...] = DEFAULT_FAIL_PATTERNS

    def __post_init__(self) -> None:
        if not 1 <= self.port <= 65535:
            raise ValueError(f"Invalid port for target {self.name!r}: {self.port}")
        if "\r" in self.path or "\n" in self.path:
            raise ValueError(f"Invalid path for target {self.name!r}")
        for k, v in self.headers.items():
            if any(c in str(k) + str(v) for c in ("\r", "\n")):
                raise ValueError(f"CRLF injection in header {k!r} for target {self.name!r}")


@dataclasses.dataclass(frozen=True, slots=True)
class ReadinessResult:
    """Result record for a readiness check."""

    name: str
    status: ReadinessStatus
    elapsed_ms: float
    attempts: int
    trigger: str
    http_status: int | None = None
    detail: str = ""

    @property
    def ok(self) -> bool:
        return self.status is ReadinessStatus.READY


class _Phase(enum.Enum):
    WAIT_EVENT = "wait_event"
    CONNECTING = "connecting"
    SENDING = "sending"
    READING = "reading"
    DONE = "done"


@dataclasses.dataclass(slots=True)
class _TargetState:
    target: ReadinessTarget
    addr_info: tuple[int, int, int, str, tuple[Any, ...]]
    phase: _Phase = _Phase.WAIT_EVENT
    status: ReadinessStatus | None = None
    sock: socket.socket | None = None
    send_buf: bytes = b""
    send_offset: int = 0
    recv_buf: bytearray = dataclasses.field(default_factory=bytearray)
    attempts: int = 0
    backoff_idx: int = 0
    next_probe_at: float = 0.0
    io_deadline: float = 0.0
    trigger: str = "initial-probe"
    last_http_status: int | None = None
    detail: str = ""


class _SignalWakeupPipe:
    """Registers signals with installed Python handlers into epoll via set_wakeup_fd."""

    def __init__(self, selector: selectors.BaseSelector) -> None:
        self._selector = selector
        self._r_fd: int | None = None
        self._w_fd: int | None = None
        self._prev_wakeup_fd: int = -1
        self._active = False
        self.triggered_signal: int | None = None

    def __enter__(self) -> _SignalWakeupPipe:
        if threading.current_thread() is not threading.main_thread():
            return self
        r_fd, w_fd = os.pipe2(os.O_NONBLOCK | os.O_CLOEXEC)
        try:
            self._prev_wakeup_fd = signal.set_wakeup_fd(w_fd, warn_on_full_buffer=False)
        except (ValueError, OSError):
            os.close(r_fd)
            os.close(w_fd)
            return self
        self._r_fd = r_fd
        self._w_fd = w_fd
        self._active = True
        self._selector.register(r_fd, selectors.EVENT_READ, data=("signal", None))
        return self

    def drain(self) -> int | None:
        if self._r_fd is None:
            return None
        try:
            data = os.read(self._r_fd, 64)
        except BlockingIOError:
            return None
        if data:
            self.triggered_signal = data[-1]
            return self.triggered_signal
        return None

    def __exit__(self, *_: object) -> None:
        if not self._active:
            return
        if self._r_fd is not None:
            try:
                self._selector.unregister(self._r_fd)
            except (KeyError, ValueError):
                pass
        try:
            signal.set_wakeup_fd(self._prev_wakeup_fd)
        except (ValueError, OSError):
            pass
        for fd in (self._r_fd, self._w_fd):
            if fd is not None:
                try:
                    os.close(fd)
                except OSError:
                    pass
        self._active = False


class JournalEventSource:
    """Non-blocking `journalctl --follow --output=json` stream plugged into epoll."""

    def __init__(
        self,
        units: Sequence[str],
        *,
        journalctl_bin: str = "journalctl",
        history_lines: int = 20,
        cmd_override: Sequence[str] | None = None,
    ) -> None:
        self._units = tuple(dict.fromkeys(u for u in units if u))
        self._journalctl_bin = journalctl_bin
        self._history_lines = history_lines
        self._cmd_override = list(cmd_override) if cmd_override is not None else None
        self._proc: subprocess.Popen[bytes] | None = None
        self._buf = bytearray()
        self._fd: int | None = None
        self.active = False

    @property
    def fd(self) -> int | None:
        return self._fd

    def start(self, selector: selectors.BaseSelector) -> bool:
        if not self._units and self._cmd_override is None:
            return False
        if self._cmd_override is not None:
            cmd = self._cmd_override
        else:
            cmd = [
                self._journalctl_bin,
                "--follow",
                "--output=json",
                f"--lines={self._history_lines}",
                "--no-pager",
            ]
            for unit in self._units:
                cmd.extend(["-u", unit])

        try:
            self._proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                bufsize=0,
            )
        except OSError as exc:
            logger.debug("Journal stream unavailable (%s); using adaptive epoll timers", exc)
            return False

        assert self._proc.stdout is not None
        fd = self._proc.stdout.fileno()
        os.set_blocking(fd, False)
        self._fd = fd
        self.active = True
        selector.register(fd, selectors.EVENT_READ, data=("journal", self))
        logger.debug("Subscribed to journald stream for units: %s", ", ".join(self._units))
        return True

    def read_events(self, selector: selectors.BaseSelector) -> list[tuple[set[str], str, int | None]]:
        """Drain available JSON log lines and return [(unit_names, message, realtime_us), ...]."""
        if self._fd is None:
            return []
        events: list[tuple[set[str], str, int | None]] = []
        eof = False

        while True:
            try:
                chunk = os.read(self._fd, 8192)
            except BlockingIOError:
                break
            except OSError:
                eof = True
                break
            if not chunk:
                eof = True
                break
            self._buf.extend(chunk)

        while True:
            nl = self._buf.find(b"\n")
            if nl == -1:
                break
            raw_line = bytes(self._buf[:nl]).strip()
            del self._buf[: nl + 1]
            if not raw_line:
                continue
            parsed = self._parse_record(raw_line)
            if parsed is not None:
                events.append(parsed)

        if eof:
            self.close(selector)
        return events

    @staticmethod
    def _parse_record(raw_line: bytes) -> tuple[set[str], str, int | None] | None:
        try:
            rec = json.loads(raw_line.decode("utf-8", errors="replace"))
        except json.JSONDecodeError:
            return None
        if not isinstance(rec, dict):
            return None

        units: set[str] = set()
        for key in ("_SYSTEMD_UNIT", "UNIT", "USER_UNIT"):
            val = rec.get(key)
            if isinstance(val, str) and val:
                units.add(val)

        ts_raw = rec.get("__REALTIME_TIMESTAMP")
        realtime_us: int | None = None
        if isinstance(ts_raw, (str, int)):
            try:
                realtime_us = int(ts_raw)
            except ValueError:
                realtime_us = None

        msg_raw = rec.get("MESSAGE", "")
        if isinstance(msg_raw, list):
            msg = bytes(b for b in msg_raw if isinstance(b, int) and 0 <= b <= 255).decode(
                "utf-8", errors="replace"
            )
        else:
            msg = str(msg_raw)
        return units, msg, realtime_us

    def close(self, selector: selectors.BaseSelector | None = None) -> None:
        if self._fd is not None and selector is not None:
            try:
                selector.unregister(self._fd)
            except (KeyError, ValueError):
                pass
        self._fd = None
        self.active = False
        if self._proc is not None:
            stderr_msg = ""
            if self._proc.poll() is None:
                self._proc.terminate()
                try:
                    self._proc.wait(timeout=1.0)
                except subprocess.TimeoutExpired:
                    self._proc.kill()
                    self._proc.wait(timeout=1.0)
            else:
                if self._proc.stderr is not None:
                    try:
                        stderr_msg = self._proc.stderr.read().decode("utf-8", errors="replace").strip()
                    except OSError:
                        pass
            if stderr_msg:
                logger.debug("journalctl stream closed: %s", stderr_msg)
            for pipe in (self._proc.stdout, self._proc.stderr):
                if pipe is not None:
                    try:
                        pipe.close()
                    except OSError:
                        pass
            self._proc = None


# Backoff ladders (seconds). Zero time.sleep(): scheduled as monotonic deadlines in epoll_wait.
_JOURNAL_SAFETY_INTERVALS = (2.5, 4.0, 5.0)
_FALLBACK_INTERVALS = (0.05, 0.1, 0.2, 0.35, 0.5, 1.0)
_HTTP_WARMUP_INTERVALS = (0.15, 0.3, 0.5, 1.0)


def _create_selector() -> selectors.BaseSelector:
    epoll_cls = getattr(selectors, "EpollSelector", None)
    if epoll_cls is not None:
        return epoll_cls()
    return selectors.DefaultSelector()


def _build_http_probe_request(target: ReadinessTarget) -> bytes:
    host_clean = target.host.strip("[]")
    host_hdr = f"[{host_clean}]" if ":" in host_clean else host_clean
    lines = [
        f"GET {target.path} HTTP/1.1",
        f"Host: {host_hdr}:{target.port}",
        "User-Agent: arr-provision/2.0",
        "Accept: application/json, */*",
        "Connection: close",
    ]
    for k, v in target.headers.items():
        if k.lower() not in {"host", "connection", "content-length"}:
            lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("")
    return "\r\n".join(lines).encode("ascii")


def _abort_pending(
    states: Sequence[_TargetState],
    selector: selectors.BaseSelector,
    detail: str,
) -> None:
    for st in states:
        if st.phase is not _Phase.DONE:
            _mark_done(st, selector, ReadinessStatus.ABORTED, detail=detail)


def _close_target_socket(state: _TargetState, selector: selectors.BaseSelector) -> None:
    if state.sock is not None:
        try:
            selector.unregister(state.sock)
        except (KeyError, ValueError):
            pass
        try:
            state.sock.close()
        except OSError:
            pass
        state.sock = None


def _schedule_wait(
    state: _TargetState,
    now: float,
    *,
    journal_active: bool,
    http_warmup: bool = False,
) -> None:
    state.phase = _Phase.WAIT_EVENT
    if http_warmup:
        ladder = _HTTP_WARMUP_INTERVALS
    elif journal_active and state.target.systemd_unit:
        ladder = _JOURNAL_SAFETY_INTERVALS
    else:
        ladder = _FALLBACK_INTERVALS
    delay = ladder[min(state.backoff_idx, len(ladder) - 1)]
    state.backoff_idx += 1
    state.next_probe_at = now + delay


def _mark_done(
    state: _TargetState,
    selector: selectors.BaseSelector,
    status: ReadinessStatus,
    *,
    detail: str = "",
) -> None:
    _close_target_socket(state, selector)
    state.phase = _Phase.DONE
    state.status = status
    state.detail = detail


def _begin_http_send(
    state: _TargetState,
    selector: selectors.BaseSelector,
    now: float,
    io_timeout: float,
) -> None:
    assert state.sock is not None
    if not state.target.probe_http:
        _mark_done(state, selector, ReadinessStatus.READY, detail="TCP listener active")
        return

    state.send_buf = _build_http_probe_request(state.target)
    state.send_offset = 0
    state.recv_buf.clear()
    state.phase = _Phase.SENDING
    state.io_deadline = now + io_timeout
    _try_send_http(state, selector, now, io_timeout)


def _try_send_http(
    state: _TargetState,
    selector: selectors.BaseSelector,
    now: float,
    io_timeout: float,
    *,
    registered: bool = True,
) -> None:
    assert state.sock is not None
    while state.send_offset < len(state.send_buf):
        try:
            sent = state.sock.send(state.send_buf[state.send_offset :])
        except BlockingIOError:
            if registered:
                selector.modify(state.sock, selectors.EVENT_WRITE, data=("target", state))
            else:
                selector.register(state.sock, selectors.EVENT_WRITE, data=("target", state))
            return
        except OSError as exc:
            _close_target_socket(state, selector)
            state.detail = str(exc)
            _schedule_wait(state, now, journal_active=False, http_warmup=True)
            return
        if sent == 0:
            _close_target_socket(state, selector)
            state.detail = "socket closed during HTTP send"
            _schedule_wait(state, now, journal_active=False, http_warmup=True)
            return
        state.send_offset += sent

    state.phase = _Phase.READING
    state.io_deadline = now + io_timeout
    if registered:
        selector.modify(state.sock, selectors.EVENT_READ, data=("target", state))
    else:
        selector.register(state.sock, selectors.EVENT_READ, data=("target", state))


def _start_connect(
    state: _TargetState,
    selector: selectors.BaseSelector,
    now: float,
    io_timeout: float,
    *,
    journal_active: bool,
    trigger: str,
) -> None:
    _close_target_socket(state, selector)
    state.attempts += 1
    state.trigger = trigger
    family, socktype, proto, _, sockaddr = state.addr_info

    try:
        sock = socket.socket(family, socktype, proto)
    except OSError as exc:
        state.detail = f"socket creation failed: {exc}"
        _schedule_wait(state, now, journal_active=journal_active)
        return

    sock.setblocking(False)
    state.sock = sock

    try:
        err = sock.connect_ex(sockaddr)
    except OSError as exc:
        err = exc.errno or errno.ECONNREFUSED

    if err == 0:
        if not state.target.probe_http:
            _mark_done(state, selector, ReadinessStatus.READY, detail="TCP listener active")
            return
        state.send_buf = _build_http_probe_request(state.target)
        state.send_offset = 0
        state.recv_buf.clear()
        state.phase = _Phase.SENDING
        state.io_deadline = now + io_timeout
        _try_send_http(state, selector, now, io_timeout, registered=False)
        return

    if err in (errno.EINPROGRESS, errno.EALREADY, errno.EWOULDBLOCK):
        state.phase = _Phase.CONNECTING
        state.io_deadline = now + io_timeout
        selector.register(sock, selectors.EVENT_WRITE, data=("target", state))
        return

    _close_target_socket(state, selector)
    state.detail = os.strerror(err)
    _schedule_wait(state, now, journal_active=journal_active)


def _handle_target_io(
    state: _TargetState,
    selector: selectors.BaseSelector,
    now: float,
    io_timeout: float,
    *,
    journal_active: bool,
) -> None:
    if state.sock is None:
        return

    if state.phase is _Phase.CONNECTING:
        so_err = state.sock.getsockopt(socket.SOL_SOCKET, socket.SO_ERROR)
        if so_err != 0:
            _close_target_socket(state, selector)
            state.detail = os.strerror(so_err)
            _schedule_wait(state, now, journal_active=journal_active)
            return
        _begin_http_send(state, selector, now, io_timeout)
        return

    if state.phase is _Phase.SENDING:
        _try_send_http(state, selector, now, io_timeout, registered=True)
        return

    if state.phase is _Phase.READING:
        eof = False
        while len(state.recv_buf) < _MAX_HEADER_BYTES:
            try:
                chunk = state.sock.recv(4096)
            except BlockingIOError:
                break
            except OSError as exc:
                _close_target_socket(state, selector)
                state.detail = str(exc)
                _schedule_wait(state, now, journal_active=journal_active, http_warmup=True)
                return
            if not chunk:
                eof = True
                break
            state.recv_buf.extend(chunk)
            if b"\r\n\r\n" in state.recv_buf:
                break

        has_headers = b"\r\n\r\n" in state.recv_buf
        if not has_headers and not eof and len(state.recv_buf) < _MAX_HEADER_BYTES:
            return

        match = _HTTP_STATUS_LINE_RE.match(bytes(state.recv_buf))
        if not match:
            _close_target_socket(state, selector)
            state.detail = "incomplete or non-HTTP response"
            _schedule_wait(state, now, journal_active=journal_active, http_warmup=True)
            return

        code = int(match.group(1))
        state.last_http_status = code
        if code in state.target.expected_statuses:
            _mark_done(state, selector, ReadinessStatus.READY, detail=f"HTTP {code}")
        elif code in state.target.fail_statuses:
            _mark_done(
                state,
                selector,
                ReadinessStatus.HTTP_REJECTED,
                detail=f"HTTP {code} (fail-fast status)",
            )
        else:
            _close_target_socket(state, selector)
            state.detail = f"HTTP {code} (warming up)"
            _schedule_wait(state, now, journal_active=journal_active, http_warmup=True)


def _process_journal_events(
    events: Sequence[tuple[set[str], str, int | None]],
    states: Sequence[_TargetState],
    selector: selectors.BaseSelector,
    now: float,
    io_timeout: float,
    *,
    journal_active: bool,
    min_fail_wall_us: int,
) -> None:
    """Resolve journal records chronologically so restarts supersede stale failures."""
    pending_failures: dict[int, str] = {}
    wake_targets: set[int] = set()

    for rec_units, message, realtime_us in events:
        for idx, st in enumerate(states):
            if st.phase is _Phase.DONE or not st.target.systemd_unit:
                continue
            if st.target.systemd_unit not in rec_units:
                continue
            if _START_RESET_RE.search(message):
                pending_failures.pop(idx, None)
                continue
            if any(p.search(message) for p in st.target.fail_patterns):
                if realtime_us is None or realtime_us >= min_fail_wall_us:
                    pending_failures[idx] = message[:200]
                wake_targets.discard(idx)
                continue
            if any(p.search(message) for p in st.target.ready_patterns):
                pending_failures.pop(idx, None)
                if st.phase is _Phase.WAIT_EVENT:
                    wake_targets.add(idx)

    for idx, fail_msg in pending_failures.items():
        st = states[idx]
        logger.error(
            "%s: unit failure event detected in journald (%s)",
            st.target.name,
            fail_msg[:160],
        )
        _mark_done(st, selector, ReadinessStatus.UNIT_FAILED, detail=fail_msg)

    for idx in wake_targets:
        st = states[idx]
        if st.phase is _Phase.WAIT_EVENT:
            logger.debug("%s: journal readiness event -> immediate socket probe", st.target.name)
            st.backoff_idx = 0
            _start_connect(
                st,
                selector,
                now,
                io_timeout,
                journal_active=journal_active,
                trigger="journal-event",
            )


def wait_for_ready(
    targets: Iterable[ReadinessTarget],
    *,
    timeout: float = 60.0,
    io_timeout: float = 5.0,
    use_journal: bool = True,
    cancel_event: threading.Event | None = None,
    journal_cmd_override: Sequence[str] | None = None,
) -> dict[str, ReadinessResult]:
    """Wait concurrently for all targets using Linux epoll + systemd journal events.

    Zero `time.sleep()`: all I/O, journal wakeups, signals, and backoff deadlines
    run inside a single `EpollSelector.select()` reactor.
    """
    target_list = list(targets)
    if not target_list:
        return {}

    start_ns = time.monotonic_ns()
    start_wall_us = time.time_ns() // 1000
    min_fail_wall_us = start_wall_us - 2_000_000
    start = start_ns / 1e9
    global_deadline = start + max(0.05, timeout)

    selector = _create_selector()
    states: list[_TargetState] = []

    for tgt in target_list:
        infos = socket.getaddrinfo(
            tgt.host.strip("[]"), tgt.port, socket.AF_UNSPEC, socket.SOCK_STREAM
        )
        states.append(_TargetState(target=tgt, addr_info=infos[0]))  # type: ignore[arg-type]

    units = [t.systemd_unit for t in target_list if t.systemd_unit]
    journal: JournalEventSource | None = None

    try:
        with _SignalWakeupPipe(selector) as sig_pipe:
            # Phase 0: Immediate parallel non-blocking probe before spawning journalctl.
            # If every target is already accepting connections, returns in < 2ms with zero subprocesses.
            for st in states:
                _start_connect(
                    st,
                    selector,
                    start,
                    io_timeout,
                    journal_active=False,
                    trigger="initial-probe",
                )

            # Briefly drain any instant loopback SYN-ACK / HTTP replies before checking if journal is needed.
            if any(st.phase in (_Phase.CONNECTING, _Phase.SENDING, _Phase.READING) for st in states):
                drain_until = min(global_deadline, time.monotonic() + 0.05)
                while time.monotonic() < drain_until and any(
                    st.phase in (_Phase.CONNECTING, _Phase.SENDING, _Phase.READING) for st in states
                ):
                    events = selector.select(timeout=max(0.0, drain_until - time.monotonic()))
                    now = time.monotonic()
                    for key, _ in events:
                        kind, payload = key.data
                        if kind == "signal":
                            sig = sig_pipe.drain()
                            if sig is not None:
                                _abort_pending(states, selector, f"signal {sig}")
                                break
                        elif kind == "target":
                            _handle_target_io(
                                payload,
                                selector,
                                now,
                                io_timeout,
                                journal_active=False,
                            )
                    if sig_pipe.triggered_signal is not None:
                        break

            pending = [st for st in states if st.phase is not _Phase.DONE]
            if pending and use_journal and (units or journal_cmd_override is not None):
                journal = JournalEventSource(units, cmd_override=journal_cmd_override)
                if journal.start(selector):
                    now = time.monotonic()
                    for st in pending:
                        if st.phase is _Phase.WAIT_EVENT and st.target.systemd_unit:
                            # Reset tight fallback timer to sparse safety guard now that journal is live.
                            st.backoff_idx = 0
                            _schedule_wait(st, now, journal_active=True)

            # Main event loop
            while any(st.phase is not _Phase.DONE for st in states):
                if cancel_event is not None and cancel_event.is_set():
                    _abort_pending(states, selector, "cancelled")
                    break

                now = time.monotonic()
                if now >= global_deadline:
                    for st in states:
                        if st.phase is not _Phase.DONE:
                            _mark_done(
                                st,
                                selector,
                                ReadinessStatus.TIMEOUT,
                                detail=st.detail or f"timeout after {timeout:.1f}s",
                            )
                    break

                next_wake = global_deadline
                for st in states:
                    if st.phase is _Phase.WAIT_EVENT and st.next_probe_at < next_wake:
                        next_wake = st.next_probe_at
                    elif st.phase in (_Phase.CONNECTING, _Phase.SENDING, _Phase.READING):
                        if st.io_deadline < next_wake:
                            next_wake = st.io_deadline

                events = selector.select(timeout=max(0.0, next_wake - now))
                now = time.monotonic()
                journal_active = journal is not None and journal.active

                for key, _ in events:
                    kind, payload = key.data
                    if kind == "signal":
                        sig = sig_pipe.drain()
                        if sig is not None:
                            _abort_pending(states, selector, f"signal {sig}")
                            break
                    elif kind == "journal":
                        assert journal is not None
                        was_active = journal.active
                        records = journal.read_events(selector)
                        _process_journal_events(
                            records,
                            states,
                            selector,
                            now,
                            io_timeout,
                            journal_active=journal.active,
                            min_fail_wall_us=min_fail_wall_us,
                        )
                        if was_active and not journal.active:
                            for st in states:
                                if st.phase is _Phase.WAIT_EVENT:
                                    st.next_probe_at = min(
                                        st.next_probe_at, now + _FALLBACK_INTERVALS[0]
                                    )
                    elif kind == "target":
                        _handle_target_io(
                            payload,
                            selector,
                            now,
                            io_timeout,
                            journal_active=journal_active,
                        )

                if sig_pipe.triggered_signal is not None:
                    break

                # Fire expired I/O deadlines or scheduled safety/fallback probes
                journal_active = journal is not None and journal.active
                for st in states:
                    if st.phase in (_Phase.CONNECTING, _Phase.SENDING, _Phase.READING):
                        if now >= st.io_deadline:
                            _close_target_socket(st, selector)
                            st.detail = "socket I/O timeout"
                            _schedule_wait(st, now, journal_active=journal_active, http_warmup=True)
                    elif st.phase is _Phase.WAIT_EVENT and now >= st.next_probe_at:
                        _start_connect(
                            st,
                            selector,
                            now,
                            io_timeout,
                            journal_active=journal_active,
                            trigger="safety-probe" if (journal_active and st.target.systemd_unit) else "epoll-backoff",
                        )
    finally:
        if journal is not None:
            journal.close(selector)
        for st in states:
            _close_target_socket(st, selector)
        selector.close()

    total_ms = (time.monotonic_ns() - start_ns) / 1e6
    results: dict[str, ReadinessResult] = {}
    for st in states:
        status = st.status or ReadinessStatus.TIMEOUT
        results[st.target.name] = ReadinessResult(
            name=st.target.name,
            status=status,
            elapsed_ms=round(total_ms, 2),
            attempts=st.attempts,
            trigger=st.trigger,
            http_status=st.last_http_status,
            detail=st.detail,
        )
    return results
