# TODO — mediNix-core

> **Generiert** aus tasks.json + Korridor + Ledger am 2026-11-07.
> Nicht von Hand pflegen — Inhalte gehören in die Quellen:
> `todo/tasks.json` (offene Arbeit, validiert durch `scripts/check_tasks.py`),
> `.agent-state.json` (Entscheidungen), `docs/AUDIT-LEDGER.md` (Befunde).
> Neu erzeugen: `python3 scripts/gen_todo.py` · Prüfen: `python3 scripts/gen_todo.py --check`.

## 1. Offene Arbeit — `todo/tasks.json` (61)

_Eine Quelle. Validierung: `python3 scripts/check_tasks.py` · Blacklist-Regeln im Korridor: 53_

### hoch (10)

- [ ] `R24` FIDO2 / Passkey-only Authentifizierung
- [ ] `R47` L-047: echte Credential-Quelle für root/wheel. `users.mutableUsers = lib.mkDefault false` braucht einen realen…
- [ ] `R55` Identitäten einmal ableiten (ADR-040 Endform)
- [ ] `R56` NIXMETA-Header vollständig nachziehen
- [ ] `R74` Pocket-ID Auto-Enrollment + Multi-User/RBAC über versiegelte Credentials
- [ ] `R80` Vector + Loki + Grafana
- [ ] `R82` Label-basiertes Automounting/MergerFS
- [ ] `T-28-11` Roh-Chat-/Audit-Exporte mit Infra-Metadaten aus Git entfernen: todo/done/2026-10-25_*/input/chat.json, todo/do…
- [ ] `T-28-13` Guard scripts/check_infra_leaks.py: verbietet echte WAN-Domain, LAN-Subnetze (RFC 1918) und oeffentliche IPv4…
- [ ] `T-29-02` Arr-API-Keys kommen nicht an: SONARR_API_KEY_FILE ist Docker-Konvention, die das Binary ignoriert

### mittel (45)

