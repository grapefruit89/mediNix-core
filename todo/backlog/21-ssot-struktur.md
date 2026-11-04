# Gruppe 2 — SSOT & Struktur

Stand: 2026-11-04 · zusammengeführt aus `ROADMAP.md`, `todo/backlog/08-…`, `todo/backlog/19-…`, `docs/AUDIT-LEDGER.md`

> **Was hier steht:** Die echten Struktur-Punkte am Rahmen. Alles andere ist Feature
> oder Doku. `ROADMAP.md` bleibt Quelle — die Zeilenverweise gelten dort.

| ID | Punkt | Aufwand | Charakter | Belege |
|---|---|---|---|---|
| **B-CA** | **`caddyClass` vs. `accessGroup` — letzter echter SSOT-Verstoß.** `50-core/registry.nix` hat `caddyClass` (`public`/`stream`/`internal`/`idp`/`none`), `50-core/service-contract.nix` hat `accessGroup` mit denselben Werten. Beide beschreiben dieselbe Zugriffsklasse, historisch getrennt gewachsen. Konsolidieren: entweder `caddyClass` streichen (Registry liest aus Manifest) oder `accessGroup` streichen (Manifest liest aus Registry). | MITTEL (~30 min) | **Struktur / SSOT** | `todo/backlog/19-…` |
| **B8** | **Aufgabe 8: `agent/skills/` → `skills/`.** Wrapper-Ordner auflösen (`agent/` hat nur ein Kind). Dazu: `nix-packaging` archivieren (600+ Zeilen Package-Bau, für ein NixOS-Modul-Repo irrelevant), `cross-platform.md` archivieren, **`medinix-project.md` anlegen** (5xx-Regeln, YAML-Header, Validierungs-Gates — die Lücke, die der Agent heute raten muss), `skills-lock.json`/`link-skills.sh`/`check_skills.py` anpassen, `.claude/skills/` retargeten. | GROSS (~1 h) | **Struktur** | `todo/backlog/08-…` |
| **R55** | **Identitäten einmal ableiten (ADR-040 Endform).** Exportarr-/Fabrik-Konten heute in `58-observability/585-exporters.nix` (liest `manifest`, schreibt `users.users`+`factoryUnits`) in die Engine verlagern (`50-core/derive.nix` + Manifest-Absicht) — dann baut `585` nur noch `systemd.services` und alle Kanten sind gerichtet. | GROSS | Struktur | `ROADMAP.md:55` · `docs/TODO.md:23` · ADR-040 Konsequenzen |
| **L18** | **Single-Entry `medinixLib` fehlt.** Heute `inherit (medinixLib) …` im Meisterstück, aber kein zentraler Export. | MITTEL | Struktur | `docs/AUDIT-LEDGER.md:28` · `docs/TODO.md:50` |
| **R56** | **NIXMETA-Header vollständig nachziehen.** Die Ratsche ist bewusst schrumpfend: offen `folder` (42/67), `status` (43/67), `complexity` (32/67), `links.adr` (17/67). Dazu die **zwei Dialekte** zusammenführen (`sprite:` + flaches `adr:` in 55/56-playback vs. `links.adr`). Braucht Urteilsvermögen je Modul — deshalb **nicht** automatisiert. | GROSS | Struktur | `ROADMAP.md:56` · `docs/TODO.md:24` |
| **T9** | **Root-Dateien nach `docs/CONVENTIONS.md` konsolidieren** (`ADMIN-HANDOFF.md`, `AGENTS.md`, `CLAUDE.md`, `opencode.json`, `ROADMAP.md`, `UPSTREAM-SOURCES.md`). | MITTEL | Struktur | `docs/TODO.md:10` |
| **T14** | **515 mDNS-Refresh umbauen.** ⚠️ Der Punkt sagt selbst: `.path`-Trigger ist bereits systemd-nativ, „Umbau = lateral". **Kein Nutzen erkennbar — Kandidat zum Verwerfen.** | MITTEL | Struktur (fraglich) | `docs/TODO.md:14` |

## Reihenfolge

1. **B-CA** — kleinster echter SSOT-Verstoß, zwei Felder eine Bedeutung.
2. **B8** — größter Nutzen (der Agent muss die Projektregeln nicht mehr raten), aber meiste Pfadbewegung.
3. R55, L18, R56 — brauchen Urteilsvermögen, keine Mechanik.

## Nicht Teil dieser Gruppe

- Header-Ratsche `complexity` je Modul → in R56 enthalten.
- `agent/skills/`-Archivierung → in B8 enthalten.
