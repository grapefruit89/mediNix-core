#!/usr/bin/env python3
"""Erzeugt die Playbook-Zone (Paragraf 5) in docs/RUNBOOK.md aus lib/runbook.json (SSoT).

Warum: eine zweite, handgepflegte Playbook-Liste driftet (Beleg: dieselben
Symptome standen doppelt in lib/cli.nix UND in docs/RUNBOOK.md). Quelle bleibt
lib/runbook.json; cli.nix liest sie via builtins.readFile, diese Doku wird daraus
generiert. Eine Information = eine Quelle.

Aufruf:  python3 scripts/gen_runbook.py           (schreibt docs/RUNBOOK.md)
         python3 scripts/gen_runbook.py --check   (Exit 1, wenn veraltet)
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUNBOOK = ROOT / "lib" / "runbook.json"
DOC = ROOT / "docs" / "RUNBOOK.md"
MARKER_START = "<!-- RUNBOOK-PLAYBOOKS START -->"
MARKER_END = "<!-- RUNBOOK-PLAYBOOKS END -->"


def load() -> dict[str, dict[str, object]]:
    data = json.loads(RUNBOOK.read_text(encoding="utf-8"))
    required = {"symptom", "bereich", "chain", "paths", "error_pattern", "fix"}
    for key, entry in data.items():
        missing = required - set(entry)
        if missing:
            raise SystemExit(f"runbook.json: '{key}' fehlt Felder: {sorted(missing)}")
    if len(data) < 1:
        raise SystemExit("runbook.json: leer")
    return data


def render(data: dict[str, dict[str, object]]) -> str:
    out = [
        MARKER_START,
        "**Generiert** aus [`lib/runbook.json`](../lib/runbook.json) (SSoT) — nicht von Hand",
        "pflegen. Das CLI liest dieselbe Datei; neu erzeugen: `python3 scripts/gen_runbook.py`,",
        "pruefen: `--check` (laeuft in `order-lint`).",
        "",
        "Aufruf je Knopf: `medinix triage <id>` (oder `medinix triage <bereich|service>`).",
        "",
    ]
    for key in sorted(data):
        e = data[key]
        out.append(f"### `{key}` — {e['symptom']}")
        out.append("")
        out.append("```json")
        out.append(json.dumps({key: e}, ensure_ascii=False, indent=2, sort_keys=True))
        out.append("```")
        out.append("")
    out.append(MARKER_END)
    return "\n".join(out)


def main() -> int:
    block = render(load())
    text = DOC.read_text(encoding="utf-8")
    if MARKER_START not in text:
        raise SystemExit(f"{DOC}: Marker {MARKER_START} fehlt")
    new = re.sub(
        re.escape(MARKER_START) + r".*?" + re.escape(MARKER_END), block, text, flags=re.S
    )
    if "--check" in sys.argv:
        if new != text:
            print("docs/RUNBOOK.md Playbooks sind veraltet — 'python3 scripts/gen_runbook.py' ausfuehren.")
            return 1
        print("Runbook-Playbooks in docs/RUNBOOK.md sind aktuell.")
        return 0
    DOC.write_text(new, encoding="utf-8")
    print(f"Runbook-Playbooks geschrieben ({len(load())} Eintraege)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
