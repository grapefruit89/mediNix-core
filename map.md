# mediNix-core — map.md (Navigation)

> Verhalten/Invarianten: `AGENTS.md`.
> Diese Datei beantwortet nur **wo liegt was** und **welche Datei zuerst**.
> Budget: ≤ 100 Zeilen / ≤ 700 Wörter / ≤ 5.500 Bytes (`scripts/check_ai_cockpit.py`).

## 1. O(1)-Einstieg (4 Schritte, keine Suche)

1. `.agent-state.json` — Korridor: `locked_invariants`, `dead_ends_and_failures`,
   `recent_refactorings`, `corridor` (Whitelist/Blacklist).
2. `todo/tasks.json` — einzige Handquelle offener Arbeit (`status`, `priority`, `wave`, `source.ref`).
   Sichten `docs/TODO.md`/`docs/PLAN.md` sind generiert.
3. `docs/adr/llm-index.json` — aktive ADRs, `start_here`, Namensregeln;
   Verfassung: `docs/adr/ADR-0000-dezimalrahmen-verfassung.md`.
4. `scripts/verify.sh` — lokale Leiter; ausführen mit `bash scripts/verify.sh`.

## 2. Dekaden-Inventar (Dezimalrahmen, ADR-0000)

| Ordner / Datei | Rolle | Kerninhalt |
|---|---|---|
| `50-core/` | Foundation | `501-decimal-engine.nix`+`derive.nix` (UID/GID/StateDirectory), `service-factory.nix`, `service-contract.nix`, `hardening-profiles.nix`, `registry.nix` (SSoT), `BANNED_TECHNOLOGIES.md` |
| `51-ingress/` | Access | 511 Caddy · 512 Pocket-ID · 513 DDNS/Speedport · 514 ACME · 515 Blocky · 516 CrowdSec · 517 OAuth2-Proxy · 518 Landingpage · 519 Guardrails |
| `52-security/` | Security | 520 Baseline/nftables · 521 sealed Credentials · 525 WireGuard · 526 VPN-Killswitch |
| `53-acquisition/` | Ingestion | 532 Sonarr · 533 Radarr · 534 Readarr · 535 Lidarr · 536 Prowlarr · 537 Recyclarr · 538 Provisioning |
| `54-processing/` | Processing | 541 SABnzbd · 543 Mover |
| `55-playback/` | Core UI | 551 Jellyfin · 552 Audiobookshelf · 553 Navidrome (funktionaler Kern) |
| `56-exposition/` | Exposition | 561 Seerr |
| `57-maintenance/` | Maintenance | 570 Storage/SetGID · 571 SQLite-WAL · 576 Backup · 577 Drift · 578 Orphan-Cleanup · 579 Backup-SSH |
| `58-observability/` | Observability | 581 ntfy · 582 Gatus · 583 Runtime-Guard · 584 Boot-Watchdog · 585 Exporter · 586 VPN-Selftest · 587 Disk-Health · 588 Update-Notifier |
| `59-guardrails/` | Guardrails | 591 Cross-Domain-Assertions |
| `scripts/` | Werkzeuge | `verify.sh` (Leiter) · `check_*.py` (Gates) · `gen_*.py`/`medinix-meta.py` (Generatoren) · `nixmeta_check.py` · `link-skills.sh` |
| `docs/adr/` | Entscheidungen | `ADR-0000` (Verfassung) · `ADR-00-nixmeta-v3` (Header) · Manifest `ADR-0003` · Index `llm-index.json` |
| `docs/` | Wissensbasis | `NAVIGATION.md`, `RUNBOOK.md`, `CONVENTIONS.md`, `TERMINOLOGY.md`, `NIXOS-ANCHORS.md`, `modules/<id>-<dienst>.md`, `AUDIT-LEDGER.md` |
| `todo/` | Arbeit | `tasks.json` (Handquelle) · `docs/TODO.md` + `docs/PLAN.md` (generiert) · Altstände in `docs/audit/` |
| `flake.nix` | Outputs | Modul-/Paket-Exports + Checks (Port-Riegel, Negativtests, Unit-/VM-Skripte) |

## 3. Task-to-File-Matrix (Task → Datei zuerst)

| Aufgabe | Zuerst lesen | Dann / Aktion |
|---|---|---|
| Neuen Dienst aufnehmen | `docs/NAVIGATION.md` → `docs/modules/_TEMPLATE.md` | `50-core/registry.nix`, `50-core/service-factory.nix` |
| UID/Port/GID ableiten | `50-core/501-decimal-engine.nix`, `50-core/derive.nix` | `docs/adr/ADR-0000-…md` (UPG) |
| Hardening ändern | `50-core/hardening-profiles.nix` | `docs/adr/ADR-5050-…md`, `systemd-analyze security` |
| Ingress/Route/SSO | `51-ingress/511-caddy.nix` bzw. `517-oauth2-proxy.nix` | `docs/ingress-security-matrix.md`, 519-Guardrails |
| Firewall/Secrets | `52-security/520-core-security.nix`, `521-creds.nix` | `docs/adr/ADR-521-secret-management.md` |
| *arr-Stack | `53-acquisition/532-…538-*.nix` | `50-core/arr-settings.nix`, `arr-key-sync.nix` |
| Download/Mover | `54-processing/541-sabnzbd.nix`, `543-mover.nix` | `docs/adr/ADR-543-cold-archive-tiering.md` |
| Playback (Kern) | `55-playback/551-553-*.nix` | `docs/modules/`-Seite des Dienstes |
| Medien-Anfragen | `56-exposition/561-seerr.nix` | `docs/adr/ADR-561-seerr.md` |
| Backup/Restore | `57-maintenance/576-backup.nix` | `docs/adr/ADR-576-backup.md`, `579-backup-ssh.nix` |
| Monitoring/Health | `58-observability/582-gatus.nix` | `581-ntfy.nix`, `583-runtime-guard.nix` |
| Domain-übergreifend prüfen | `59-guardrails/591-cross-domain.nix` | `docs/adr/ADR-0003-architektur-manifest.md` |
| Offene Arbeit / Befund | `todo/tasks.json` | `gen_todo.py`, `gen_plan.py`, `check_tasks.py` |
| Architektur-Entscheidung | `docs/adr/llm-index.json` | passende `ADR-*.md`, `check_adrs.py` |
| Konvention / Begriff | `docs/CONVENTIONS.md`, `docs/TERMINOLOGY.md` | `docs/NIXOS-ANCHORS.md`, `docs/anchors/` |
| Betrieb / Triage | `docs/RUNBOOK.md` | `docs/AGENT-READINESS.md` |
| Verifikation / CI | `scripts/verify.sh` | `flake.nix` (Checks), `.github/workflows/` |
| Neue `.nix`-Datei | `docs/adr/ADR-00-nixmeta-v3-header.md` | Header + `scripts/nixmeta_check.py` |

## 4. Gates & Budgets

- Verifikation: `bash scripts/verify.sh` (19 Prüfungen, mit Builds); `--fast` ist **nicht** commit-fähig.
- Generierte Sichten: `docs/TODO.md`, `docs/PLAN.md`, `docs/INDEX.md`, `*/AGENTS.md` — nie von Hand editieren.
- Cockpit-Budget: `AGENTS.md` ≤ 70 Z. / ≤ 500 W. / ≤ 4000 B., `map.md` ≤ 100 Z. / ≤ 700 W. / ≤ 5500 B. (`scripts/check_ai_cockpit.py`).
- Verbindlich: reine lokale Entwicklung, Dezimalrahmen/UPG, systemd-first, Zero Docker, fail-closed.
