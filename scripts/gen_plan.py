#!/usr/bin/env python3
# ---
# id: "gen-plan"
# title: "Erzeugt docs/PLAN.md (Fahrplan) aus todo/tasks.json"
# domain: 50
# folder: "scripts"
# status: active
# kind: tooling
# complexity: 2
# last_reviewed: 2026-11-05
# links:
#   adr: ADR-0000
# ---
"""Erzeugt docs/PLAN.md als ABLEITUNG aus todo/tasks.json.

Warum generiert: ein handgeschriebener Fahrplan waere die naechste zweite
Planungsquelle - genau das Problem, das am 2026-11-05 mit fuenf Oberflaechen
beendet wurde. Die Quelle bleibt `todo/tasks.json`; hier entsteht nur die
lesbare Sicht mit Wellen, Aufwand, Abnahmekriterien und Quellen.

Aufwand ist ein Richtwert, keine Zusage:
  S <= 1 h   M <= 4 h   L > 4 h (bis 2 Tage)

Aufruf:  python3 scripts/gen_plan.py           (schreibt docs/PLAN.md)
         python3 scripts/gen_plan.py --check   (Exit 1, wenn veraltet)
"""
from __future__ import annotations

import json
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TASKS = ROOT / "todo" / "tasks.json"
DOC = ROOT / "docs" / "PLAN.md"

HOURS = {"S": 1, "M": 4, "L": 8}
WAVE_TITLE = {
    0: "Abschluss & Hygiene",
    1: "Deploy-Blocker & Datenlecks",
    2: "Entscheidungen",
    3: "Struktur & SSOT",
    4: "Gates, Betrieb & Doku",
    5: "Features (nicht freigegeben)",
}
WAVE_NOTE = {
    0: "Kleine Aufraeumarbeiten. Danach ist die Liste ehrlich kurz.",
    1: "Sicherheit vor Features: ein Host-Build-Blocker und Infra-Daten im Git-Repo.",
    2: "Jede Frage einzeln billig, blockiert aber die Folgeschritte.",
    3: "Der letzte echte SSOT-Verstoss und die grossen Refactors.",
    4: "Macht Fehler sichtbar, statt sie zu suchen.",
    5: "Braucht pro Punkt eine YAGNI-Pruefung. Mehrere Punkte doppeln bereits "
       "laufende Infrastruktur (VictoriaLogs, VictoriaMetrics) oder Pocket-ID-Features.",
}


def load() -> list[dict]:
    return json.loads(TASKS.read_text(encoding="utf-8"))["tasks"]


def render() -> str:
    tasks = load()
    open_tasks = [t for t in tasks if t.get("status") == "open"]
    by_wave: dict[int, list[dict]] = {}
    for t in open_tasks:
        by_wave.setdefault(int(t["wave"]), []).append(t)

    total_hours = sum(HOURS.get(t.get("effort", "M"), 4) for t in open_tasks)
    L = [
        "# PLAN — Fahrplan aus `todo/tasks.json`",
        "",
        f"> **Generiert** am {date.today().isoformat()} aus `todo/tasks.json` "
        f"({len(tasks)} Tasks, {len(open_tasks)} offen).",
        "> Nicht von Hand pflegen. Quelle: `todo/tasks.json`. "
        "Prüfen: `python3 scripts/gen_plan.py --check`.",
        "",
        f"**Richtwert Aufwand:** {total_hours} h netto über alle offenen Punkte "
        "(S ≤ 1 h · M ≤ 4 h · L > 4 h). Ohne Recherche, Prüf-Leiter, CI-Wartezeit "
        "und Review — real liegt das bei Faktor 1,3–1,5.",
        "",
    ]

    for wave in sorted(by_wave):
        entries = sorted(by_wave[wave], key=lambda t: ({"S": 0, "M": 1, "L": 2}.get(t.get("effort"), 3), t["id"]))
        hours = sum(HOURS.get(t.get("effort", "M"), 4) for t in entries)
        L += [f"## W{wave} — {WAVE_TITLE.get(wave, '?')} ({len(entries)} Punkte, ~{hours} h)", ""]
        if wave in WAVE_NOTE:
            L += [f"_{WAVE_NOTE[wave]}_", ""]
        L += ["| ID | Aufwand | Art | Punkt | Abnahme | Quellen |", "|---|---|---|---|---:|---:|"]
        for t in entries:
            acc = len(t.get("acceptance") or [])
            res = len(t.get("research") or [])
            title = t["title"].replace("|", "\\|")
            L.append(f"| `{t['id']}` | {t.get('effort', '?')} | {t['kind']} | {title} | {acc or '—'} | {res or '—'} |")
        L.append("")

        # Abnahme + Quellen nur fuer die Wellen, die als naechstes gebaut werden
        if wave <= 1:
            for t in entries:
                if not (t.get("acceptance") or t.get("research")):
                    continue
                L += [f"### `{t['id']}` — {t['title']}", ""]
                if t.get("acceptance"):
                    L.append("**Abnahme:**")
                    L += [f"- {a}" for a in t["acceptance"]]
                if t.get("research"):
                    L.append("")
                    L.append("**Quellen:**")
                    for r in t["research"]:
                        ref = r.get("url") or r.get("ref") or "?"
                        L.append(f"- `{r.get('type')}` · {ref}" + (f" — {r['note']}" if r.get("note") else ""))
                L.append("")

    L += [
        "## Was der Fahrplan nicht regelt",
        "",
        "- **Reihenfolge innerhalb einer Welle** ist frei; Abhängigkeiten stehen als",
        "  `depends_on` im Task.",
        "- **Welle 5 ist nicht freigegeben.** Jeder Punkt dort braucht zuerst die Frage:",
        "  brauchen wir das wirklich, oder ist es Wunschdenken?",
        "- **Schätzungen sind Richtwerte.** Die drei unsichersten Punkte: `R47`",
        "  (Architekturentscheidung), `R55`/`R56` (breite Refactors).",
        "",
    ]
    return "\n".join(L)


def _undated(text: str) -> str:
    return text.replace(f"am {date.today().isoformat()}", "am <DATUM>")


def main() -> int:
    text = render()
    if "--check" in sys.argv:
        current = DOC.read_text(encoding="utf-8") if DOC.exists() else ""
        if _undated(current) != _undated(text):
            print("docs/PLAN.md ist veraltet — 'python3 scripts/gen_plan.py' ausfuehren.")
            return 1
        print("docs/PLAN.md ist aktuell.")
        return 0
    DOC.write_text(text, encoding="utf-8")
    print(f"docs/PLAN.md geschrieben ({len(text.splitlines())} Zeilen)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
