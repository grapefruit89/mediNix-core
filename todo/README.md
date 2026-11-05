# todo/ — eine Quelle für offene Arbeit

**Seit 2026-11-05 gibt es genau eine Handquelle: `/home/moritz/repos/mediNix-core/todo/tasks.json`.**

Vorher lagen fünf Oberflächen mit fünf verschiedenen Zahlen nebeneinander (ROADMAP 26,
`docs/TODO.md` 36, `backlog/*.md` ~20, `plan.json` 63, `blocks/*.json` 39+18). Jede war
für sich richtig, zusammen ergaben sie keinen Stand. Der Report der Zusammenführung:
`/home/moritz/repos/mediNix-core/docs/audit/2026-11-05/migration-report.md`.

## Die Datei

| Rolle | Absoluter Pfad |
| --- | --- |
| **Handquelle (offene Arbeit)** | `/home/moritz/repos/mediNix-core/todo/tasks.json` |
| Validator (Gate) | `/home/moritz/repos/mediNix-core/scripts/check_tasks.py` |
| Menschenlesbare Sicht (generiert) | `/home/moritz/repos/mediNix-core/docs/TODO.md` |
| Befunde-Log (eigener Lebenszyklus) | `/home/moritz/repos/mediNix-core/docs/AUDIT-LEDGER.md` |
| Agenten-Gedächtnis (Sackgassen) | `/home/moritz/repos/mediNix-core/.agent-state.json` |
| Archiv der Altquellen | `/home/moritz/repos/mediNix-core/docs/audit/2026-11-05/` |

## Ein Task — die Felder

```json
{
  "id": "N-29-04",
  "title": "scan_inconsistencies.py kennt ADR-0000 §14 nicht",
  "kind": "feature",          // bug | feature | docs | refactor | security | decision | chore
  "status": "open",           // open | in_progress | blocked | done | rejected
  "priority": "low",          // high | medium | low
  "legacy": false,            // true = Status ungeprüft (Altbestand)
  "source": {                 // WO kommt das her (Pflicht)
    "type": "chat-block",
    "ref": "todo/blocks/29-meta-dezimalrahmen-nacharbeit.json#N-29-04",
    "date": "2026-11-05",
    "evidence": ["Zusammenfassung des Blocks"]
  },
  "why": "Der Check meldet 8 Bibliotheken als Fehler, weil er die §14-Kategorien nicht kennt.",
  "steps_open": ["§14-bewusste Allowlist ergänzen"],
  "steps_done": [],
  "notes": "Kein Gate — weder in der Leiter noch in CI.",
  "depends_on": [],
  "links": []
}
```

Pflicht ist: `id`, `title`, `kind`, `status`, `priority`, `source.ref` und entweder
`why` oder `steps_open`. `steps_done` braucht jeder `done`-Task.

## Was das Gate erzwingt

`python3 /home/moritz/repos/mediNix-core/scripts/check_tasks.py` läuft in
`scripts/verify.sh` und in `order-lint.yml`. Es scheitert bei:

- doppelter `id` oder `id` außerhalb des Namensschemas
- unbekanntem `status` / `priority` / `kind`
- fehlendem `title`, `source.ref` oder fehlender Begründung
- **`source.ref` auf eine Datei oder Zeile, die es nicht gibt** — genau dieser Test
  hätte die `lib/`-Leichen sofort gefunden
- zwei Tasks aus derselben Quellzeile
- `depends_on` auf eine unbekannte ID oder im Kreis
- `status: done` ohne `steps_done`

`legacy: true` ist ein Hinweis, kein Fehler: Altbestand aus Chat-Blöcken, dessen
Erledigungsstand nie nachgemessen wurde. Diese Einträge werden abgearbeitet oder
geschlossen — sie verschwinden nicht durch Weglassen.

## Regeln

1. **Neue Arbeit** wird nur in `tasks.json` eingetragen — nicht in ROADMAP, nicht in
   eine neue Markdown-Liste.
2. **`docs/TODO.md` nicht von Hand ändern.** Es entsteht aus `tasks.json` + Korridor +
   Ledger: `python3 /home/moritz/repos/mediNix-core/scripts/gen_todo.py`.
3. **ID bleibt stabil**, auch nach dem Abschluss (Historie bleibt lesbar).
4. **Abschluss dokumentieren:** `status: done` + `steps_done` mit Commit.
5. **Befunde ≠ Aufgaben.** Ein Audit-Fund lebt im Ledger; wird daraus Arbeit, bekommt
   er einen Task mit `source.ref` auf die Ledger-Zeile.
6. **Keine dritte Liste.** Wer eine anlegen will, muss zuerst eine bestehende schließen.
