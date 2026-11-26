"""Unit & integration tests for event-driven epoll + journal readiness engine."""

from __future__ import annotations

import http.server
import json
import os
import signal
import socket
import sys
import threading
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

try:
    from arr_provision.events import ReadinessStatus, ReadinessTarget, wait_for_ready
except ImportError:
    from events import ReadinessStatus, ReadinessTarget, wait_for_ready


def _reserve_ephemeral_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return int(s.getsockname()[1])


class _WarmupHandler(http.server.BaseHTTPRequestHandler):
    calls = 0
    fail_first = 0

    def do_GET(self) -> None:  # noqa: N802
        type(self).calls += 1
        if type(self).calls <= type(self).fail_first:
            self.send_response(503)
            self.end_headers()
            self.wfile.write(b"warming up")
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"version":"5.0"}')

    def log_message(self, format: str, *args: object) -> None:
        return


class EventsReadinessTests(unittest.TestCase):
    def test_already_listening_returns_immediately(self) -> None:
        class OkHandler(_WarmupHandler):
            calls = 0
            fail_first = 0

        srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), OkHandler)
        port = srv.server_address[1]
        t = threading.Thread(target=srv.serve_forever, daemon=True)
        t.start()
        try:
            res = wait_for_ready(
                [ReadinessTarget(name="sonarr", port=port, path="/api/v3/system/status")],
                timeout=3.0,
                use_journal=False,
            )
            self.assertTrue(res["sonarr"].ok)
            self.assertEqual(res["sonarr"].http_status, 200)
            self.assertEqual(res["sonarr"].attempts, 1)
            self.assertEqual(res["sonarr"].trigger, "initial-probe")
            self.assertLess(res["sonarr"].elapsed_ms, 500.0)
        finally:
            srv.shutdown()
            srv.server_close()

    def test_503_warmup_transitions_to_200(self) -> None:
        class SlowWarmup(_WarmupHandler):
            calls = 0
            fail_first = 2

        srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), SlowWarmup)
        port = srv.server_address[1]
        t = threading.Thread(target=srv.serve_forever, daemon=True)
        t.start()
        try:
            res = wait_for_ready(
                [ReadinessTarget(name="radarr", port=port, path="/api/v3/system/status")],
                timeout=3.0,
                use_journal=False,
            )
            self.assertTrue(res["radarr"].ok)
            self.assertEqual(res["radarr"].http_status, 200)
            self.assertEqual(res["radarr"].attempts, 3)
        finally:
            srv.shutdown()
            srv.server_close()

    def test_journal_event_wakes_and_probes_immediately(self) -> None:
        port = _reserve_ephemeral_port()

        class ReadyHandler(_WarmupHandler):
            calls = 0
            fail_first = 0

        # Simulate a service that binds AFTER 120ms and emits Kestrel's exact journal JSON line.
        # Notice the safety timer with journal_active is 2.5s! So succeeding in < 400ms
        # PROVES the journal pipe woke epoll immediately instead of waiting for any timer.
        script = (
            "import json, sys, time; "
            "time.sleep(0.15); "
            f"print(json.dumps({{'_SYSTEMD_UNIT': 'prowlarr.service', 'MESSAGE': 'Now listening on: http://127.0.0.1:{port}'}}), flush=True); "
            "time.sleep(5)"
        )

        srv_holder: list[http.server.ThreadingHTTPServer] = []

        def start_server() -> None:
            time.sleep(0.12)
            srv = http.server.ThreadingHTTPServer(("127.0.0.1", port), ReadyHandler)
            srv_holder.append(srv)
            srv.serve_forever()

        t = threading.Thread(target=start_server, daemon=True)
        t.start()
        try:
            res = wait_for_ready(
                [
                    ReadinessTarget(
                        name="prowlarr",
                        port=port,
                        path="/api/v1/system/status",
                        systemd_unit="prowlarr.service",
                    )
                ],
                timeout=3.0,
                journal_cmd_override=[sys.executable, "-c", script],
            )
            self.assertTrue(res["prowlarr"].ok)
            self.assertEqual(res["prowlarr"].trigger, "journal-event")
            self.assertLess(res["prowlarr"].elapsed_ms, 800.0)
        finally:
            for srv in srv_holder:
                srv.shutdown()
                srv.server_close()

    def test_journal_unit_failure_triggers_fail_fast(self) -> None:
        port = _reserve_ephemeral_port()
        script = (
            "import json, sys, time; "
            "time.sleep(0.08); "
            "print(json.dumps({'UNIT': 'jellyfin.service', 'MESSAGE': \"jellyfin.service: Failed with result 'exit-code'.\"}), flush=True); "
            "time.sleep(5)"
        )
        res = wait_for_ready(
            [
                ReadinessTarget(
                    name="jellyfin",
                    port=port,
                    path="/System/Info/Public",
                    systemd_unit="jellyfin.service",
                )
            ],
            timeout=10.0,
            journal_cmd_override=[sys.executable, "-c", script],
        )
        self.assertEqual(res["jellyfin"].status, ReadinessStatus.UNIT_FAILED)
        self.assertLess(res["jellyfin"].elapsed_ms, 800.0)

    def test_signal_wakeup_aborts_cleanly(self) -> None:
        port = _reserve_ephemeral_port()
        prev_handler = signal.getsignal(signal.SIGUSR1)
        signal.signal(signal.SIGUSR1, lambda *_: None)

        def send_sig() -> None:
            time.sleep(0.1)
            os.kill(os.getpid(), signal.SIGUSR1)

        t = threading.Thread(target=send_sig, daemon=True)
        t.start()
        try:
            res = wait_for_ready(
                [ReadinessTarget(name="seerr", port=port, path="/api/v1/status")],
                timeout=10.0,
                use_journal=False,
            )
            self.assertEqual(res["seerr"].status, ReadinessStatus.ABORTED)
            self.assertLess(res["seerr"].elapsed_ms, 500.0)
        finally:
            signal.signal(signal.SIGUSR1, prev_handler)

    def test_timeout_when_unreachable(self) -> None:
        port = _reserve_ephemeral_port()
        res = wait_for_ready(
            [ReadinessTarget(name="deadsvc", port=port, path="/health")],
            timeout=0.25,
            use_journal=False,
        )
        self.assertEqual(res["deadsvc"].status, ReadinessStatus.TIMEOUT)

    def test_fail_fast_http_rejected(self) -> None:
        class AuthRejectHandler(http.server.BaseHTTPRequestHandler):
            calls = 0

            def do_GET(self) -> None:  # noqa: N802
                type(self).calls += 1
                self.send_response(401)
                self.end_headers()

            def log_message(self, format: str, *args: object) -> None:
                return

        srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), AuthRejectHandler)
        port = srv.server_address[1]
        t = threading.Thread(target=srv.serve_forever, daemon=True)
        t.start()
        try:
            res = wait_for_ready(
                [
                    ReadinessTarget(
                        name="sonarr",
                        port=port,
                        path="/api/v3/system/status",
                        fail_statuses=frozenset({401, 403}),
                    )
                ],
                timeout=5.0,
                use_journal=False,
            )
            self.assertEqual(res["sonarr"].status, ReadinessStatus.HTTP_REJECTED)
            self.assertEqual(res["sonarr"].http_status, 401)
            self.assertEqual(res["sonarr"].attempts, 1)
            self.assertLess(res["sonarr"].elapsed_ms, 500.0)
        finally:
            srv.shutdown()
            srv.server_close()

    def test_concurrent_multi_target_and_restart_replay(self) -> None:
        p1 = _reserve_ephemeral_port()
        p2 = _reserve_ephemeral_port()

        class OkHandler(_WarmupHandler):
            calls = 0
            fail_first = 0

        # Replay batch contains an earlier failure superseded by Starting + Now listening on.
        script = (
            "import json, sys, time; "
            "print(json.dumps({'UNIT': 'sonarr.service', 'MESSAGE': \"sonarr.service: Failed with result 'exit-code'.\"}), flush=True); "
            "print(json.dumps({'UNIT': 'sonarr.service', 'MESSAGE': 'Starting sonarr.service - Sonarr...'}), flush=True); "
            "time.sleep(0.12); "
            f"print(json.dumps({{'_SYSTEMD_UNIT': 'sonarr.service', 'MESSAGE': 'Now listening on: http://127.0.0.1:{p1}'}}), flush=True); "
            f"print(json.dumps({{'_SYSTEMD_UNIT': 'radarr.service', 'MESSAGE': 'Now listening on: http://127.0.0.1:{p2}'}}), flush=True); "
            "time.sleep(5)"
        )

        servers: list[http.server.ThreadingHTTPServer] = []

        def start_both() -> None:
            time.sleep(0.08)
            for port in (p1, p2):
                srv = http.server.ThreadingHTTPServer(("127.0.0.1", port), OkHandler)
                servers.append(srv)
                threading.Thread(target=srv.serve_forever, daemon=True).start()

        threading.Thread(target=start_both, daemon=True).start()
        try:
            res = wait_for_ready(
                [
                    ReadinessTarget(name="sonarr", port=p1, path="/api/v3/system/status", systemd_unit="sonarr.service"),
                    ReadinessTarget(name="radarr", port=p2, path="/api/v3/system/status", systemd_unit="radarr.service"),
                ],
                timeout=4.0,
                journal_cmd_override=[sys.executable, "-c", script],
            )
            self.assertTrue(res["sonarr"].ok)
            self.assertTrue(res["radarr"].ok)
            self.assertLess(res["sonarr"].elapsed_ms, 1000.0)
            self.assertLess(res["radarr"].elapsed_ms, 1000.0)
        finally:
            for srv in servers:
                srv.shutdown()
                srv.server_close()

    def test_journal_eof_falls_back_quickly(self) -> None:
        port = _reserve_ephemeral_port()

        class OkHandler(_WarmupHandler):
            calls = 0
            fail_first = 0

        # Simulate journalctl exiting immediately with EACCES/empty output.
        srv_holder: list[http.server.ThreadingHTTPServer] = []

        def start_delayed() -> None:
            time.sleep(0.10)
            srv = http.server.ThreadingHTTPServer(("127.0.0.1", port), OkHandler)
            srv_holder.append(srv)
            srv.serve_forever()

        threading.Thread(target=start_delayed, daemon=True).start()
        try:
            res = wait_for_ready(
                [ReadinessTarget(name="lidarr", port=port, path="/api/v1/system/status", systemd_unit="lidarr.service")],
                timeout=2.0,
                journal_cmd_override=[sys.executable, "-c", "import sys; sys.exit(1)"],
            )
            self.assertTrue(res["lidarr"].ok)
            # Without EOF fallback, journal safety guard would have waited 2.5s and timed out!
            self.assertLess(res["lidarr"].elapsed_ms, 800.0)
        finally:
            for srv in srv_holder:
                srv.shutdown()
                srv.server_close()


if __name__ == "__main__":
    unittest.main()
