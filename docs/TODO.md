# TODO — mediNix-core

> **Generiert** aus Korridor + Roadmap + Ledger am 2026-10-16.
> Nicht von Hand pflegen — Inhalte gehören in die Quellen:
> `.agent-state.json` (Entscheidungen), `ROADMAP.md` (Planung), `docs/AUDIT-LEDGER.md` (Befunde).
> Neu erzeugen: `python3 scripts/gen_todo.py` · Prüfen: `python3 scripts/gen_todo.py --check`.

## 1. Offene Entscheidungen (Korridor)

- [ ] Root-Dateien nach docs/CONVENTIONS.md konsolidieren (ADMIN-HANDOFF.md, AGENTS.md, CLAUDE.md, opencode.json, ROADMAP.md, UPSTREAM-SOURCES.md)?
- [ ] Voll-Stack-Check erweitern um pocket-id, cloudflare-ddns, feishin, avahi, recyclarr, smartd?
- [ ] Ankreuzbogen Schicht 3 (Generator medinix-meta.py new-service) bauen?
- [ ] Stufe 3 (QEMU-Smoke-Test) lokal freischalten?
- [ ] 515 mDNS-Refresh umbauen? (.path-Trigger ist bereits systemd-nativ; Umbau = lateral)

## 2. Roadmap — offene Punkte

_Abschnitte: Backlog · Blacklist-Regeln im Korridor: 41_

