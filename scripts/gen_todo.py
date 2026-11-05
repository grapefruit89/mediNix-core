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


def tasks_open() -> dict[str, list[dict]]:
    """Offene Arbeit aus todo/tasks.json — der einzigen Handquelle (2026-11-05)."""
    data = json.loads((ROOT / "todo" / "tasks.json").read_text(encoding="utf-8"))
    by_priority: dict[str, list[dict]] = {"high": [], "medium": [], "low": []}
    for t in data["tasks"]:
        if t.get("status") not in ("open", "in_progress", "blocked"):
            continue
        by_priority.setdefault(t.get("priority", "medium"), []).append(t)
    return by_priority


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
    by_priority = tasks_open()
    decisions, n_blacklist = corridor_items()
    open_ledger = ledger_open()
    n_open = sum(len(v) for v in by_priority.values())

    L = [
        "# TODO — mediNix-core",
        "",
        f"> **Generiert** aus tasks.json + Korridor + Ledger am {date.today().isoformat()}.",
        "> Nicht von Hand pflegen — Inhalte gehören in die Quellen:",
        "> `todo/tasks.json` (offene Arbeit, validiert durch `scripts/check_tasks.py`),",
        "> `.agent-state.json` (Entscheidungen), `docs/AUDIT-LEDGER.md` (Befunde).",
        f"> Neu erzeugen: `python3 scripts/gen_todo.py` · Prüfen: `python3 scripts/gen_todo.py --check`.",
        "",
        "## 1. Offene Entscheidungen (Korridor)",
        "",
    ]
    L += [f"- [ ] {d}" for d in decisions] or ["- (keine)"]
    L += ["", f"## 2. Offene Arbeit — `todo/tasks.json` ({n_open})", ""]
    L.append(f"_Eine Quelle. Validierung: `python3 scripts/check_tasks.py` · "
             f"Blacklist-Regeln im Korridor: {n_blacklist}_")
    label = {"high": "hoch", "medium": "mittel", "low": "niedrig"}
    for pri in ("high", "medium", "low"):
        entries = by_priority.get(pri) or []
        if not entries:
            continue
        L += ["", f"### {label[pri]} ({len(entries)})", ""]
        for t in entries:
            legacy = " _(Status ungeprüft)_" if t.get("legacy") else ""
            L.append(f"- [ ] `{t['id']}` {t['title']}{legacy}")
    if n_open == 0:
        L.append("- (keine)")
    L += ["", "## 3. Ledger — Befunde ohne Abschluss", ""]
    L += [f"- [ ] {e}" for e in open_ledger] or ["- (keine)"]
    L += ["", "## 4. Pflicht bei jeder Änderung", "",
          "- [ ] Diff vorlegen, Go abwarten (AGENTS.md).",
          "- [ ] Volle Prüf-Leiter: nixfmt-Sweep, 5 Checks **bauen**, `nix flake check`, docs-Paket.",
          "- [ ] Erst lokal messen, dann **ein** Push (Korridor-Regel).",
          ""]
    return "\n".join(L)


def _undated(text: str) -> str:
    """Datum aus der Kopfzeile entfernen — der Check prueft Inhalt, nicht den Kalender."""
    return re.sub(r"am \d{4}-\d{2}-\d{2}", "am <DATUM>", text)


def main() -> int:
    text = render()
    if "--check" in sys.argv:
        current = TODO.read_text(encoding="utf-8") if TODO.exists() else ""
        if _undated(current) != _undated(text):
            print("docs/TODO.md ist veraltet — 'python3 scripts/gen_todo.py' ausfuehren.")
            return 1
        print("docs/TODO.md ist aktuell.")
        return 0
    TODO.write_text(text, encoding="utf-8")
    print(f"docs/TODO.md geschrieben ({len(text.splitlines())} Zeilen)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
