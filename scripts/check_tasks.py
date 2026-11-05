#!/usr/bin/env python3
# ---
# id: "check-tasks"
# title: "Validator fuer todo/tasks.json (eine Quelle, keine Leichen)"
# domain: 50
# folder: "scripts"
# status: active
# kind: tooling
# complexity: 2
# last_reviewed: 2026-11-05
# links:
#   adr: ADR-0000
# ---
"""Prueft todo/tasks.json — die einzige Handquelle fuer offene Arbeit.

Warum: Bis 2026-11-05 gab es fuenf Oberflaechen mit fuenf verschiedenen Zahlen
(ROADMAP 26, docs/TODO.md 36, backlog ~20, plan.json 63, blocks 39+18). Keine war
falsch, jede zaehlte etwas anderes — niemand konnte den ehrlichen Stand nennen.
Ohne Pruefer driftet auch eine einzelne Datei wieder (`plan.json` sah 2026-10-25
schon einmal richtig aus).

Geprueft wird:
  1. JSON-Struktur (version, tasks[])
  2. `id` eindeutig und im Namensschema
  3. `status`, `priority`, `kind` aus den erlaubten Wertebereichen
  4. `title` vorhanden und <= 160 Zeichen
  5. `source.ref` vorhanden; bei `pfad:zeile` muss die Datei existieren und die
     Zeile im Bereich liegen — genau dieser Test haette die lib/-Leichen gefunden
  6. `why` oder `steps_open` nicht leer (eine Aufgabe ohne Begruendung ist keine)
  7. `depends_on` zeigt auf existierende IDs, kein Zyklus
  8. keine zwei Tasks mit derselben `source.ref` (Dubletten)
  9. `status: done` braucht `steps_done`

Hinweise (kein Fehler): Tasks mit `legacy: true` sind Status ungeprueft.

Exit: 0 gruen (auch mit Hinweisen), 1 bei Fehlern.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TASKS = ROOT / "todo" / "tasks.json"

ID_RE = re.compile(r"^[A-Z][A-Za-z0-9]*(-[A-Za-z0-9]+)*$")
STATUS = {"open", "in_progress", "blocked", "done", "rejected"}
PRIORITY = {"high", "medium", "low"}
KIND = {"bug", "feature", "docs", "refactor", "security", "decision", "chore"}
REF_RE = re.compile(r"^(?P<path>[^:#]+?)(?::(?P<line>\d+))?(?:#[^#]*)?$")


def main() -> int:
    errors: list[str] = []
    hints: list[str] = []

    if not TASKS.exists():
        print(f"FEHLT: {TASKS.relative_to(ROOT)}")
        return 1
    try:
        data = json.loads(TASKS.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"KEIN GUELTIGES JSON: {e}")
        return 1

    tasks = data.get("tasks")
    if not isinstance(tasks, list):
        print("STRUKTUR: 'tasks' fehlt oder ist keine Liste")
        return 1

    ids: dict[str, dict] = {}
    refs: dict[str, str] = {}

    for t in tasks:
        tid = t.get("id", "<ohne id>")
        where = f"Task {tid}"

        if not ID_RE.match(tid):
            errors.append(f"{where}: id verletzt das Namensschema ({ID_RE.pattern})")
        if tid in ids:
            errors.append(f"{where}: doppelte id")
        ids[tid] = t

        if t.get("status") not in STATUS:
            errors.append(f"{where}: status '{t.get('status')}' nicht in {sorted(STATUS)}")
        if t.get("priority") not in PRIORITY:
            errors.append(f"{where}: priority '{t.get('priority')}' nicht in {sorted(PRIORITY)}")
        if t.get("kind") not in KIND:
            errors.append(f"{where}: kind '{t.get('kind')}' nicht in {sorted(KIND)}")

        title = (t.get("title") or "").strip()
        if not title:
            errors.append(f"{where}: title fehlt")
        elif len(title) > 160:
            errors.append(f"{where}: title {len(title)} Zeichen (> 160)")

        src = t.get("source") or {}
        ref = (src.get("ref") or "").strip()
        if not ref:
            errors.append(f"{where}: source.ref fehlt")
        else:
            if ref in refs:
                errors.append(f"{where}: source.ref '{ref}' schon von {refs[ref]} benutzt (Dublette)")
            refs[ref] = tid
            m = REF_RE.match(ref)
            if m and m.group("path").endswith((".md", ".nix", ".json", ".py", ".sh")):
                p = ROOT / m.group("path")
                if not p.is_file():
                    errors.append(f"{where}: source.ref zeigt auf fehlende Datei '{m.group('path')}'")
                elif m.group("line"):
                    n = len(p.read_text(encoding="utf-8", errors="replace").splitlines())
                    if int(m.group("line")) > n:
                        errors.append(
                            f"{where}: source.ref {m.group('line')} > {n} Zeilen in {m.group('path')}")

        if not (t.get("why") or "").strip() and not (t.get("steps_open") or []):
            errors.append(f"{where}: weder why noch steps_open — Aufgabe ohne Begruendung")

        if t.get("status") == "done" and not (t.get("steps_done") or []):
            errors.append(f"{where}: status done, aber steps_done leer")

        if t.get("legacy"):
            hints.append(f"{where}: legacy — Status ungeprueft")

    # depends_on + Zyklen
    for tid, t in ids.items():
        for dep in t.get("depends_on") or []:
            if dep == tid:
                errors.append(f"Task {tid}: depends_on zeigt auf sich selbst")
            elif dep not in ids:
                errors.append(f"Task {tid}: depends_on '{dep}' existiert nicht")

    WHITE, GREY, BLACK = 0, 1, 2
    color = {tid: WHITE for tid in ids}

    def visit(node: str, stack: list[str]) -> None:
        if color.get(node) == GREY:
            errors.append("Zyklus in depends_on: " + " -> ".join(stack + [node]))
            return
        if color.get(node) == BLACK:
            return
        color[node] = GREY
        for dep in ids.get(node, {}).get("depends_on") or []:
            if dep in ids:
                visit(dep, stack + [node])
        color[node] = BLACK

    for tid in ids:
        visit(tid, [])

    for h in hints:
        print(f"HINWEIS: {h}")
    for e in errors:
        print(f"FEHLER:  {e}")

    if errors:
        print(f"\nROT: {len(errors)} Fehler in {len(tasks)} Tasks ({len(hints)} Hinweise).")
        return 1

    print(f"OK: {len(tasks)} Tasks valide "
          f"({sum(1 for t in ids.values() if t.get('status') == 'done')} erledigt, "
          f"{len(hints)} legacy/Hinweise).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
