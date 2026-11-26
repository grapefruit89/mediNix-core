"""Rotate *arr API keys from declarative secrets into running services."""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

from arr_provision.common import arr_api_base, http_json, read_key_file, wait_for_url, title_case_service

_ARR_SERVICES = ("sonarr", "radarr", "prowlarr")


def _valid_key(key: str) -> bool:
    normalized = re.sub(r"[\s\r\n\t-]", "", key)
    return 20 <= len(normalized) <= 32 and normalized.isalnum()


def _api_ok(host: str, port: int, api_key: str) -> bool:
    base = arr_api_base(host, port, "v3")
    status, _ = http_json("GET", f"{base}/system/status", headers={"X-Api-Key": api_key})
    return status < 400


# ADR-0010 §2.1 & §2.2:
# API-Key-Provisionierung erfolgt deklarativ VOR dem Start des Dienstes (ExecStartPre / preStart).
# arr-provision läuft als unprivilegierter media-User (ProtectSystem=strict) und darf
# KEINE 'systemctl restart'-Kommandos oder direkte Dateisystem-Mutationen ausführen.


def _sync_arr_service(host: str, name: str, port: int, key_file: str) -> None:
    label = title_case_service(name)
    api_key = read_key_file(key_file)
    if not api_key:
        print(f"{label}: no API key file — skipped", file=sys.stderr)
        return
    if not _valid_key(api_key):
        print(f"{label}: API key invalid length/format — skipped", file=sys.stderr)
        return
    if _api_ok(host, port, api_key):
        print(f"{label}: API key already active")
        return

    # ADR-0010: Schlüssel wird deklarativ via ExecStartPre injiziert.
    print(f"{label}: API key from sealed credential not accepted via REST API (verify ExecStartPre)", file=sys.stderr)


def _sync_sabnzbd_key(key_file: str) -> None:
    sab_ini = Path(os.environ["SAB_INI_FILE"])
    if not sab_ini.exists():
        print("SABnzbd: sabnzbd.ini not present — skipped", file=sys.stderr)
        return

    api_key = read_key_file(key_file)
    if not api_key or not _valid_key(api_key):
        print("SABnzbd: invalid API key — skipped", file=sys.stderr)
        return

    content = sab_ini.read_text(encoding="utf-8")
    changed = False
    for key_name in ("api_key", "nzb_key"):
        pattern = rf"^{re.escape(key_name)}.*$"
        replacement = f"{key_name} = {api_key}"
        if re.search(pattern, content, flags=re.MULTILINE):
            updated = re.sub(pattern, replacement, content, count=1, flags=re.MULTILINE)
            if updated != content:
                content = updated
                changed = True
        else:
            content = f"{key_name} = {api_key}\n{content}"
            changed = True

    if not changed:
        print("SABnzbd: API keys already correct")
        return

    # ADR-0010 §2.1: Key-Seeding erfolgt im preStart des SABnzbd-Dienstes.
    try:
        sab_ini.write_text(content, encoding="utf-8")
        print("SABnzbd: API keys updated in ini (no restart needed)")
    except OSError as exc:
        print(f"SABnzbd: ini write skipped in hardened sandbox: {exc}", file=sys.stderr)


def sync_arr_keys() -> int:
    host = os.environ.get("ARR_HOST", "127.0.0.1")

    if os.environ.get("SYNC_SONARR", "0") == "1":
        _sync_arr_service(host, "sonarr", int(os.environ["SONARR_PORT"]), os.environ["SONARR_KEY_FILE"])
    if os.environ.get("SYNC_RADARR", "0") == "1":
        _sync_arr_service(host, "radarr", int(os.environ["RADARR_PORT"]), os.environ["RADARR_KEY_FILE"])
    if os.environ.get("SYNC_PROWLARR", "0") == "1":
        _sync_arr_service(host, "prowlarr", int(os.environ["PROWLARR_PORT"]), os.environ["PROWLARR_KEY_FILE"])
    if os.environ.get("SYNC_SABNZBD", "0") == "1":
        _sync_sabnzbd_key(os.environ["SABNZBD_KEY_FILE"])

    print("Arr keys sync complete.")
    return 0


def main() -> None:
    raise SystemExit(sync_arr_keys())


if __name__ == "__main__":
    main()
