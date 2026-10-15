#!/usr/bin/env python3
"""Erzeugt die Service Map in docs/INDEX.md aus lib/registry.nix (SSoT).

Warum: eine handgepflegte Tabelle driftet (Beleg: die alte Map in docs/README.md
zeigte noch die flat GID 5000 als Primaergruppe — ADR-0000 §5 verwirft das — und
listete 15 von 16 Registry-Diensten). Quelle bleibt lib/registry.nix; hier wird
nichts gepflegt, nur abgeleitet.

Ableitung (ADR-0000 §4): Port = UID = Primaer-GID = Nummer x 10.
Das Feld `gid` aus der Registry wird bewusst NICHT verwendet (es steht dort noch
auf 5000 = flat GID); die UPG ist die Ableitung.

Aufruf:  python3 scripts/gen_service_map.py           (schreibt INDEX.md)
         python3 scripts/gen_service_map.py --check   (Exit 1, wenn veraltet)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "lib" / "registry.nix"
INDEX = ROOT / "docs" / "INDEX.md"
MARKER_START = "<!-- SERVICE-MAP START -->"
MARKER_END = "<!-- SERVICE-MAP END -->"

# Erlaubte Aufrufe im services-Block. Reihenfolge: spezifische zuerst.
CALLS = [
    ("mkServiceWithUnit", 6),
    ("mkNoPortWithUnit", 6),
    ("mkService", 4),
    ("mkNoPort", 4),
]
QUOTED = r'"([^"]+)"'


def parse_registry() -> list[dict[str, object]]:
    text = REGISTRY.read_text(encoding="utf-8")
    lines = text.splitlines()
    start = next(i for i, l in enumerate(lines) if re.match(r"\s*services = \{", l))
    end = next(i for i in range(start + 1, len(lines)) if re.match(r"\s*\};", lines[i]))
    services, seen_unit_calls = [], False
    for offset, line in enumerate(lines[start + 1 : end], start=start + 2):
        raw = line.split("#", 1)[0].strip()
        if not raw or raw.startswith("services") or raw.startswith("inherit"):
            continue
        m = re.match(r"(?:[a-z0-9-]+)\s*=\s*([A-Za-z]+)\s+(.*);$", raw)
        if not m:
            raise SystemExit(f"registry-parser: unbekanntes Muster in lib/registry.nix:{offset}: {raw!r}")
        call, args = m.group(1), m.group(2)
        known = dict(CALLS).get(call)
        if known is None:
            raise SystemExit(f"registry-parser: unbekannter Aufruf {call!r} in Zeile {offset}")
        strs = re.findall(QUOTED, args)
        nums = re.findall(r"\b(\d{3})\b", args)
        if len(strs) < known - 2 or len(nums) != 1:
            raise SystemExit(f"registry-parser: Argumente unklar in Zeile {offset}: {raw!r}")
        name, num = strs[0], int(nums[0])
        profile = strs[1] if len(strs) > 1 else "?"
        caddy = strs[2] if len(strs) > 2 else "?"
        unit = strs[3] if len(strs) > 3 else name
        if call == "mkNoPortWithUnit":
            seen_unit_calls = True
        services.append(
            {
                "name": name,
                "unit": unit,
                "num": num,
                "port": None if call in ("mkNoPort", "mkNoPortWithUnit") else num * 10,
                # mkNoPort = SPA/Template ohne Account (unitName null) -> keine UID;
                # mkNoPortWithUnit hat eine eigene Unit (z. B. 513) -> Account mit uid = num*10.
                "uid": None if call == "mkNoPort" else num * 10,
                "upg": num * 10,
                "profile": profile,
                "caddy": caddy,
            }
        )
    if len(services) < 10 or not seen_unit_calls:
        raise SystemExit("registry-parser: zu wenige/uneindeutige Dienste — Parser pruefen")
    return sorted(services, key=lambda s: int(s["num"]))


def render(services: list[dict[str, object]]) -> str:
    out = [
        MARKER_START,
        "## 🗺 Service Map",
        "",
        "**Generiert** aus [`lib/registry.nix`](../lib/registry.nix) (SSoT) — nicht von Hand",
        "pflegen. Neu erzeugen: `python3 scripts/gen_service_map.py`, prüfen: `--check`",
        "(läuft in `order-lint`).",
        "",
        "| Dienst | Unit | Num | Port | UID | Primär-GID (UPG) | Profil | caddyClass |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for s in services:
        f = lambda v: "–" if v is None else str(v)  # noqa: E731
        ut = s["unit"] if s["unit"] != s["name"] else "–"
        out.append(
            f"| `{s['name']}` | `{ut}` | {s['num']} | {f(s['port'])} | {f(s['uid'])} | "
            f"**{s['upg']}** | `{s['profile']}` | `{s['caddy']}` |"
        )
    out += [
        "",
        "> **UPG (ADR-0000 §4):** `Port = UID = Primär-GID = Nummer × 10`. Die geteilte Gruppe",
        "> `media` (GID 5000) ist **ausschließlich** supplementary (`extraGroups`) — nie Primärgruppe.",
        "> Dienste ohne eigenen Listener (z. B. `cloudflare-dns`, `feishin`) haben keinen Port.",
        MARKER_END,
    ]
    return "\n".join(out)


def main() -> int:
    block = render(parse_registry())
    text = INDEX.read_text(encoding="utf-8")
    if MARKER_START in text:
        new = re.sub(
            re.escape(MARKER_START) + r".*?" + re.escape(MARKER_END), block, text, flags=re.S
        )
    else:  # erster Lauf: den handgeschriebenen Block ersetzen
        new = re.sub(r"## 🗺 Service Map.*?(?=## )", block + "\n\n", text, flags=re.S)
    if "--check" in sys.argv:
        if new != text:
            print("docs/INDEX.md Service Map ist veraltet — 'python3 scripts/gen_service_map.py' ausfuehren.")
            return 1
        print("Service Map in docs/INDEX.md ist aktuell.")
        return 0
    INDEX.write_text(new, encoding="utf-8")
    print(f"Service Map geschrieben ({len(parse_registry())} Dienste)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
