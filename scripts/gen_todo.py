#!/usr/bin/env python3
"""Erzeugt docs/TODO.md als ABLEITUNG aus Korridor + Roadmap + Ledger.

Warum generiert: eine handgepflegte TODO-Liste waere eine zweite Planungsquelle
(Blacklist AB-015 "dritte Roadmap-Datei"). Die Quellen bleiben:
  .agent-state.json (corridor)  -> offene Entscheidungen + Blacklist-Themen
  ROADMAP.md                    -> Backlog (P1..P3, offene Checkboxen)
  docs/AUDIT-LEDGER.md          -> Befunde mit Status != DONE

Aufruf:  python3 scripts/gen_todo.py           (schreibt docs/TODO.md)
         python3 scripts/gen_todo.py --check   (Exit 1, wenn veraltet)
"""

from __future__ import annotations

import json
import re
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TODO = ROOT / "docs" / "TODO.md"


def roadmap_items() -> tuple[list[str], list[str]]:
    """(blockname, offene punkte) je Roadmap-Abschnitt."""
    text = (ROOT / "ROADMAP.md").read_text(encoding="utf-8")
    sections: list[tuple[str, list[str]]] = []
    current = ("(ohne Abschnitt)", [])
    for line in text.splitlines():
        if line.startswith("## "):
            if current[1]:
                sections.append(current)
            current = (line[3:].strip(), [])
        elif line.startswith("- [ ] "):
            current[1].append(line[6:].strip())
    if current[1]:
        sections.append(current)
    if not sections:
        return [], []
    return [s[0] for s in sections], [f"{name}: {item}" for name, items in sections for item in items]


def corridor_items() -> tuple[list[str], int]:
    data = json.loads((ROOT / ".agent-state.json").read_text(encoding="utf-8"))
    c = data["corridor"]
    return [d.get("frage", str(d)) for d in c["open_decisions"]], len(c["blacklist"])


def _cells(line: str) -> list[str]:
    """Tabellenzeile in Zellen zerlegen; escapte Pipes (`\\|`) bleiben Inhalt."""
    return [c.strip().replace("\x00", "|") for c in line.replace("\\|", "\x00").strip().strip("|").split("|")]


def ledger_open() -> list[str]:
    """Befunde, deren Status-Spalte nicht DONE/REVERTED/WONTFIX ist."""
    out = []
    for line in (ROOT / "docs" / "AUDIT-LEDGER.md").read_text(encoding="utf-8").splitlines():
        if not re.match(r"\| L-\d+ \|", line):
            continue
        cells = _cells(line)
        if len(cells) < 7:
            continue
        lid, area, where, finding, evidence, fix, status = cells[:7]
        if status.replace("*", "").strip().upper().startswith(("DONE", "REVERTED", "WONTFIX")):
            continue
        out.append(f"{lid} ({area}) {finding[:150]} — Status: {status or 'offen'}")
    return out


def render() -> str:
    blocks, backlog = roadmap_items()
    decisions, n_blacklist = corridor_items()
    open_ledger = ledger_open()

    L = [
        "# TODO — mediNix-core",
        "",
        f"> **Generiert** aus Korridor + Roadmap + Ledger am {date.today().isoformat()}.",
        "> Nicht von Hand pflegen — Inhalte gehören in die Quellen:",
        "> `.agent-state.json` (Entscheidungen), `ROADMAP.md` (Planung), `docs/AUDIT-LEDGER.md` (Befunde).",
        f"> Neu erzeugen: `python3 scripts/gen_todo.py` · Prüfen: `python3 scripts/gen_todo.py --check`.",
        "",
        "## 1. Offene Entscheidungen (Korridor)",
        "",
    ]
    L += [f"- [ ] {d}" for d in decisions] or ["- (keine)"]
    L += ["", "## 2. Roadmap — offene Punkte", ""]
    if blocks:
        L.append(f"_Abschnitte: {', '.join(blocks)} · Blacklist-Regeln im Korridor: {n_blacklist}_")
        L.append("")
    L += [f"- [ ] {b}" for b in backlog] or ["- (keine)"]
    L += ["", "## 3. Ledger — Befunde ohne Abschluss", ""]
    L += [f"- [ ] {e}" for e in open_ledger] or ["- (keine)"]
    L += ["", "## 4. Pflicht bei jeder Änderung", "",
          "- [ ] Diff vorlegen, Go abwarten (AGENTS.md).",
          "- [ ] Volle Prüf-Leiter: nixfmt-Sweep, 5 Checks **bauen**, `nix flake check`, docs-Paket.",
          "- [ ] Erst lokal messen, dann **ein** Push (Korridor-Regel).",
          ""]
    return "\n".join(L)


def main() -> int:
    text = render()
    if "--check" in sys.argv:
        current = TODO.read_text(encoding="utf-8") if TODO.exists() else ""
        if current != text:
            print("docs/TODO.md ist veraltet — 'python3 scripts/gen_todo.py' ausfuehren.")
            return 1
        print("docs/TODO.md ist aktuell.")
        return 0
    TODO.write_text(text, encoding="utf-8")
    print(f"docs/TODO.md geschrieben ({len(text.splitlines())} Zeilen)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
