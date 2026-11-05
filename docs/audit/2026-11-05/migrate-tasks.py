#!/usr/bin/env python3
"""Einmalige Migration: alle Todo-Quellen -> todo/tasks.json.

Quellen (jede Zeile wird genau einmal konsumiert, der Report weist es nach):
  1. todo/backlog/*.md          kuratierte Tabelle mit stabilen IDs (R47, B-M4, ...)
  2. ROADMAP.md                 offene Checkboxen (die 4 ohne Backlog-Referenz)
  3. todo/blocks/*.json         next_steps + open_questions (Chat-Extrakte)
  4. docs/TODO.md               NICHT migriert: generiert aus ROADMAP

Nicht migriert (eigener Lebenszyklus, bleiben eigene Dateien):
  - docs/AUDIT-LEDGER.md   Findings-Log (keine OPEN/WIP-Zeilen mehr)
  - todo/decisions.json    aus blocks.decisions generiert
  - .agent-state.json      Agenten-Gedaechtnis (Sackgassen), kein Todo

Aufruf: python3 docs/audit/2026-11-05/migrate-tasks.py [--write]
Ohne --write wird nur der Report auf stdout gedruckt.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TASKS = ROOT / "todo" / "tasks.json"
REPORT = ROOT / "docs" / "audit" / "2026-11-05" / "migration-report.md"
DATE = "2026-11-05"

PRIORITY_FROM_EFFORT = {
    "GROSS": "medium", "MITTEL": "medium", "klein": "low", "offen": "medium",
}
KIND_FROM_CHAR = [
    ("Sicherheit", "security"), ("Build-Blocker", "bug"), ("Gate", "bug"),
    ("Struktur", "refactor"), ("Kosmetik", "docs"), ("Doku", "docs"),
    ("Feature", "feature"), ("Observability", "feature"),
]


def norm(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[`*_\[\]()\"'„“]", "", s)
    s = re.sub(r"[^a-z0-9äöüß ]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def first_sentence(text: str, limit: int = 110) -> str:
    """Titel = erste Sinneinheit. Bricht an Gedankenstrich oder Satzende,
    aber NICHT an Abkuerzungen wie 'vs.' (sonst wird 'caddyClass vs.' zum Titel)."""
    text = re.sub(r"\*\*", "", text).strip()
    text = re.sub(r"^[„\"']", "", text)
    for sep in (" — ", " – "):
        if sep in text:
            head = text.split(sep)[0]
            if len(head) >= 12:
                text = head
            break
    m = re.match(r"^(.{20,}?[.:])\s+(?=[A-ZÄÖÜ„])", text)
    if m:
        text = m.group(1)
    text = text.rstrip(" .")
    return (text[:limit].rstrip() + "…") if len(text) > limit else text


def parse_backlog():
    """-> list of dict: id,title,effort,char,refs,section,file,line,notes,status"""
    rows = []
    for f in sorted((ROOT / "docs" / "audit" / "2026-11-05" / "todo-backlog").glob("*.md")):
        section = ""
        for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if line.startswith("## "):
                section = line[3:].strip()
            m = re.match(r"^\|\s*\*\*([^*]+)\*\*\s*\|", line)
            if not m or m.group(1).strip() == "Summe":
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            tid = m.group(1).strip()
            done = "erledigt" in section.lower()
            rows.append({
                "id": tid,
                "title": first_sentence(cells[1]),
                "effort": cells[2] if len(cells) > 2 else "",
                "char": cells[3] if len(cells) > 3 else "",
                "refs": cells[4] if len(cells) > 4 else "",
                "section": section,
                "file": "docs/audit/2026-11-05/todo-backlog/" + f.name,
                "line": i,
                "notes": cells[1],
                "status": "done" if done else "open",
            })
    return rows


def parse_roadmap():
    out = []
    for i, line in enumerate((ROOT / "ROADMAP.md").read_text(encoding="utf-8").splitlines(), 1):
        if re.match(r"^- \[ \]", line):
            out.append({"line": i, "text": line[6:].strip()})
    return out


def kind_of(char: str) -> str:
    for needle, kind in KIND_FROM_CHAR:
        if needle.lower() in char.lower():
            return kind
    return "feature"


def priority_of(effort: str, char: str = "") -> str:
    e = f"{effort} {char}".upper()
    if "P0" in e or "BLOCKER" in e or "GROSS" in e:
        return "high"
    if "P1" in e or "HOCH" in e:
        return "high"
    if "P2" in e or "MITTEL" in e or "MEDIUM" in e:
        return "medium"
    if "P3" in e or "KLEIN" in e or "LOW" in e:
        return "low"
    return "medium"


def main(write: bool) -> int:
    backlog = parse_backlog()
    roadmap = parse_roadmap()
    tasks: dict[str, dict] = {}
    report = []

    # ---- 1) Backlog -> Tasks (kuratiert, stabilste IDs) ----
    road_consumed = {}
    for r in backlog:
        for rl in re.findall(r"ROADMAP\.md:(\d+)", r["refs"]):
            road_consumed.setdefault(int(rl), r["id"])
        tasks[r["id"]] = {
            "id": r["id"],
            "title": r["title"],
            "kind": kind_of(r["char"]),
            "status": r["status"],
            "priority": priority_of(r["effort"], r["char"]),
            "legacy": False,
            "source": {
                "type": "backlog",
                "ref": f"{r['file']}:{r['line']}",
                "date": DATE,
                "evidence": [x.strip() for x in re.split(r"[·,]", r["refs"]) if x.strip()],
            },
            "why": r["notes"],
            "steps_open": [],
            "steps_done": ([{"date": DATE, "what": "in todo/backlog als erledigt gefuehrt"}] if r["status"] == "done" else []),
            "notes": f"{r['section']} · Aufwand: {r['effort']} · Charakter: {r['char']}",
            "depends_on": [],
            "links": [],
        }
        report.append(("backlog", f"{r['id']:9s}", r["id"]))

    # ---- 2) ROADMAP-Zeilen ohne Backlog-Referenz ----
    for item in roadmap:
        if item["line"] in road_consumed:
            continue
        tid = f"R{item['line']}"
        if tid in tasks:
            # Kollision: der Backlog fuehrt dieselbe Nummer bereits (z. B. R92 als
            # erledigt, waehrend ROADMAP.md:92 die Zeile noch offen zeigt).
            # NICHT ueberschreiben - die ROADMAP-Zeile wird Beleg am bestehenden Task.
            tasks[tid]["source"]["evidence"].append(f"ROADMAP.md:{item['line']}: {item['text'][:160]}")
            tasks[tid]["notes"] = (tasks[tid]["notes"] +
                                   " ROADMAP.md fuehrt die Zeile noch als offen - dort nachziehen.")
            report.append(("roadmap", f"Zeile {item['line']}", f"{tid} (in bestehenden Task zusammengefuehrt)"))
            continue
        tasks[tid] = {
            "id": tid,
            "title": first_sentence(item["text"]),
            "kind": "feature",
            "status": "open",
            "priority": "medium",
            "legacy": False,
            "source": {
                "type": "roadmap",
                "ref": f"ROADMAP.md:{item['line']}",
                "date": DATE,
                "evidence": [item["text"][:200]],
            },
            "why": item["text"],
            "steps_open": [item["text"]],
            "steps_done": [],
            "notes": "Nur in ROADMAP.md gefuehrt, kein Backlog-Eintrag.",
            "depends_on": [],
            "links": [],
        }
        report.append(("roadmap", f"Zeile {item['line']}", tid))

    # ---- 3) Chat-Blocks: next_steps ----
    for f in sorted((ROOT / "todo" / "blocks").glob("*.json")):
        b = json.loads(f.read_text(encoding="utf-8"))
        bid = b["block_id"]
        for s in b.get("next_steps") or []:
            action = (s.get("action") or "").strip()
            if action.lower() in ("keine", "-", ""):
                continue
            tid = s["id"]
            if tid in tasks:
                report.append(("block-step", tid, f"UEBERSPRUNGEN (ID existiert: {tid})"))
                continue
            tasks[tid] = {
                "id": tid,
                "title": first_sentence(action),
                "kind": "feature",
                "status": "open",
                "priority": s.get("priority", "medium"),
                "legacy": True,
                "source": {
                    "type": "chat-block",
                    "ref": f"todo/blocks/{f.name}#{tid}",
                    "date": DATE,
                    "evidence": [b.get("summary", "")[:200]],
                },
                "why": action,
                "steps_open": [action],
                "steps_done": [],
                "notes": f"Legacy-Extrakt aus Chat-Block {bid}. Status ungeprueft (vor 2026-11-04).",
                "depends_on": s.get("depends_on") or [],
                "links": [],
            }
            report.append(("block-step", tid, tid))
        for q in b.get("open_questions") or []:
            tid = q["id"]
            if tid in tasks:
                report.append(("block-question", tid, f"UEBERSPRUNGEN (ID existiert: {tid})"))
                continue
            tasks[tid] = {
                "id": tid,
                "title": first_sentence(q["question"]),
                "kind": "decision",
                "status": "open",
                "priority": "high" if q.get("blocking") else "medium",
                "legacy": False,
                "source": {
                    "type": "chat-question",
                    "ref": f"todo/blocks/{f.name}#{tid}",
                    "date": DATE,
                    "evidence": [b.get("summary", "")[:200]],
                },
                "why": q.get("why_open", ""),
                "steps_open": [q["question"]],
                "steps_done": [],
                "notes": f"Offene Frage aus Chat-Block {bid}." + (" BLOCKING." if q.get("blocking") else ""),
                "depends_on": [],
                "links": [],
            }
            report.append(("block-question", tid, tid))

    # ---- 4) Erledigte: DONE_COMMITS des abgeloesten Aggregats, fest uebernommen ----
    # Quelle war todo/plan.json bzw. todo/scripts/aggregate.py (heute
    # docs/audit/2026-11-05/aggregate.py.retired). Hier eingefroren, damit die
    # Migration ohne den alten Generator reproduzierbar bleibt.
    DONE_COMMITS = {
        "N-22-01": "90553ad", "N-23-01": "f3153df", "N-23-02": "f3153df",
        "N-24-01": "21ca67f", "N-29-01": "6d82119", "N-29-02": "6d82119",
    }
    for tid, commit in DONE_COMMITS.items():
        if tid in tasks:
            tasks[tid]["status"] = "done"
            tasks[tid]["steps_done"] = [{
                "date": DATE, "what": "abgeschlossen (Commit aus dem alten Aggregat)",
                "commit": commit,
            }]

    # ---- schreiben ----
    ordered = sorted(tasks.values(), key=lambda t: (
        {"high": 0, "medium": 1, "low": 2}.get(t["priority"], 3),
        {"open": 0, "done": 1, "rejected": 2}.get(t["status"], 3),
        t["id"],
    ))
    payload = {
        "version": 1,
        "generated_from": "migration 2026-11-05 (docs/audit/2026-11-05/migrate-tasks.py)",
        "validated_by": "scripts/check_tasks.py",
        "tasks": ordered,
    }

    stats = {
        "tasks": len(ordered),
        "open": sum(1 for t in ordered if t["status"] == "open"),
        "done": sum(1 for t in ordered if t["status"] == "done"),
        "legacy": sum(1 for t in ordered if t["legacy"]),
        "decisions": sum(1 for t in ordered if t["kind"] == "decision"),
    }

    lines = ["# Migrations-Report: Todo-Quellen -> todo/tasks.json", "",
             f"Stand: {DATE} · Skript: `docs/audit/2026-11-05/migrate-tasks.py`", "",
             "## Bilanz", "", "| Quelle | Items | Ziel |", "|---|---:|---|"]
    for src in ("backlog", "roadmap", "block-step", "block-question"):
        n = sum(1 for r in report if r[0] == src)
        lines.append(f"| {src} | {n} | tasks.json |")
    lines += ["", "## Ergebnis", ""] + [f"- {k}: **{v}**" for k, v in stats.items()]
    lines += ["", "## Zeile fuer Zeile", "", "| Quelle | Original | Task-ID |", "|---|---|---|"]
    lines += [f"| {a} | `{b}` | `{c}` |" for a, b, c in report]

    print("\n".join(lines[:16]))
    print(f"\n... {len(report)} Quellzeilen abgebildet, {len(ordered)} Tasks")

    if write:
        TASKS.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        REPORT.parent.mkdir(parents=True, exist_ok=True)
        REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"geschrieben: {TASKS.relative_to(ROOT)} , {REPORT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main("--write" in sys.argv))
