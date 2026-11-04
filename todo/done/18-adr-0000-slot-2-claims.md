# Aufgabe 18 — ADR-0000 §2: Foundation-Slot-Claims

> [!CAUTION]
> **STATUS: ERLEDIGT** — §2 beschreibt `_0` jetzt als Rolle, nicht als Ordner-Liste
> (Commit siehe `git log -- docs/adr/ADR-0000-dezimalrahmen-verfassung.md`).

---

## Problem

§2 der Verfassung behauptete, `_0` **enthalte** diese Dateien:

```
| _0 | Foundation | What do we work with? |
  `CLAUDE.md`, options `default.nix`, `50-core/501-decimal-engine.nix`,
  `registry` — strictly structure & engine, NEVER daemons |
```

Das ist semantischer Drift, kein Tippfehler:

1. **`CLAUDE.md` liegt in der Repo-Wurzel**, nicht in `50-core/`. Ebenso `default.nix`.
   ADR-0000 §14 klassifiziert beide als **Root-Config** (`kind: root-config`) — eine
   eigene Kategorie, nicht Teil von `_0`.
2. **`_0` ist eine Rolle, kein Ordner.** Die Sektion beschreibt Slots (Rollen) über
   allen Projekten; eine Ordner-Liste macht daraus eine Verzeichnis-Beschreibung und
   widerspricht §1 („the module layout remains strictly flat and two-tiered").
3. **`registry`** ist kein Dateiname. Gemeint ist `50-core/registry.nix`.

## Beleg (Messung, nicht Vermutung)

```
$ grep -n "^folder:" default.nix
folder: "."

$ ls 50-core/registry.nix 50-core/501-decimal-engine.nix
50-core/501-decimal-engine.nix  50-core/registry.nix

$ ls CLAUDE.md default.nix
CLAUDE.md  default.nix          # Repo-Wurzel
```

## Auflösung

§2 nennt jetzt die Rolle und die tatsächlichen Codedateien; Root-Doku wird explizit als
**Root-Config (§14)** abgegrenzt. Zusätzlich steht im Vorspann von §2 der Satz, der die
Verwechslung dauerhaft verhindert:

> Die Slots sind **Rollen**, keine Ordner — welche Datei welche Rolle trägt, regelt §14
> (Datei-Klassifikation).

## Nicht Teil dieser Aufgabe

- Keine Änderung an §14 (die Kategorien sind korrekt; §2 hat falsch zitiert).
- Keine Umnummerierung der Sektionen.
- Die fehlende §12 (Nummernfolge springt 11 → 13) bleibt offen — eigener Befund.

## Herkunft

Gefunden am 2026-11-04 im Claude-Review (F3), bestätigt beim Vollzug von §14.