- [ ] `B-CA` `caddyClass` vs. `accessGroup`
- [ ] `B-M4` 591 Options-Pfad-Assertion
- [ ] `B-S11K` ADR-0000 §11 vs. `docs/TERMINOLOGY.md`
- [ ] `B-S410` ADR-0000 §4 (UPG) und §10 (Consequences) beschreiben teils dasselbe
- [ ] `L15` `complexity:` fehlt bei 15 von 44 Modulen → Index zeigt `-/5`
- [ ] `L18` Single-Entry `medinixLib` fehlt
- [ ] `N-25-01` Dokumentationstrias in ADR-0000 oder docs/ verankern
- [ ] `N-27-01` nftables GeoIP-Sets evaluieren
- [ ] `N-29-06` Q-29-04 entscheiden und danach die vier Merge-Paare abarbeiten: medinix-nix-idioms+nixos-idiom-audit, nixos-fl…
- [ ] `Q-15-01` Welche konkreten Prüfkriterien umfassen die restlichen der 44 Nixmap-Auditregeln im vollständigen Regelsatz?
- [ ] `Q-28-02` Das nie gebaute Modul (geplant als lib/wan-ip-provider.nix, heute 50-core/) deklariert { lib, pkgs ? null }, n…
- [ ] `Q-28-03` Ist die nftables-Regel 'tcp dport 80 meter flood-http { ip saddr limit rate over 25/minute burst 50 packets }…
- [ ] `Q-28-04` 515-blocky.nix setzt customDNS.mapping fuer 'lan' und '<domain>' auf 127.0.0.1
- [ ] `Q-28-05` Korridor AB-036 ('Ausgemustertes archivieren statt loeschen') vs. geloeschte docs/archive/ARCHIVE-ADR-554-feis…
- [ ] `Q-28-07` check_adrs listet 8 Legacy-Slug-IDs (ADR-571-sqlite-wal, ADR-576-backup-classification, ...) statt numerischer…
- [ ] `Q-28-08` 19 committete Dateien (Roh-Chat-Exporte in todo/done/, Destillate in todo/*.json) enthalten Infra-Metadaten (e…
- [ ] `Q-29-04` scripts/skills-exclude.txt fuehrt seit Wochen vier Merge-Kandidaten als Kommentar: medinix-nix-idioms (doppelt…
- [ ] `Q-29-05` Soll ein Front-Matter-Feld 'scope: medinix|generic' eingefuehrt werden (31 SKILL.md-Dateien + eine Regel in sc…
- [ ] `Q-29-06` Die 9 in scripts/skills-exclude.txt ausgeschlossenen Skills (kanban-orchestrator, kanban-worker, hermes-sessio…
- [ ] `Q-29-07` Zwei Kategorien ohne Skill: /home/moritz/repos/mediNix-core/docs/agents/08-mcp-second-brain (nur CONCEPT.md) u…
- [ ] `Q-29-08` ADR-0000 §11 und /home/moritz/repos/mediNix-core/docs/TERMINOLOGY.md beschreiben beide Semantic Anchors
- [ ] `R100` Doc-Nit (N): `docs/agents/07-patterns-misc/nixos-llm-first-workflow/SKILL.md:183` ist stale (`nix-env -iA nixp…
- [ ] `R161` ADR-Verweis-Rest (Kette Code → ADR). 7 Allowlist-Einträge in `scripts/adr-refs-allowlist.txt` abarbeiten
- [ ] `R163` Skill-Trigger nachschärfen. 18 von 30 Projekt-Skills haben eine `description` unter 80 Zeichen
- [ ] `R37` Generator `medinix-meta.py new-service` („Ankreuzbogen Schicht 3"): fragt 8 Felder, prüft Paketexistenz live ü…
- [ ] `R66` Datei-basierte Ports härter prüfen
- [ ] `R72` `50-core/gpu.nix` (Vendor-Abstraktion intel/amd/nvidia), `50-core/network-cidrs.nix`, `rebuild-guard.nix`
- [ ] `R73` `vpn-killswitch-test.sh`
- [ ] `R75` Prometheus-Scraper fehlt
- [ ] `R76` Flake-Lock-Auto-Update: wöchentlicher Workflow mit `nix flake check`
- [ ] `R81` Deferred-Deletion-Queue:
- [ ] `R88` `git branch -d refactor/decades-conformance` lokal und remote
- [ ] `R93` `scripts/systemd-facts.sh`: host-seitiges JSON-Bundle („was systemd hier kann") aus `systemctl list-units --ou…
- [ ] `R94` `docs/AUDIT-NIXOS-IDIOMS.md`:
- [ ] `R95` CONVENTIONS §Audit: drei Schichten + Prüf-Leiter Stufe 0a (`idiom_audit --p0-only`) und Stufe 1a (`nix flake c…
- [ ] `R96` CI Stufe 0a: `nixos_idiom_audit.py --p0-only` in `.github/workflows/order-lint.yml` (fail-closed)
- [ ] `R97` `docs/HOST-INTERFACE.md`: eine Seite „Host-Schnittstelle"
- [ ] `R98` `arr-provision` bündeln: 8 Einzel-CLIs (`arr-sync-*`) → ein `arr-provision <subcommand>` (weniger Entry-Points…
- [ ] `R99` `medinix gather <symptom>`
- [ ] `T-28-07` Q-28-04 pruefen: Blocky-customDNS-Mapping auf die LAN-IP des Hosts statt 127.0.0.1 (Verhalten fuer LAN-Clients…
- [ ] `T-28-08` Q-28-05 entscheiden: ARCHIVE-ADR-554 aus HEAD als Archivkopie zurueckholen ODER Loeschung in .agent-state.json…
- [ ] `T-28-12` Restliche Infra-Strings in den destillierten Todo-Daten (todo/plan.json, todo/decisions.json, todo/antipattern…
- [ ] `T12` QEMU-Smoke-Test lokal freischalten (Stufe 3 der Prüf-Leiter)
- [ ] `T14` 515 mDNS-Refresh umbauen. ⚠️ Der Punkt sagt selbst: `.path`-Trigger ist bereits systemd-nativ, „Umbau = latera…
- [ ] `T9` Root-Dateien nach `docs/CONVENTIONS.md` konsolidieren (`ADMIN-HANDOFF.md`, `AGENTS.md`, `CLAUDE.md`, `opencode…

### niedrig (6)

- [ ] `N-27-02` caddy-ratelimit durch nftables ersetzen
- [ ] `N-29-04` /home/moritz/repos/mediNix-core/docs/agents/shared/scripts/scan_inconsistencies.py kennt ADR-0000 §14 nicht un…
- [ ] `N-29-05` folder_lint meldet zwei Ordner mit 0 Dateien: /home/moritz/repos/mediNix-core/todo/_index und /home/moritz/rep…
- [ ] `T-28-03` Q-28-03 pruefen: nftables-Syntax mit nft -c gegen das generierte Ruleset verifizieren
- [ ] `T-28-10` Q-28-07 pruefen: 8 ADR-Slug-IDs auf numerische IDs umstellen (Dateiname + Ueberschrift + Index + Verweise)
- [ ] `T-28-15` Magic Number pruefen: 1.1.1.1 als DoH-Upstream (515-blocky) und Route-Probe (50-core/wan-ip-provider.nix) uebe…

## 2. Ledger — Befunde ohne Abschluss

- [ ] L-015 (OPT) unvollständiges Frontmatter: `complexity:` fehlt bei **15** von 44 (`status:` inzwischen überall gesetzt) → Index zeigt `-/5` — Status: OPEN
- [ ] L-018 (OPT) fehlender Single-Entry (`medinixLib`; Meisterstück nutzt `inherit (medinixLib) …`) — Status: OPEN
- [ ] L-050 (BUG) Erster echter Host-Build (q958, nixpkgs `e554fab`) deckte drei Integrationsfehler auf, die in der synthetischen Pruefkonfiguration unsichtbar sind: (1 — Status: "external"`; external setzt weder `enable` noch `ports` und haengt nur `customDNS` an (Attrset mergt). Default bleibt `managed`, Pruefkonfig baut unveraendert. (2) Notifier-Template hinter `lib.mkIf cfg.enable`. (3) Exporter laedt `LoadCredentialEncrypted = NAME-api-key:<sealed>` und uebergibt `--api-key-file /run/credentials/<unit>/...`. Deploy auf q958: Generation 9, sonarr `127.0.0.1:5320` aktiv, 0 failed Units.
- [ ] L-051 (BUG) Der versiegelte Arr-API-Key kommt beim Dienst **nie an**. Gemessen auf q958: Unit setzt `SONARR_API_KEY_FILE=/run/credentials/sonarr.service/sonarr-ap — Status: **WIP** (2 offen)

## 3. Pflicht bei jeder Änderung

- [ ] Diff vorlegen, Go abwarten (AGENTS.md).
- [ ] Volle Prüf-Leiter: nixfmt-Sweep, 5 Checks **bauen**, `nix flake check`, docs-Paket.
- [ ] Erst lokal messen, dann **ein** Push (Korridor-Regel).
