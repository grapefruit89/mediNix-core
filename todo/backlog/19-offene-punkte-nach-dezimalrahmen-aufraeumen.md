# Aufgabe 19 — Offene Punkte nach Dezimalrahmen-Aufräumen

Stand: 2026-11-04 (nach `228ba38`)

> Aufgenommen nach Abschluss des Dezimalrahmen-Aufräumens.
> Kein akuter Handlungsbedarf, aber nicht vergessen.
> **Nur ADR-0000 ist fertig** — alles hier ist außerhalb des Rahmens.

---

## Aufgabe 8 (aufgeschoben)

- `agent/skills/` → `skills/` (Wrapper-Ordner auflösen)
- `nix-packaging` archivieren (`docs/audit/2026-11-04/agent-skills-archive/`)
- `cross-platform.md` archivieren
- `medinix-project.md` anlegen (5xx-Rahmen, YAML-Regeln, Validierungs-Gates)
- `skills-lock.json`, `link-skills.sh`, `check_skills.py` anpassen
- `.claude/skills/` retargeten
- **Aufwand:** ~1 h. **Charakter:** echte Strukturarbeit.

## M4 — 591 Options-Pfad-Assertion

- In `59-guardrails/591-cross-domain.nix` eine Assertion ergänzen, die prüft:
  jeder Registry-Dienst mit Port löst auf einen existierenden Options-Pfad auf.
- Negativtest dazu.
- **Aufwand:** ~30 min. **Charakter:** Verteidigung für die Zukunft (wirkt erst,
  wenn jemand einen neuen Dienst ohne Modul anlegt).

## caddyClass vs. accessGroup (echter SSOT-Verstoß)

- `50-core/registry.nix` hat `caddyClass` (`public`/`stream`/`internal`/`idp`/`none`)
- `50-core/service-contract.nix` hat `accessGroup` (dito)
- Beide beschreiben dieselbe Zugriffsklasse, historisch getrennt gewachsen.
- Konsolidieren: entweder `caddyClass` streichen (Registry liest aus Manifest)
  oder `accessGroup` streichen (Manifest liest aus Registry).
- **Aufwand:** ~30 min. **Charakter:** letzter echter SSOT-Verstoß.

## `.agent-state.json` — Grenzfälle

- `blacklist[1].was`, `blacklist[8].topic`, `blacklist[15].was`,
  `blacklist[30].was` — enthalten noch `lib/`-Pfade als Regelbeschreibung
  (nicht Historie).
- 4 Zeilen, Mini-Commit. **Charakter:** Kosmetik.

## §11 ADR-0000 — Duplikat „Protocol over Product"

- Zeile 237 und Zeile 240 in `docs/adr/ADR-0000-dezimalrahmen-verfassung.md`
  sind identisch („Protocol over Product: Der Slot wird anhand der Rolle
  vergeben…"). Eine Zeile streichen.
- **Aufwand:** 1 min. **Charakter:** Kosmetik.

## Optionale Kosmetik (§11 vs TERMINOLOGY, §4/§10)

- §11 Semantic Anchors: 10-Zeilen-Tabelle doppelt zu `docs/TERMINOLOGY.md`.
  Kürzen auf 3 Zeilen + Verweis. **Gate-relevant: nein** (kein Skript zitiert §11).
- §4 UPG und §10 Consequences: beschreiben teils dasselbe.
- **Aufwand:** ~15 min. **Charakter:** Feinschliff. Nur beim nächsten Anfassen
  der ADR mitnehmen.

---

## Status nach Aufgabe 19

| | |
|---|---|
| ADR-0000 | fertig (keine Widersprüche, keine toten Pfade, §12 dokumentiert) |
| ADR-0002 | (c)-Punkt ergänzt (Deklarativ / `mutableUsers`) |
| ADR-0003 | drei Punkte ergänzt (DynamicUser-Richtigstellung, Service-Koexistenz, `mkForce`-Upstream-Ausnahme) |
| ADR-040 | §3-Ausnahme (Vollzugs-Prüfung) dokumentiert |
| Delta-Tabelle | `○` nur noch **M4** (siehe oben) |
| Gate-Status | alle grün |
| Push | keiner |

## Nicht Teil dieser Aufgabe

- Keine Konsolidierung von `caddyClass`/`accessGroup` (eigener Auftrag).
- Keine Kürzung von §11/§4/§10.
- Keine `agent/skills/`-Umsortierung.
