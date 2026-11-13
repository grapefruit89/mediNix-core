---
title: AGENT-READINESS — mediNix-core
---

# AGENT-READINESS — mediNix-core

## Der eine Einstiegspunkt

**`/home/moritz/repos/mediNix-core/docs/INDEX.md`** — hier startet der Navigationstest.
Zusätzlich lädt opencode `/home/moritz/repos/mediNix-core/AGENTS.md` automatisch; die Datei
beantwortet „was darf ich", nicht „wo fange ich an".

## Die vier Schichten

| Schicht | Datei | Beantwortet die Frage |
|---|---|---|
| Einstieg | `/home/moritz/repos/mediNix-core/docs/INDEX.md` | „Wo fange ich an?" — Frage → Ort, in drei Gruppen |
| Aufgaben-Navigation | `/home/moritz/repos/mediNix-core/docs/NAVIGATION.md` | „Ich will X tun → lies A, B, C" — 4 Aufgaben, jede Falle mit Beleg |
| Regeln | `/home/moritz/repos/mediNix-core/AGENTS.md` + `docs/CONVENTIONS.md` | „Was darf ich, was nicht?" |
| Semantik je Dienst | `/home/moritz/repos/mediNix-core/docs/modules/` | „Warum ist das so gebaut?" |

Dazu der generierte Katalog: der Abschnitt „Vollständiger Index" in `docs/INDEX.md` und die
Service Map. Beide werden von Generatoren erzeugt, nicht von Hand gepflegt — CI prüft das
(`.github/workflows/docs-index.yml`: Generator laufen lassen, dann `git diff --exit-code`).

## Die Messung

Methode: frischer Agent ohne Chatverlauf, Start **nur** bei `docs/INDEX.md`, read-only.
Gezählt wird, nicht geurteilt.

| Runde | Datum | Prompt | Dateien | Fehlgriffe | grep/find | Ratestellen |
|---|---|---|---:|---:|---:|---:|
| 1 | 2026-11-13 | „589-foo anlegen, Port/UID nach Dezimalrahmen" | 17 | 3 | 1× | 6 |
| 2 | 2026-11-13 | identisch | **13** | **0** | **0×** | **4** |
| 3 | 2026-11-13 | „589-test, Port 5890, Manifest `internal`" — **nicht identisch** | 13 | 0 | 0× | 4 |

| Ziel | Runde 1 | Runde 3 | erreicht |
|---|---:|---:|---|
| Dateien < 10 | 17 | 13 | **nein** |
| Fehlgriffe 0 | 3 | 0 | **ja** |
| grep/find 0 | 1× | 0× | **ja** |
| Ratestellen < 3 | 6 | 4 | **nein** |

**Untergrenze: 12 Dateien.** `docs/INDEX.md` + `docs/NAVIGATION.md` + die zehn Schritte aus
`NAVIGATION.md` §1. Runde 3 lag bei 13 (ein Zusatzgriff: `51-ingress/ingress-access.nix`, das
in der Fallen-Tabelle zitiert wird). Weniger als zehn ginge nur, wenn Dokumentation das Lesen
ersetzt — also mehr Prosa, nicht bessere Navigation.

**Nicht erreicht:** die Ratestellen blieben bei 4. Eine davon ist im Dokument ausdrücklich als
Entscheidung markiert (Hardening-Profil: `hardening-profiles.nix` liefert die Sets, aber keine
Zuordnungsregel). Drei waren Lücken **in** `NAVIGATION.md`, die erst beim Befolgen sichtbar
wurden, und sind inzwischen belegt.

## Was mediNix-core nicht ist

- **Kein Obsidian-Vault.** Markdown-Links statt Wikilinks, Index generator-geprüft statt
  Obsidian-Auflösung. Die Falle ist hier nicht „Link ohne Pfad", sondern „Link auf eine Datei,
  die es nie gab" (so stand es bis 2026-11-13 in `README.md`: `50-core/MANIFEST.md`).
- **Keine Modulseite pro Datei.** 46 Module, **1** Seite (`docs/modules/582-gatus.md`) als
  Musterfall. Weitere entstehen erst, wenn ein Agent an dieser Stelle nachweislich falsch
  abbiegt.
- **Kein RAG, kein Graph-Tool.** Struktur wird **geprüft** (`check_manifest_edge`,
  `check_corridor`, `nix flake check`), nicht abgefragt. Bei 46 Modulen und 74 `.nix`-Dateien
  beantwortet `grep -rl` die Abhängigkeitsfrage in 10 ms.

## Offen (kein Fehler, aber nicht erledigt)

| Punkt | Stand | Was fehlt |
|---|---|---|
| Ziel „< 10 Dateien" | nicht erreicht (13) | Untergrenze ist 12 — das Ziel war zu optimistisch gesetzt, nicht die Struktur zu schlecht |
| Ratestellen „< 3" | 4, davon 1 bewusst | keine Dokumentationslücke mehr offen |
| Runde 3 | Prompt war **nicht** identisch zu Runde 2 | Runde 4 mit demselben Prompt, falls die Zahl belastbar verglichen werden soll |
| `mkManifestEntry` | definiert, exportiert, **nie aufgerufen** | Entscheidung: Module umstellen oder Export entfernen (`todo/tasks.json` T-30-02) |
| Hardening-Profil-Zuordnung | als „nicht ableitbar, Entscheidung" markiert | eine Regel müsste erfunden werden — bewusst nicht getan |

## Wie diese Datei gepflegt wird

Neue Messung = neue Zeile in der Zahlentabelle, mit Datum und **identischem** Prompt.
Neue Lücke = neue Zeile in `docs/NAVIGATION.md`, nicht in dieser Datei.
Diese Datei ändert sich nur, wenn sich die **Struktur** ändert, nicht der Inhalt.
