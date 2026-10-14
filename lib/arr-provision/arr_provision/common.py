"""Shared helpers for HTTP API provisioning."""

from __future__ import annotations

import json
import re
import sys
import time
import urllib.error
import urllib.request
from typing import Any, Mapping, MutableMapping, Optional

_APIKEY_XML = re.compile(r"<ApiKey>([^<]+)</ApiKey>", re.IGNORECASE)
_APIKEY_INI = re.compile(
    r"^\s*(?:api_key|nzb_key|ApiKey)\s*=\s*([a-zA-Z0-9]+)",
    re.MULTILINE | re.IGNORECASE,
)


def read_key_file(path: str) -> Optional[str]:
    """Read plain-text (32 hex), KEY=val, INI, or *arr config.xml."""
    try:
        with open(path, encoding="utf-8") as handle:
            content = handle.read().strip()
    except OSError:
        return None

    if not content:
        return None

    # 1. XML-Check (*arr config.xml)
    match_xml = _APIKEY_XML.search(content)
    if match_xml:
        return match_xml.group(1).strip() or None

    # 2. INI / Env-Check (sabnzbd.ini oder KEY=value irgendwo in der Datei)
    match_ini = _APIKEY_INI.search(content)
    if match_ini:
        return match_ini.group(1).strip() or None

    # 3. Fallback: Reiner Plaintext-Key (z.B. aus systemd-creds)
    first_line = content.splitlines()[0].strip()
    if len(first_line) >= 20 and first_line.isalnum():
        return first_line

    return None


def wait_for_url(
    url: str,
    *,
    headers: Optional[Mapping[str, str]] = None,
    max_attempts: int = 30,
    sleep_seconds: float = 2.0,
    require_fail: bool = False,
    timeout: float = 5.0,
) -> bool:
    hdrs = dict(headers or {})
    for attempt in range(1, max_attempts + 1):
        try:
            request = urllib.request.Request(url, headers=hdrs)
            with urllib.request.urlopen(request, timeout=timeout) as response:
                if require_fail and response.status >= 400:
                    raise urllib.error.HTTPError(url, response.status, "", hdrs, None)
            safe_url = re.sub(r"apikey=[^&]+", "apikey=REDACTED", url)
            print(f"Service available at {safe_url} (attempt {attempt})")
            return True
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as exc:
            if attempt == max_attempts:
                safe_url = re.sub(r"apikey=[^&]+", "apikey=REDACTED", url)
                print(f"Service not available at {safe_url} after {max_attempts} attempts: {exc}", file=sys.stderr)
                return False
            time.sleep(sleep_seconds)
    return False


def http_json(
    method: str,
    url: str,
    *,
    headers: Optional[MutableMapping[str, str]] = None,
    body: Any = None,
    timeout: float = 30.0,
) -> tuple[int, Any]:
    payload = None
    hdrs: MutableMapping[str, str] = {"Accept": "application/json"}
    if headers:
        hdrs.update(headers)
    if body is not None:
        payload = json.dumps(body).encode("utf-8")
        hdrs.setdefault("Content-Type", "application/json")
    request = urllib.request.Request(url, data=payload, headers=hdrs, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read().decode("utf-8")
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as exc:
        return exc.code, {"error": "HTTP request failed (details suppressed)"}


def arr_api_base(host: str, port: int, api_version: str) -> str:
    return f"http://{host}:{port}/api/{api_version}"


def title_case_service(name: str) -> str:
    return name[:1].upper() + name[1:] if name else name
