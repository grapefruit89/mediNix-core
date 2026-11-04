# Gruppe 7 — Kosmetik & Reste

Stand: 2026-11-04 · zusammengeführt aus `todo/backlog/19-…`, `todo/backlog/17-…`

> **Was hier steht:** Punkte ohne Verhaltenswirkung. Nur anfassen, wenn die
> betroffene Datei sowieso offen ist.

## Offen (MITTEL)

| ID | Punkt | Aufwand | Charakter | Belege |
|---|---|---|---|---|
| **B-S11K** | **ADR-0000 §11 vs. `docs/TERMINOLOGY.md`.** Die 10-Zeilen-Anker-Tabelle steht doppelt („Eine `num` leitet Port, UID, UPG-GID ab → SSOT" usw.). Kürzen auf 3 Zeilen + Verweis auf `TERMINOLOGY.md`. **Gate-relevant: nein** (kein Skript zitiert §11). | MITTEL | Kosmetik | `todo/backlog/19-…` |
| **B-S410** | **ADR-0000 §4 (UPG) und §10 (Consequences) beschreiben teils dasselbe.** Erst lesen, dann entscheiden — deshalb nicht als Klein-Punkt geführt. | MITTEL | Kosmetik | `todo/backlog/19-…` |

## Bereits erledigt — nur die Quelle aufräumen

| ID | Punkt | Warum erledigt |
|---|---|---|
| **T10** | „Voll-Stack-Check erweitern um pocket-id, cloudflare-ddns, **avahi**, recyclarr, smartd" | `grep -rn avahi` → **0 Treffer**. avahi wurde durch Blocky ersetzt (ADR-515). Die übrigen fünf stehen längst in `stackConfig` (`flake.nix:231-261`). Der Punkt ist **veraltet** und müsste aus `ROADMAP.md` entfernt werden — nicht aus `docs/TODO.md` (generiert). |
| **R92** | „Plan (Momentaufnahme): `PLAN-offene-punkte.md`" | Durch diese Konsolidierung ersetzt (2026-11-04). |
| **B-MF** | 2 verbleibende `mkForce` (512 `UMask`, 515 `DynamicUser`) | Upstream-Konflikte, in `todo/backlog/17-…` dokumentiert und in ADR-0003 §2 als Ausnahme verankert. **Kein Fix geplant.** Der 512-Punkt braucht einen Start-Test auf einem laufenden Host, keinen Commit. |

## In dieser Session erledigt (Phase 3)

- `.agent-state.json`: 4 `lib/`-Referenzen in aktiven Regeln (`blacklist[1|8|15|30]`)
- ADR-0000 §11: doppelte „Protocol over Product"-Zeile entfernt
- `nixos-llm-first-workflow/SKILL.md:183`: stale `mediahost@192.168.0.10`-Anleitung