- [ ] Backlog: Optional Schicht 3: Generator `medinix-meta.py new-service` (fragt 8 Felder, prüft Paketexistenz live über den NixOS-MCP).
- [ ] Backlog: **P0 — L-048: Band-Pruefung vs. engine-abgeleitete Konten (Blocker fuer `mediNix-negative-ankreuzbogen`):** `59-guardrails/591-cross-domain.nix` -> `frameNames` erkennt nur `lib/registry.nix` + `medinix.factoryUnits`. Die Engine leitet Konten aber aus `medinix.manifest` ab -> synthetische Testdienste (`probe`, uid 5590) gelten als "Fremd-Konto im Frameband". Entweder Band-Pruefung liest die Konten-Quelle (nicht die Ableitung, ADR-040) oder der Test erzwingt den Toplevel nicht mehr.
- [ ] Backlog: **P0 (offen, produktiv) — L-047:** `users.mutableUsers = mkDefault false` (Engine, `e803ba8`) braucht eine **echte** Credential-Quelle fuer root oder einen wheel-User (Heute: nur `testHostAccess`-Stub in Praefkonfigurationen). Sonst ist jedes Host-Build von der nixpkgs-Assertion blockiert.
- [ ] Backlog: **T3 — Exporter-Identitaet zentral ableiten (L-046, P1):** `585` gibt kuenftig KEINE `users.*` zurueck (Fixpunkt-Kreuz), sondern nur die ABSICHT. 5 Stellen:
- [ ] Backlog: **Identitaeten einmal ableiten (ADR-040, Endform):** Exportarr-/Fabrik-Konten heute in `58-observability/585-exporters.nix` (liest `manifest`, schreibt `users.users`+`factoryUnits`) in die Engine verlagern (`lib/derive.nix` + Manifest-Absicht) — dann baut `585` nur noch `systemd.services` und alle Kanten sind gerichtet.
- [ ] Backlog: **NIXMETA-Header vollständig nachziehen:** der Check ist eine *Ratsche* — offen bleiben `folder` (42/67), `status` (43/67), `complexity` (32/67) und `links.adr` (17/67). Dabei die **zwei Dialekte** zusammenführen (`sprite:` + flaches `adr:` in 55/56-playback vs. `links.adr`). Braucht Urteilsvermögen je Modul (complexity 1–5, primärer ADR) — deshalb bewusst nicht automatisiert
- [ ] Backlog: **Datei-basierte Ports härter prüfen:** für jellyfin den gerenderten XML-Inhalt greppen (heute nur Seed-Platzhalter + Substitution im Quelltext)
- [ ] Backlog: `lib/gpu.nix` (Vendor-Abstraktion intel/amd/nvidia), `lib/network-cidrs.nix`, `rebuild-guard.nix`. Quellen: UPGRADE-MATRIX A6/A7/A8.
- [ ] Backlog: `vpn-killswitch-test.sh` (echter Egress-Leak-Test), `on-demand-http.nix` (Socket-Activation für Lidarr/Readarr). Quellen: E5/D8.
- [ ] Backlog: Pocket-ID Auto-Enrollment Helper; Multi-User/RBAC über versiegelte Credentials.
- [ ] Backlog: Prometheus Node-Exporter + Caddy-Metrics **und ein Scraper** (B6): `532–536` setzen `metrics.type = "exportarr"`, `585` erzeugt die Exporter, aber es fehlt der **Konsument** (Prometheus / VictoriaMetrics / vmagent). Bis dahin entweder Store ergänzen oder Exporter abschalten (YAGNI). (Teilweise vorhanden: `585-exporters`, `582-gatus`.)
- [ ] Backlog: Flake-Lock-Auto-Update (wöchentlicher Workflow mit `nix flake check`).
- [ ] Backlog: Vector + Loki + Grafana: Journal + Caddy-JSON-Logs, 7 Tage Retention, Storage auf Tier B, Grafana hinter Caddy am Unix-Socket.
- [ ] Backlog: HDD-freundliche Deferred-Deletion-Queue (`hdparm -C`-Check, Force nach `maxAgeDays = 7`).
- [ ] Backlog: Label-basiertes Automounting/MergerFS (teilweise: `570-storage.nix` kann MergerFS-Pools, das Einhängen macht der Host).
- [ ] Backlog: `git branch -d refactor/decades-conformance` lokal und remote — ist in `audit-2026-10-15` gemergt.
- [ ] Backlog: **Plan (Momentaufnahme):** `docs/audit/2026-10-16/PLAN-offene-punkte.md` — ausgearbeiteter **Stand/Lücke/Ziel** je offenem Punkt (F/A/C/B/H/I/G/N + D-06). Quellen bleiben: `ROADMAP.md` + `.agent-state.json` → `docs/TODO.md`.
- [ ] Backlog: **`scripts/systemd-facts.sh`** (F): host-seitiges JSON-Bundle („was systemd hier kann") aus `systemctl list-units --output=json`, `list-unit-files --output=json`, `show -p …`, `systemd-analyze security --json=short`, `busctl introspect … --json=short`; **redigiert + Token-gekappt**; Runbook-Eintrag. (Läuft nur auf der Nix-Maschine.)
- [ ] Backlog: **`docs/AUDIT-NIXOS-IDIOMS.md`** (A): Methodik (drei Schichten, „**Signal ≠ Fund**"), Signal-Tabelle P0/P1/P2, datierter Lauf von `scripts/nixos_idiom_audit.py`, plus der **harte Beweis** = Schicht 3 (`nix flake check` **ohne** `--impure`, host/CI).
- [ ] Backlog: **CONVENTIONS §Audit** (C): drei Schichten + Prüf-Leiter **Stufe 0a** (`nixos_idiom_audit.py --p0-only`) und **Stufe 1a** (`nix flake check` ohne `--impure`); Korridor-Blacklist `AB-0xx` für die harten Reflexe (`--impure` im Code, `nix-env -i`/`nix-channel`, Schreibzugriff `/nix/store/`, `/usr/`-Pfade).
- [ ] Backlog: **CI Stufe 0a** (B): `nixos_idiom_audit.py --p0-only` in `.github/workflows/order-lint.yml` (fail-closed).
- [ ] Backlog: **`docs/HOST-INTERFACE.md`** (H): **eine** Seite „Host-Schnittstelle" — `medinix.host.*`, `hostIntegration.*` (`managed|external|off`), `secrets.*`, `recommended.*`, `storage.*` — plus „was gehört **nicht** in den Flake".
- [ ] Backlog: **arr-provision bündeln** (I): 8 Einzel-CLIs (`arr-sync-*`) → **ein** `arr-provision <subcommand>` (weniger Entry-Points, ein `--help`).
- [ ] Backlog: **`medinix gather <symptom>`** (G): die 7 geordneten Abschnitte (WAS · WER · IST · LOGS · PFADE · DIFF · FIX) aus Registry + systemd, redigiert + Token-gekappt.
- [ ] Backlog: **Doc-Nit** (N): `docs/agents/07-patterns-misc/nixos-llm-first-workflow/SKILL.md:183` ist stale (`nix-env -iA nixpkgs.nixos-mcp` auf `mediahost@192.168.0.10`) → auf den lokalen `nixos`-MCP umstellen.

## 3. Ledger — Befunde ohne Abschluss

- [ ] L-012 (BUG) `shellcheck` **SC2164** (`cd docs` ohne Guard im `buildPhase`) — Status: \
- [ ] L-015 (OPT) unvollständiges Frontmatter: `complexity:` fehlt bei **17**, `status:` bei **6** (`551–554`,`561`,`574`) → Index zeigt `unknown`/`-/5` — Status: OPEN
- [ ] L-018 (OPT) fehlender Single-Entry (`medinixLib`; Meisterstück nutzt `inherit (medinixLib) …`) — Status: OPEN
- [ ] L-045 (ARCH) **Uebernahme + Review:** kein Verlust (822a0d2 ist Vorfahr), aber der Branch ist **eval-rot**: `nix flake check` = 13/50, CI `Flake Check` = failure ( — Status: OPEN
- [ ] L-046 (BUG) **infinite recursion** (13 sichtbare Checks, seit `d6da997`), Ursache commit-genau per `git bisect run`: `2254f8c` "Exporters mit eigenem UPG-Account" — Status: IN PROGRESS
- [ ] L-048 (BUG) **1 Check rot**: `mediNix-negative-ankreuzbogen` faellt, weil `evaluates { ui.group = "Observability"; }` den Toplevel der Probe-Config evaluiert und  — Status: OPEN

## 4. Pflicht bei jeder Änderung

- [ ] Diff vorlegen, Go abwarten (AGENTS.md).
- [ ] Volle Prüf-Leiter: nixfmt-Sweep, 5 Checks **bauen**, `nix flake check`, docs-Paket.
- [ ] Erst lokal messen, dann **ein** Push (Korridor-Regel).
