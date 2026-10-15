# TODO — mediNix-core

> **Generiert** aus Korridor + Roadmap + Ledger am 2026-10-15.
> Nicht von Hand pflegen — Inhalte gehören in die Quellen:
> `.agent-state.json` (Entscheidungen), `ROADMAP.md` (Planung), `docs/AUDIT-LEDGER.md` (Befunde).
> Neu erzeugen: `python3 scripts/gen_todo.py` · Prüfen: `python3 scripts/gen_todo.py --check`.

## 1. Offene Entscheidungen (Korridor)

- [ ] Root-Dateien nach docs/CONVENTIONS.md konsolidieren (ADMIN-HANDOFF.md, AGENTS.md, CLAUDE.md, opencode.json, ROADMAP.md, UPSTREAM-SOURCES.md)?
- [ ] Voll-Stack-Check erweitern um pocket-id, cloudflare-ddns, feishin, avahi, recyclarr, smartd?
- [ ] Ankreuzbogen Schicht 3 (Generator medinix-meta.py new-service) bauen?
- [ ] Stufe 3 (QEMU-Smoke-Test) lokal freischalten?

## 2. Roadmap — offene Punkte

_Abschnitte: Backlog · Blacklist-Regeln im Korridor: 31_

- [ ] Backlog: Optional Schicht 3: Generator `medinix-meta.py new-service` (fragt 8 Felder, prüft Paketexistenz live über den NixOS-MCP).
- [ ] Backlog: **NIXMETA-Header vollständig nachziehen:** der Check ist eine *Ratsche* — offen bleiben `folder` (42/67), `status` (43/67), `complexity` (32/67) und `links.adr` (17/67). Dabei die **zwei Dialekte** zusammenführen (`sprite:` + flaches `adr:` in 55/56-playback vs. `links.adr`). Braucht Urteilsvermögen je Modul (complexity 1–5, primärer ADR) — deshalb bewusst nicht automatisiert
- [ ] Backlog: **Datei-basierte Ports härter prüfen:** für jellyfin den gerenderten XML-Inhalt greppen (heute nur Seed-Platzhalter + Substitution im Quelltext)
- [ ] Backlog: 516 CrowdSec Bouncer (ersetzt die Fail2ban-Übergangslösung auf Caddy-Logs). Der `lib.fakeHash` in 511 ist bereits entfernt; das Modul fehlt.
- [ ] Backlog: `lib/gpu.nix` (Vendor-Abstraktion intel/amd/nvidia), `lib/network-cidrs.nix`, `rebuild-guard.nix`. Quellen: UPGRADE-MATRIX A6/A7/A8.
- [ ] Backlog: `vpn-killswitch-test.sh` (echter Egress-Leak-Test), `on-demand-http.nix` (Socket-Activation für Lidarr/Readarr). Quellen: E5/D8.
- [ ] Backlog: Pocket-ID Auto-Enrollment Helper; Multi-User/RBAC über versiegelte Credentials.
- [ ] Backlog: Prometheus Node-Exporter + Caddy-Metrics (teilweise vorhanden: 585-exporters, 582-gatus).
- [ ] Backlog: Flake-Lock-Auto-Update (wöchentlicher Workflow mit `nix flake check`).
- [ ] Backlog: Vector + Loki + Grafana: Journal + Caddy-JSON-Logs, 7 Tage Retention, Storage auf Tier B, Grafana hinter Caddy am Unix-Socket.
- [ ] Backlog: HDD-freundliche Deferred-Deletion-Queue (`hdparm -C`-Check, Force nach `maxAgeDays = 7`).
- [ ] Backlog: Label-basiertes Automounting/MergerFS (teilweise: `570-storage.nix` kann MergerFS-Pools, das Einhängen macht der Host).
- [ ] Backlog: `git branch -d refactor/decades-conformance` lokal und remote — ist in `audit-2026-10-15` gemergt.

## 3. Ledger — Befunde ohne Abschluss

- [ ] L-012 (BUG) `shellcheck` **SC2164** (`cd docs` ohne Guard im `buildPhase`) — Status: \
- [ ] L-015 (OPT) unvollständiges Frontmatter: `complexity:` fehlt bei **17**, `status:` bei **6** (`551–554`,`561`,`574`) → Index zeigt `unknown`/`-/5` — Status: OPEN
- [ ] L-018 (OPT) fehlender Single-Entry (`medinixLib`; Meisterstück nutzt `inherit (medinixLib) …`) — Status: OPEN

## 4. Pflicht bei jeder Änderung

- [ ] Diff vorlegen, Go abwarten (AGENTS.md).
- [ ] Volle Prüf-Leiter: nixfmt-Sweep, 5 Checks **bauen**, `nix flake check`, docs-Paket.
- [ ] Erst lokal messen, dann **ein** Push (Korridor-Regel).
