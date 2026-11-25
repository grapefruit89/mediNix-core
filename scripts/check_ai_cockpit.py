#!/usr/bin/env python3
# ---
# id: "check-ai-cockpit"
# title: "Budget-Gate fuer das Repository-Cockpit (AGENTS.md/map.md)"
# domain: 50
# folder: "scripts"
# status: active
# kind: tooling
# complexity: 1
# last_reviewed: 2026-11-26
# links:
#   adr: ADR-0000
# ---
"""Prueft die Budgets des Repository-Cockpits (LLM-ordnerstruktur Baustein B).

Warum: Das Cockpit kapselt das Repo fuer Agenten (AGENTS.md = Verhalten,
map.md = Navigation). Ohne mechanisches Gate waechst der Text zurueck zum alten
Zustand und der Token-Gewinn ist nach wenigen Sitzungen weg.

Regeln:
  1. AGENTS.md existiert, <= 70 Zeilen, <= 500 Woerter, <= 4000 Bytes.
  2. map.md existiert, <= 100 Zeilen, <= 700 Woerter, <= 5500 Bytes.
  3. CLAUDE.md und GEMINI.md existieren als Zeiger auf das Cockpit.

Exit: 0 gruen, 1 bei fehlender Datei oder Budget-Ueberschreitung.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# name: (max_lines, max_words, max_bytes)
BUDGETS = {
    "AGENTS.md": (70, 500, 4000),
    "map.md": (100, 700, 5500),
}
POINTERS = ("CLAUDE.md", "GEMINI.md")


def main() -> int:
    failed = False

    for name, (max_lines, max_words, max_bytes) in BUDGETS.items():
        path = ROOT / name
        if not path.is_file():
            print(f"FEHLT   {name}: Datei nicht gefunden")
            failed = True
            continue

        raw = path.read_bytes()
        text = raw.decode("utf-8")
        lines = len(text.splitlines())
        words = len(text.split())
        size = len(raw)

        ok_lines = lines <= max_lines
        ok_words = words <= max_words
        ok_size = size <= max_bytes

        status = "OK  " if (ok_lines and ok_words and ok_size) else "ROT "
        print(
            f"{status}    {name}: {lines}/{max_lines} Zeilen, "
            f"{words}/{max_words} Woerter, {size}/{max_bytes} Bytes"
        )
        if not (ok_lines and ok_words and ok_size):
            failed = True

    for ptr in POINTERS:
        path = ROOT / ptr
        if not path.is_file():
            print(f"FEHLT   {ptr}: Pointer-Datei nicht gefunden")
            failed = True
        else:
            print(f"OK      {ptr}: vorhanden")

    if failed:
        print("Cockpit-Budget verletzt.")
        return 1
    print("Cockpit-Budget eingehalten.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
