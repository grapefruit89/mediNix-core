# Gruppe 5 — Tooling & CI

Stand: 2026-11-04 · zusammengeführt aus `ROADMAP.md`, `docs/TODO.md`

> **Was hier steht:** Werkzeuge und Automatisierung. Kein Blocker, aber viel Handarbeit,
> die verschwinden würde. `ROADMAP.md` bleibt Quelle.

| ID | Punkt | Aufwand | Charakter | Belege |
|---|---|---|---|---|
| **R96** | **CI Stufe 0a:** `nixos_idiom_audit.py --p0-only` in `.github/workflows/order-lint.yml` (fail-closed). Läuft lokal schon, fehlt in CI. | MITTEL | CI | `ROADMAP.md:96` · `docs/TODO.md:39` |
| **R76** | **Flake-Lock-Auto-Update:** wöchentlicher Workflow mit `nix flake check`. | MITTEL | CI | `ROADMAP.md:76` · `docs/TODO.md:30` |
| **R93** | **`scripts/systemd-facts.sh`:** host-seitiges JSON-Bundle („was systemd hier kann") aus `systemctl list-units --output=json`, `show -p …`, `systemd-analyze security --json=short`, `busctl introspect … --json=short`; redigiert + token-gekappt; Runbook-Eintrag. Läuft nur auf der Nix-Maschine. | MITTEL | Tooling | `ROADMAP.md:93` · `docs/TODO.md:36` |
| **R98** | **`arr-provision` bündeln:** 8 Einzel-CLIs (`arr-sync-*`) → **ein** `arr-provision <subcommand>` (weniger Entry-Points, ein `--help`). | MITTEL | Tooling | `ROADMAP.md:98` · `docs/TODO.md:41` |
| **R37** | **Generator `medinix-meta.py new-service`** („Ankreuzbogen Schicht 3"): fragt 8 Felder, prüft Paketexistenz live über den NixOS-MCP. | MITTEL | Tooling | `ROADMAP.md:37` · `docs/TODO.md:11` |
| **T12** | **QEMU-Smoke-Test lokal freischalten** (Stufe 3 der Prüf-Leiter). Heute nur in CI. | MITTEL | CI | `docs/TODO.md:13` |
| **R81** | **Deferred-Deletion-Queue:** HDD-freundlich (`hdparm -C`-Check, Force nach `maxAgeDays = 7`). | MITTEL | Feature/Tooling | `ROADMAP.md:81` · `docs/TODO.md:32` |
| **R82** | **Label-basiertes Automounting/MergerFS.** Teilweise vorhanden: `570-storage.nix` kann MergerFS-Pools, das Einhängen macht der Host. | GROSS | Feature | `ROADMAP.md:82` · `docs/TODO.md:33` |

## Empfehlung

**R96 zuerst** — es ist die einzige Zeile in dieser Gruppe, die eine bestehende lokale
Prüfung in CI verankert. Danach R98 und R93 (weniger Handarbeit pro Session).

R82 ist kein Tooling, sondern eine Host-Grenz-Frage — gehört eigentlich zu ADR-0003 §1
(„Publish-Don't-Apply"). Vor dem Bauen klären, wer das Einhängen besitzt.

## Nicht Teil dieser Gruppe

- M4 (591 Options-Pfad) ist ein **Gate**, kein Tooling → Gruppe 1.
- R88 (Branch löschen) braucht einen Push → bewusst nicht aufgenommen.
