#!/usr/bin/env python3
"""Ratsche: Systemd-Analyze Security Exposure Gate (ADR-5050 / Hardening Watchdog).

Prüft die mediNix Systemd-Hardening-Profile offline via `systemd-analyze security`.
Verhindert Sicherheits-Regressionen (Ratschen-Prinzip): Wird eine Unit unsicherer
oder verliert wichtige Sandbox-Direktiven (z.B. NoNewPrivileges, ProtectSystem),
schlägt dieser Check im CI und in verify.sh sofort fehl.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASELINE_FILE = ROOT / "scripts/systemd-security-baseline.json"

PROFILES = {
    "script": {
        "Description": "mediNix Script Profile (Maintenance / Helpers)",
        "User": "medinix-script",
        "Group": "medinix-script",
        "NoNewPrivileges": "true",
        "ProtectSystem": "strict",
        "ProtectHome": "true",
        "PrivateTmp": "true",
        "ProtectKernelTunables": "true",
        "ProtectKernelModules": "true",
        "ProtectKernelLogs": "true",
        "ProtectControlGroups": "true",
        "ProtectProc": "invisible",
        "ProcSubset": "pid",
        "RestrictNamespaces": "true",
        "RestrictRealtime": "true",
        "RestrictSUIDSGID": "true",
        "LockPersonality": "true",
        "SystemCallFilter": "@system-service",
        "SystemCallErrorNumber": "EPERM",
        "SystemCallArchitectures": "native",
        "ProtectClock": "true",
        "ProtectHostname": "true",
        "RemoveIPC": "true",
        "PrivateUsers": "true",
        "CapabilityBoundingSet": "",
        "AmbientCapabilities": "",
        "RestrictAddressFamilies": "AF_UNIX",
        "PrivateDevices": "true",
        "PrivateNetwork": "true",
        "IPAddressDeny": "any",
        "UMask": "0002",
    },
    "python": {
        "Description": "mediNix Python Service (SABnzbd / Scrapers)",
        "User": "sabnzbd",
        "Group": "sabnzbd",
        "NoNewPrivileges": "true",
        "ProtectSystem": "strict",
        "ProtectHome": "true",
        "PrivateTmp": "true",
        "ProtectKernelTunables": "true",
        "ProtectKernelModules": "true",
        "ProtectKernelLogs": "true",
        "ProtectControlGroups": "true",
        "ProtectProc": "invisible",
        "ProcSubset": "pid",
        "RestrictNamespaces": "true",
        "RestrictRealtime": "true",
        "RestrictSUIDSGID": "true",
        "LockPersonality": "true",
        "SystemCallFilter": "@system-service",
        "SystemCallErrorNumber": "EPERM",
        "SystemCallArchitectures": "native",
        "ProtectClock": "true",
        "ProtectHostname": "true",
        "RemoveIPC": "true",
        "PrivateUsers": "true",
        "CapabilityBoundingSet": "",
        "AmbientCapabilities": "",
        "RestrictAddressFamilies": "AF_UNIX AF_INET AF_INET6 AF_NETLINK",
        "PrivateDevices": "true",
        "MemoryDenyWriteExecute": "true",
        "UMask": "0002",
    },
    "dotnet": {
        "Description": "mediNix .NET Service (Sonarr / Radarr / Prowlarr)",
        "User": "sonarr",
        "Group": "sonarr",
        "NoNewPrivileges": "true",
        "ProtectSystem": "strict",
        "ProtectHome": "true",
        "PrivateTmp": "true",
        "ProtectKernelTunables": "true",
        "ProtectKernelModules": "true",
        "ProtectKernelLogs": "true",
        "ProtectControlGroups": "true",
        "ProtectProc": "invisible",
        "ProcSubset": "pid",
        "RestrictNamespaces": "true",
        "RestrictRealtime": "true",
        "RestrictSUIDSGID": "true",
        "LockPersonality": "true",
        "SystemCallFilter": "@system-service",
        "SystemCallErrorNumber": "EPERM",
        "SystemCallArchitectures": "native",
        "ProtectClock": "true",
        "ProtectHostname": "true",
        "RemoveIPC": "true",
        "PrivateUsers": "true",
        "CapabilityBoundingSet": "",
        "AmbientCapabilities": "",
        "RestrictAddressFamilies": "AF_UNIX AF_INET AF_INET6 AF_NETLINK",
        "PrivateDevices": "true",
        "MemoryDenyWriteExecute": "false",
        "UMask": "0002",
    },
    "network": {
        "Description": "mediNix Network & Ingress (Caddy / CrowdSec)",
        "User": "caddy-media",
        "Group": "caddy-media",
        "NoNewPrivileges": "true",
        "ProtectSystem": "strict",
        "ProtectHome": "true",
        "PrivateTmp": "true",
        "ProtectKernelTunables": "true",
        "ProtectKernelModules": "true",
        "ProtectKernelLogs": "true",
        "ProtectControlGroups": "true",
        "ProtectProc": "invisible",
        "ProcSubset": "pid",
        "RestrictNamespaces": "true",
        "RestrictRealtime": "true",
        "RestrictSUIDSGID": "true",
        "LockPersonality": "true",
        "SystemCallFilter": "@system-service",
        "SystemCallErrorNumber": "EPERM",
        "SystemCallArchitectures": "native",
        "ProtectClock": "true",
        "ProtectHostname": "true",
        "RemoveIPC": "true",
        "PrivateUsers": "false",
        "CapabilityBoundingSet": "CAP_NET_BIND_SERVICE",
        "AmbientCapabilities": "CAP_NET_BIND_SERVICE",
        "RestrictAddressFamilies": "AF_UNIX AF_INET AF_INET6 AF_NETLINK",
        "PrivateDevices": "true",
        "MemoryDenyWriteExecute": "true",
        "UMask": "0002",
    },
    "dotnet-gpu": {
        "Description": "mediNix Transcoding Service (Jellyfin VA-API)",
        "User": "jellyfin",
        "Group": "jellyfin",
        "NoNewPrivileges": "true",
        "ProtectSystem": "strict",
        "ProtectHome": "true",
        "PrivateTmp": "true",
        "ProtectKernelTunables": "true",
        "ProtectKernelModules": "true",
        "ProtectKernelLogs": "true",
        "ProtectControlGroups": "true",
        "ProtectProc": "invisible",
        "ProcSubset": "pid",
        "RestrictNamespaces": "true",
        "RestrictRealtime": "true",
        "RestrictSUIDSGID": "true",
        "LockPersonality": "true",
        "SystemCallFilter": "@system-service",
        "SystemCallErrorNumber": "EPERM",
        "SystemCallArchitectures": "native",
        "ProtectClock": "true",
        "ProtectHostname": "true",
        "RemoveIPC": "true",
        "PrivateUsers": "false",
        "CapabilityBoundingSet": "",
        "AmbientCapabilities": "",
        "RestrictAddressFamilies": "AF_UNIX AF_INET AF_INET6 AF_NETLINK",
        "PrivateDevices": "false",
        "MemoryDenyWriteExecute": "false",
        "UMask": "0002",
    },
}


def analyze_profile(name: str, config: dict[str, str]) -> tuple[float, str, str]:
    with tempfile.NamedTemporaryFile("w", suffix=".service", delete=False) as f:
        f.write(f"[Unit]\nDescription={config['Description']}\n\n[Service]\nExecStart=/bin/true\n")
        for k, v in config.items():
            if k != "Description":
                f.write(f"{k}={v}\n")
        tmp_path = f.name

    try:
        cmd = ["systemd-analyze", "security", "--offline=true", tmp_path]
        res = subprocess.run(cmd, capture_output=True, text=True, check=False)
        output = res.stdout + res.stderr
        m = re.search(r"Overall exposure level for .*: ([0-9.]+) ([A-Z]+)", output)
        if m:
            return float(m.group(1)), m.group(2), output
        return 9.9, "UNKNOWN", output
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


def main() -> int:
    parser = argparse.ArgumentParser(description="mediNix Systemd Security Watchdog")
    parser.add_argument("--dump", action="store_true", help="Print full security details")
    parser.add_argument("--update-baseline", action="store_true", help="Update baseline file")
    args = parser.parse_args()

    if not shutil.which("systemd-analyze"):
        print("WARNUNG: systemd-analyze ist auf diesem System nicht verfügbar. Check übersprungen.")
        return 0

    baseline = {}
    if BASELINE_FILE.is_file():
        try:
            baseline = json.loads(BASELINE_FILE.read_text(encoding="utf-8")).get("profiles", {})
        except Exception as e:
            print(f"WARNUNG: Baseline {BASELINE_FILE} konnte nicht gelesen werden: {e}")

    failed = False
    results = {}

    print("== Systemd Security Exposure Audit =================================")
    print(f"{'Profil':<12} {'Score':<8} {'Status':<8} {'Erlaubt':<8} {'Ergebnis'}")
    print("-" * 55)

    for name, conf in PROFILES.items():
        exposure, status, full_out = analyze_profile(name, conf)
        base_info = baseline.get(name, {})
        max_allowed = base_info.get("max_allowed", 2.5)

        is_ok = exposure <= max_allowed
        status_symbol = "\033[32mOK\033[0m" if is_ok else "\033[31mREGRESSION\033[0m"

        print(f"{name:<12} {exposure:<8.1f} {status:<8} {max_allowed:<8.1f} {status_symbol}")

        if not is_ok:
            failed = True
            print(f"  ❌ {name} überschreitet das Sicherheitslimit ({exposure} > {max_allowed})!")

        results[name] = {
            "exposure": exposure,
            "status": status,
            "max_allowed": max_allowed,
        }

        if args.dump:
            print(f"\n--- Details für {name} ---")
            for line in full_out.splitlines():
                if line.startswith("✗") or "exposure" in line.lower():
                    print("  " + line)
            print("-" * 55)

    if args.update_baseline:
        new_baseline = {
            "version": 1,
            "description": "Baseline exposure scores for mediNix systemd hardening profiles",
            "profiles": {
                k: {
                    "exposure": v["exposure"],
                    "status": v["status"],
                    "max_allowed": round(v["exposure"] + 0.2, 1),
                }
                for k, v in results.items()
            },
        }
        BASELINE_FILE.write_text(json.dumps(new_baseline, indent=2) + "\n", encoding="utf-8")
        print(f"\n✅ Baseline erfolgreich aktualisiert: {BASELINE_FILE}")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
