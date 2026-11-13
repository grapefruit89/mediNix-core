# reviews/ — eine Scheibe, eine Frage

Methode übernommen aus dem DIN-BriefNEO-Handoff (2026-11-13), angepasst auf mediNix:
**ein Thema isoliert prüfen**, statt einen Fat Review über das ganze Repo zu schicken.

## Warum

Ein Review über alles liefert viele Zahlen, und die veralten zwischen Schreiben und
Lesen. Eine Scheibe ist klein genug, dass jede Zahl am Objekt nachrechenbar ist.

## Der Ablauf in fünf Schritten

**1. Scheibe schneiden.**
Eine Frage, **2–4 Dateien**, ein Messblock. Passt die Frage nicht in einen Satz, sind es
zwei Scheiben. Mehr als vier Dateien heißt: Schnitt zu grob.

**2. Messen, bevor der Prompt geschrieben wird.**
Read-only am Objekt (Repo, laufendes System), nie aus dem Gedächtnis. Die Messwerte kommen
**in den Prompt**, nicht in eine Datei, die drei Commits später veraltet ist. Die
Messmethode mitschreiben (`grep`-Muster, `nix eval`-Pfad, `ss`-Filter) — sonst ist die Zahl
nicht prüfbar.

**3. `prompt.md` schreiben** — Pflichtbausteine in dieser Reihenfolge:

1. **Rolle:** „du änderst nichts, du prüfst".
2. **Harte Regeln:** ADR-0000, Baseline, Verbote (`mkForce`-Bann, Zero-Container, …).
3. **Was bereits erledigt ist** — als Tabelle. Ohne diesen Block meldet der Reviewer
   erledigte Befunde erneut.
4. **Aufgaben mit Gegenprobe:** „nenne Nummern, keine Meinung"; „welcher Nachweis fehlt
   heute, wie prüft man ihn in einem Satz".
5. **Messwerte** mit Datum und Methode.
6. **Antwortform:** kurz, Beleg pro Behauptung, ohne Beleg `ungeprüft` + Gegenprobe,
   am Ende A/B/C mit Kosten.
7. **Verbote:** keine Wiederholung erledigter Befunde; entschiedene Themen nur mit
   **neuem** Messwert; keine Screenshots als Beweis.

**4. Anhang bauen.**

```bash
mkdir -p /home/moritz/repos/mediNix-core/reviews/2026-11-13-mein-thema
cat > /home/moritz/repos/mediNix-core/reviews/2026-11-13-mein-thema/files.txt <<'EOF'
/home/moritz/repos/mediNix-core/51-ingress/515-blocky.nix
/home/moritz/repos/mediNix-core/50-core/registry.nix
EOF

python3 /home/moritz/repos/mediNix-core/scripts/review-slice.py \
  /home/moritz/repos/mediNix-core/reviews/2026-11-13-mein-thema
```

Angehängt wird **nur `merge.txt`** plus `prompt.md` als Text. Der Bauer bricht ab, wenn ein
Pfad außerhalb des Repos liegt oder eine Datei fehlt; bei mehr als vier Dateien warnt er.
`merge.txt` ist Build-Output und wird nicht versioniert.

**5. Auswerten, nicht übernehmen.** Jeden Befund am Code oder am laufenden System
nachrechnen. Drei Sorten:

| Sorte | Umgang |
|---|---|
| belegt und heute noch wahr | umsetzen, Messung vorher/nachher |
| belegt, aber inzwischen erledigt | verwerfen, im Ledger vermerken |
| plausibel, aber „ungeprüft" | nachmessen, dann entscheiden — nie auf Verdacht bauen |

## Nachbereiten

Erkenntnisse gehören nicht in den Chat: Behoben → `docs/AUDIT-LEDGER.md` (L-NNN) und
`todo/tasks.json`. Offen → Task mit `acceptance` + `research`. Danach die Leiter:
`bash /home/moritz/repos/mediNix-core/scripts/verify.sh`.

## Fallen (aus DIN-BriefNEO übernommen)

- **Der Anhang ist der Arbeitsbaum, nicht der Commit.** Verbindlich ist die SHA256-Tabelle.
- **Der Anhang veraltet im nächsten Commit.** Nach einem Umbau: neue Scheibe, nicht den
  alten Prompt nachschieben.
- **Zahlen sind Versprechen.** Wer eine Zahl in den Prompt schreibt, liefert die Zählweise.
- **Ein Reviewer, der nicht rechnet, ist nutzlos.** Die brauchbarsten Korrekturen kommen
  aus Gegenproben, nicht aus Urteilen.
