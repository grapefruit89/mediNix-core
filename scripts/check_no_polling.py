#!/usr/bin/env python3
"""Ratsche: Zero-Polling & Anti-Sleep Invariante (mediNix ADR-0010 / ADR-5000).

Verbietet unkontrollierte `sleep`-Aufrufe, `time.sleep()` und Busy-Polling
in Produktiv-Code (Services, Wartungs-Skripte, Provisioning).

Polling verdeckt Fehler, ignoriert Unit-Crashes, frisst Timeouts und
erzeugt unnötige CPU-Latenzen. mediNix verlangt stattdessen native Event-Kanäle:
  - Systemd-Unit Lifecycle: synchronous `systemctl stop/start` oder `Type=notify`
  - Dateisystem-Events: `systemd.path` (inotify)
  - API / Service Readiness: Kernel-epoll & systemd-journald streaming (`events.py`)

Erlaubt sind ausschließlich begründete Ausnahmen auf Hardware-Ebene
(z. B. physische DSL-Leitungs-Synchronisation beim Router-Reconnect).
"""

from __future__ import annotations

import ast
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Relevante Produktions-Verzeichnisse
TARGET_DIRS = (
    "50-core",
    "51-ingress",
    "52-security",
    "53-acquisition",
    "54-processing",
    "55-playback",
    "56-exposition",
    "57-maintenance",
    "58-observability",
    "59-guardrails",
    "packages",
    "scripts",
)

# Dateiendungen
CHECK_EXTENSIONS = {".nix", ".sh", ".py", ".bash", ".service"}

# Dokumentierte, hardware-bedingte Ausnahmen: {Relativer Pfad: Begründung}
ALLOWLIST = {
    "51-ingress/513-router-adapter-speedport.nix": (
        "Hardware-DSL-Synchronisation: Physischer DSLAM/PPPoE-Reconnect des Speedport-Routers "
        "benötigt 20-25s Leitungspuffer auf Kupferkabel-Ebene."
    ),
    "scripts/migrate-uids.sh": (
        "Einmaliges historisches Offline-Migrationsskript für UIDs (kein Laufzeit-Dienst)."
    ),
}

SHELL_SLEEP = re.compile(
    r"(?:^|[;&|]\s*|\$\(|\b)(?:sudo\s+)?sleep\s+[0-9]+(?:\.[0-9]+)?",
    re.IGNORECASE,
)
BUSY_POLL = re.compile(
    r"\b(?:while|until)\s+[^;]+(?:curl|nc|wget|netcat)[^;]*;\s*do\b",
    re.IGNORECASE,
)


def check_python_file(path: Path) -> list[str]:
    findings: list[str] = []
    rel_path = path.relative_to(ROOT).as_posix()
    try:
        source = path.read_text(encoding="utf-8", errors="replace")
        tree = ast.parse(source, filename=str(path))
    except Exception:
        # Falls AST-Parsing fehlschlägt (z. B. Syntaxfehler), Fallback auf Zeilenscan
        return []

    # Prüfe echte AST-Aufrufe von time.sleep(...)
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            # time.sleep(...)
            if isinstance(node.func, ast.Attribute) and node.func.attr == "sleep":
                if isinstance(node.func.value, ast.Name) and node.func.value.id == "time":
                    findings.append(
                        f"{rel_path}:{node.lineno}: [Python time.sleep Aufruf]"
                    )
            # direct sleep(...)
            elif isinstance(node.func, ast.Name) and node.func.id == "sleep":
                findings.append(
                    f"{rel_path}:{node.lineno}: [Python sleep Aufruf]"
                )

    return findings


def check_script_or_nix(path: Path) -> list[str]:
    findings: list[str] = []
    rel_path = path.relative_to(ROOT).as_posix()
    try:
        content = path.read_text(encoding="utf-8", errors="replace")
    except Exception as e:
        return [f"{rel_path}: Konnte Datei nicht lesen: {e}"]

    # Ausblenden von Kommentaren
    for idx, raw_line in enumerate(content.splitlines(), 1):
        line = raw_line.strip()
        if line.startswith("#") or line.startswith("//") or line.startswith("/*"):
            continue

        if SHELL_SLEEP.search(line):
            findings.append(f"{rel_path}:{idx}: [Shell sleep Befehl] -> '{line}'")
        if BUSY_POLL.search(line):
            findings.append(f"{rel_path}:{idx}: [Busy-Polling Schleife] -> '{line}'")

    return findings


def main() -> int:
    all_findings: list[str] = []
    checked_count = 0

    for dir_name in TARGET_DIRS:
        target_dir = ROOT / dir_name
        if not target_dir.exists():
            continue

        for path in sorted(target_dir.rglob("*")):
            if not path.is_file():
                continue
            if path.suffix not in CHECK_EXTENSIONS:
                continue
            # Tests und Caches überspringen
            if any(p in ("tests", "__pycache__", ".pytest_cache") for p in path.parts):
                continue
            if path.resolve() == Path(__file__).resolve():
                continue

            rel_path = path.relative_to(ROOT).as_posix()
            if rel_path in ALLOWLIST:
                continue

            checked_count += 1
            if path.suffix == ".py":
                findings = check_python_file(path)
            else:
                findings = check_script_or_nix(path)

            all_findings.extend(findings)

    if all_findings:
        print("❌ FEHLER: Unerlaubte Polling- / Sleep-Befehle im Produktivcode gefunden!\n")
        print("   Polling ist in mediNix verboten (ADR-0010 / ADR-5000).")
        print("   Nutze stattdessen Event-Reaktoren (events.py), Type=notify oder systemd.path.\n")
        for f in all_findings:
            print(f"   • {f}")
        print(f"\nGesamt: {len(all_findings)} Verstoß/Verstöße in {checked_count} geprüften Dateien.")
        return 1

    print(
        f"OK    check_no_polling (0 verbotene Polling/Sleep-Befehle in {checked_count} Produktiv-Dateien, "
        f"{len(ALLOWLIST)} dokumentierte Hardware-Ausnahmen)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
