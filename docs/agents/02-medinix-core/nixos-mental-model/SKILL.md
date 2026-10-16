---
name: nixos-mental-model
description: "Denkrahmen für NixOS-Arbeit in mediNix-core. Laden beim Schreiben/Ändern von NixOS-Modulen, Flakes, systemd-Units oder Optionen — erkennt Klassische-Distro-Reflexe (imperativ, mutabel, eager) VOR dem Tippen und ordnet die typischen Fallen (faul, zyklische Ableitung, hermetisch, zweistufig) ein."
---

# NixOS-Mentalmodell (mediNix-core)

## Wofür

Dein Trainingswissen kommt aus klassischen Distributionen. **Diese Reflexe sind dort
richtig und hier falsch.** Dieser Skill ordnet ein, *welche* NixOS-Eigenschaft gerade
relevant ist — bevor du tippst.

## Die vier Fallen, die uns real getroffen haben

| Falle | Symptom | Prüffrage | Beweis/Fix |
|---|---|---|---|
| **Faul (lazy)** | Guardrail „ist da", greift aber nicht | *Liest jemand diesen Wert?* | Assertion, die das Feld explizit anfasst; Negativtest mit Grund |
| **Zyklische Ableitung** | `error: infinite recursion encountered` | *Lese ich eine Quelle, aus der ich (oder ein Modul mit meiner Ableitung) Ableitungen schreibe?* | **ADR-040**: Kanten nur Quelle → Ableitung; Guardrails lesen statische SSoT (`lib/registry.nix`) oder Absichts-Optionen, nie `manifest`, wenn sie das Abgeleitete prüfen |
| **Hermetisch** | Datei geschrieben, Build sieht sie nicht | *Ist die Datei getrackt?* | `git add -N <datei>` **vor** jeder Messung (AB-032) |
| **Zweistufig (Eval ≠ Build)** | lokal grün, CI rot | *Baue ich die Checks auch?* | `nix build .#checks.x86_64-linux.<check>` explizit; nie nur `--no-build` (L-036) |

„Rein" im engeren Sinn (`builtins.currentTime`, `getEnv`, `import <nixpkgs>`, `--impure`)
ist ein **eigenes** P0-Thema (Determinismus) — nicht zu verwechseln mit der zyklischen
Ableitung.

## Halt-Reflexe (wenn du das bei dir bemerkst: stoppen)

- Du editierst strukturierte Daten (`*.json`, Korridor) per `sed`/Textersetzung → **AB-037**: Werkzeug (`scripts/agent-state-edit.py`) oder Bibliothek.
- Du ersetzt ein systemd-Primitiv durch einen eigenen Watcher → **AB-034**.
- Du baust eine dritte Ablage für dieselbe Information → **AB-039/AB-031** (Ableitung statt Pflege).
- Du schreibst „mal eben" etwas nach `/etc` → im nächsten Rebuild weg.
- Du hoffst, dass es funktioniert → **beweise** es (Leiter, Negativtest).

## Zwei-Versuche-Stop (AB-038)

Zwei Versuche mit **derselben Methode** (Detail-Variante) sind verschwendet.
Nach dem zweiten Fehlschlag: **Methode wechseln** und dem Menschen berichten.

## Referenzen

- `docs/concepts/nixos-eigenschaften.md` — die vollständige Liste mit Belegen
- `docs/adr/ADR-040-gerichtete-abhaengigkeiten.md`
- `docs/adr/ADR-0000-dezimalrahmen-verfassung.md`
- `.agent-state.json` → `corridor.blacklist`

## Belegsammlung: Eval-Blocker, Assertions vs. Checks

`references/eval-blocker-assertions-und-checks.md` - sechs Kurzregeln mit Belegen:
bisect-first bei Eval-Blockern, Fixpunkt-Kreuz, Assertions laufen waehrend der Config-Auswertung
(abgeleitetes Ergebnis -> `checks.*`), Engine-Defaults vs. nixpkgs-Assertions, "ein Check-Ausgang
ist kein Ursachenbeleg", gueltige Mess-Metrik + Build-Gates, die `--no-build` verdeckt.
