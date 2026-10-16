#!/usr/bin/env python3
"""agent-state-edit.py — `.agent-state.json` SICHER aendern (load -> append -> dump).

Regel **AB-037**: strukturierte Daten NIE per Text-Manipulation editieren.
Roundtrip ist byte-identisch (getestet): `json.load` -> `json.dump(indent=2, ensure_ascii=False)`.

Aufrufe:
  python3 scripts/agent-state-edit.py --check
  python3 scripts/agent-state-edit.py add-blacklist --id AB-0XX --topic T --was W --warum Y \
      [--evidence E] [--revive R] [--source S]
  python3 scripts/agent-state-edit.py add-decision --id D-0X --frage F [--optionen a,b,c]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

STATE = Path(__file__).resolve().parent.parent / ".agent-state.json"


def load() -> dict:
    return json.loads(STATE.read_text(encoding="utf-8"))


def save(d: dict) -> None:
    STATE.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=".agent-state.json sauber editieren (AB-037)")
    sub = ap.add_subparsers(dest="cmd")

    bl = sub.add_parser("add-blacklist")
    for f in ("id", "topic", "was", "warum"):
        bl.add_argument("--" + f, required=True)
    for f in ("evidence", "revive", "source"):
        bl.add_argument("--" + f, default="")

    dec = sub.add_parser("add-decision")
    dec.add_argument("--id", required=True)
    dec.add_argument("--frage", required=True)
    dec.add_argument("--optionen", default="")

    ap.add_argument("--check", action="store_true", help="nur JSON/Anzahl pruefen")
    ap.add_argument("--date", default="2026-10-16")
    a = ap.parse_args()

    state = load()
    if a.check:
        c = state["corridor"]
        print(f"JSON ok · blacklist {len(c['blacklist'])} · open_decisions {len(c.get('open_decisions', []))}")
        return 0

    if a.cmd == "add-blacklist":
        state["corridor"]["blacklist"].append(
            {
                "id": a.id,
                "topic": a.topic,
                "was": a.was,
                "warum": a.warum,
                "evidence": a.evidence,
                "status": "aktiv",
                "revive_if": a.revive,
                "source": a.source,
                "date": a.date,
            }
        )
    elif a.cmd == "add-decision":
        state["corridor"]["open_decisions"].append(
            {
                "id": a.id,
                "frage": a.frage,
                "optionen": [o.strip() for o in a.optionen.split(",") if o.strip()],
                "status": "offen",
            }
        )
    else:
        ap.print_help()
        return 2

    save(state)
    c = state["corridor"]
    print(f"ok · blacklist {len(c['blacklist'])} · open_decisions {len(c.get('open_decisions', []))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
