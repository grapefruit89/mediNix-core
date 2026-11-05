# PLAN — Fahrplan aus `todo/tasks.json`

> [!CAUTION]
> **Diese Datei ist generiert und darf nicht von Hand geändert werden.**
> Quelle: `/home/moritz/repos/mediNix-core/todo/tasks.json`. Neu erzeugen:
> `python3 /home/moritz/repos/mediNix-core/scripts/gen_plan.py`.
> Leitfaden zur Orderstruktur: Kopf von `/home/moritz/repos/mediNix-core/AGENTS.md`.

> **Generiert** am 2026-11-05 aus `todo/tasks.json` (91 Tasks, 60 offen).
> Nicht von Hand pflegen. Quelle: `todo/tasks.json`. Prüfen: `python3 scripts/gen_plan.py --check`.

**Richtwert Aufwand:** 193 h netto über alle offenen Punkte (S ≤ 1 h · M ≤ 4 h · L > 4 h). Ohne Recherche, Prüf-Leiter, CI-Wartezeit und Review — real liegt das bei Faktor 1,3–1,5.

## W0 — Abschluss & Hygiene (3 Punkte, ~3 h)

_Kleine Aufraeumarbeiten. Danach ist die Liste ehrlich kurz._

| ID | Aufwand | Art | Punkt | Abnahme | Quellen |
|---|---|---|---|---:|---:|
| `N-29-05` | S | feature | folder_lint meldet zwei Ordner mit 0 Dateien: /home/moritz/repos/mediNix-core/todo/_index und /home/moritz/rep… | 2 | 1 |
| `T-28-03` | S | feature | Q-28-03 pruefen: nftables-Syntax mit nft -c gegen das generierte Ruleset verifizieren | 2 | 2 |
| `T-28-15` | S | feature | Magic Number pruefen: 1.1.1.1 als DoH-Upstream (515-blocky) und Route-Probe (50-core/wan-ip-provider.nix) uebe… | 3 | 2 |

### `N-29-05` — folder_lint meldet zwei Ordner mit 0 Dateien: /home/moritz/repos/mediNix-core/todo/_index und /home/moritz/rep…

**Abnahme:**
- folder_lint meldet 0 Ordner mit weniger als 3 Dateien
- `.claude/skills` ist entfernt oder in der Allowlist begruendet

**Quellen:**
- `internal` · docs/agents/shared/scripts/folder_lint.sh — Allowlist Zeile 17: tests|scripts|references|templates|evals|audit

### `T-28-03` — Q-28-03 pruefen: nftables-Syntax mit nft -c gegen das generierte Ruleset verifizieren

**Abnahme:**
- generiertes nftables-Ruleset mit `nft -c -f` geprueft, Exit 0
- Pruefausgabe im Commit dokumentiert

**Quellen:**
- `internal` · 52-security/520-core-security.nix — Quelle der Regeln
- `resource` · nixos-manual — networking.nftables-Syntax und Regelsatz

### `T-28-15` — Magic Number pruefen: 1.1.1.1 als DoH-Upstream (515-blocky) und Route-Probe (50-core/wan-ip-provider.nix) uebe…

**Abnahme:**
- 1.1.1.1 nicht mehr hartkodiert in 51-ingress/515-blocky.nix
- Option fuer den DoH-Upstream mit Default 1.1.1.1
- check_nixos_anchors und nixmeta gruen

**Quellen:**
- `internal` · 51-ingress/515-blocky.nix — heutiger DoH-Upstream
- `resource` · nixos-wiki — services.blocky Optionen

## W1 — Deploy-Blocker & Datenlecks (5 Punkte, ~21 h)

_Sicherheit vor Features: ein Host-Build-Blocker und Infra-Daten im Git-Repo._

| ID | Aufwand | Art | Punkt | Abnahme | Quellen |
|---|---|---|---|---:|---:|
| `Q-28-08` | S | decision | 19 committete Dateien (Roh-Chat-Exporte in todo/done/, Destillate in todo/*.json) enthalten Infra-Metadaten (e… | 2 | 1 |
| `R47` | M | bug | L-047: echte Credential-Quelle für root/wheel. `users.mutableUsers = lib.mkDefault false` braucht einen realen… | 3 | 4 |
| `T-28-12` | M | feature | Restliche Infra-Strings in den destillierten Todo-Daten (todo/plan.json, todo/decisions.json, todo/antipattern… | 3 | 2 |
| `T-28-13` | M | feature | Guard scripts/check_infra_leaks.py: verbietet echte WAN-Domain, LAN-Subnetze (RFC 1918) und oeffentliche IPv4… | 3 | 2 |
| `T-28-11` | L | feature | Roh-Chat-/Audit-Exporte mit Infra-Metadaten aus Git entfernen: todo/done/2026-10-25_*/input/chat.json, todo/do… | 3 | 2 |

### `Q-28-08` — 19 committete Dateien (Roh-Chat-Exporte in todo/done/, Destillate in todo/*.json) enthalten Infra-Metadaten (e…

**Abnahme:**
- Entscheidung im Task dokumentiert (behalten + begruenden ODER entfernen + Archiv)
- Konsequenz fuer T-28-11 und T-28-13 notiert

**Quellen:**
- `internal` · docs/audit/2026-11-05/todo-blocks/28-verify-open-points.json — Q-28-08: 19 committete Dateien

### `R47` — L-047: echte Credential-Quelle für root/wheel. `users.mutableUsers = lib.mkDefault false` braucht einen realen…

**Abnahme:**
- Host-Build ohne testHostAccess-Stub moeglich
- users.mutableUsers = false mit realem Login-Pfad belegt
- nix flake check gruen, kein mkForce als Abkuerzung

**Quellen:**
- `internal` · docs/AUDIT-LEDGER.md — L-047: Build-Blocker
- `internal` · docs/adr/ADR-0002-nixos-grundfunktionen.md — mutableUsers-Entscheidung
- `resource` · nixos-manual — users.mutableUsers, initialPassword, hashedPassword
- `resource` · nix-community-sops-nix — Alternative Credential-Quelle

### `T-28-12` — Restliche Infra-Strings in den destillierten Todo-Daten (todo/plan.json, todo/decisions.json, todo/antipattern…

**Abnahme:**
- Infra-Strings in todo/decisions.json, todo/antipatterns.md und den archivierten Blocks gescrubbt
- Ersatz durch example.com und RFC-5737-Netze
- check_infra_leaks.py meldet 0

**Quellen:**
- `internal` · docs/audit/2026-11-05/todo-blocks/28-verify-open-points.json — Fundstelle
- `resource` · nix-security-tracker — Umgang mit sensiblen Host-Daten

### `T-28-13` — Guard scripts/check_infra_leaks.py: verbietet echte WAN-Domain, LAN-Subnetze (RFC 1918) und oeffentliche IPv4…

**Abnahme:**
- scripts/check_infra_leaks.py existiert und findet 0 Treffer im Baum
- erkennt die bekannten Exporte, wenn man sie zurueckspielt
- eingebunden in .github/workflows/order-lint.yml und scripts/verify.sh

**Quellen:**
- `internal` · docs/AUDIT-LEDGER.md — L-044: jede Kante braucht einen Check
- `resource` · nix-dev — Muster fuer kleine Guard-Skripte

### `T-28-11` — Roh-Chat-/Audit-Exporte mit Infra-Metadaten aus Git entfernen: todo/done/2026-10-25_*/input/chat.json, todo/do…

**Abnahme:**
- keine Roh-Exporte mit Infra-Metadaten mehr in todo/done/
- entfernte Dateien vorher in ein privates Archiv verschoben (AB-036)
- `git log -S` nach der echten WAN-Domain liefert ab diesem Commit 0 Treffer

**Quellen:**
- `internal` · docs/AUDIT-LEDGER.md — L-044: Kante braucht einen Check
- `internal` · docs/audit/2026-11-05/todo-blocks/28-verify-open-points.json — Fundstelle T-28-11

## W2 — Entscheidungen (15 Punkte, ~24 h)

_Jede Frage einzeln billig, blockiert aber die Folgeschritte._

| ID | Aufwand | Art | Punkt | Abnahme | Quellen |
|---|---|---|---|---:|---:|
| `Q-15-01` | S | decision | Welche konkreten Prüfkriterien umfassen die restlichen der 44 Nixmap-Auditregeln im vollständigen Regelsatz? | — | — |
| `Q-28-02` | S | decision | Das nie gebaute Modul (geplant als lib/wan-ip-provider.nix, heute 50-core/) deklariert { lib, pkgs ? null }, n… | — | — |
| `Q-28-03` | S | decision | Ist die nftables-Regel 'tcp dport 80 meter flood-http { ip saddr limit rate over 25/minute burst 50 packets }… | — | — |
| `Q-28-04` | S | decision | 515-blocky.nix setzt customDNS.mapping fuer 'lan' und '<domain>' auf 127.0.0.1 | — | — |
| `Q-28-05` | S | decision | Korridor AB-036 ('Ausgemustertes archivieren statt loeschen') vs. geloeschte docs/archive/ARCHIVE-ADR-554-feis… | — | — |
| `Q-28-07` | S | decision | check_adrs listet 8 Legacy-Slug-IDs (ADR-571-sqlite-wal, ADR-576-backup-classification, ...) statt numerischer… | — | — |
| `Q-29-04` | S | decision | scripts/skills-exclude.txt fuehrt seit Wochen vier Merge-Kandidaten als Kommentar: medinix-nix-idioms (doppelt… | — | — |
| `Q-29-05` | S | decision | Soll ein Front-Matter-Feld 'scope: medinix\|generic' eingefuehrt werden (31 SKILL.md-Dateien + eine Regel in sc… | — | — |
| `Q-29-06` | S | decision | Die 9 in scripts/skills-exclude.txt ausgeschlossenen Skills (kanban-orchestrator, kanban-worker, hermes-sessio… | — | — |
| `Q-29-07` | S | decision | Zwei Kategorien ohne Skill: /home/moritz/repos/mediNix-core/docs/agents/08-mcp-second-brain (nur CONCEPT.md) u… | — | — |
| `Q-29-08` | S | decision | ADR-0000 §11 und /home/moritz/repos/mediNix-core/docs/TERMINOLOGY.md beschreiben beide Semantic Anchors | — | — |
| `T-28-10` | S | feature | Q-28-07 pruefen: 8 ADR-Slug-IDs auf numerische IDs umstellen (Dateiname + Ueberschrift + Index + Verweise) | — | — |
| `N-29-06` | M | feature | Q-29-04 entscheiden und danach die vier Merge-Paare abarbeiten: medinix-nix-idioms+nixos-idiom-audit, nixos-fl… | — | — |
| `T-28-07` | M | feature | Q-28-04 pruefen: Blocky-customDNS-Mapping auf die LAN-IP des Hosts statt 127.0.0.1 (Verhalten fuer LAN-Clients… | — | — |
| `T-28-08` | M | feature | Q-28-05 entscheiden: ARCHIVE-ADR-554 aus HEAD als Archivkopie zurueckholen ODER Loeschung in .agent-state.json… | — | — |

## W3 — Struktur & SSOT (9 Punkte, ~35 h)

_Der letzte echte SSOT-Verstoss und die grossen Refactors._

| ID | Aufwand | Art | Punkt | Abnahme | Quellen |
|---|---|---|---|---:|---:|
| `B-S11K` | S | docs | ADR-0000 §11 vs. `docs/TERMINOLOGY.md` | — | — |
| `B-S410` | S | docs | ADR-0000 §4 (UPG) und §10 (Consequences) beschreiben teils dasselbe | — | — |
| `L15` | S | docs | `complexity:` fehlt bei 15 von 44 Modulen → Index zeigt `-/5` | — | — |
| `B-CA` | M | refactor | `caddyClass` vs. `accessGroup` | — | — |
| `L18` | M | refactor | Single-Entry `medinixLib` fehlt | — | — |
| `R161` | M | docs | ADR-Verweis-Rest (Kette Code → ADR). 7 Allowlist-Einträge in `scripts/adr-refs-allowlist.txt` abarbeiten | — | — |
| `T9` | M | refactor | Root-Dateien nach `docs/CONVENTIONS.md` konsolidieren (`ADMIN-HANDOFF.md`, `AGENTS.md`, `CLAUDE.md`, `opencode… | — | — |
| `R55` | L | refactor | Identitäten einmal ableiten (ADR-040 Endform) | — | — |
| `R56` | L | refactor | NIXMETA-Header vollständig nachziehen | — | — |

## W4 — Gates, Betrieb & Doku (12 Punkte, ~40 h)

_Macht Fehler sichtbar, statt sie zu suchen._

| ID | Aufwand | Art | Punkt | Abnahme | Quellen |
|---|---|---|---|---:|---:|
| `N-25-01` | S | feature | Dokumentationstrias in ADR-0000 oder docs/ verankern | — | — |
| `R94` | S | docs | `docs/AUDIT-NIXOS-IDIOMS.md`: | — | — |
| `R95` | S | docs | CONVENTIONS §Audit: drei Schichten + Prüf-Leiter Stufe 0a (`idiom_audit --p0-only`) und Stufe 1a (`nix flake c… | — | — |
| `R96` | S | feature | CI Stufe 0a: `nixos_idiom_audit.py --p0-only` in `.github/workflows/order-lint.yml` (fail-closed) | — | — |
| `B-M4` | M | bug | 591 Options-Pfad-Assertion | — | — |
| `R163` | M | docs | Skill-Trigger nachschärfen. 18 von 30 Projekt-Skills haben eine `description` unter 80 Zeichen | — | — |
| `R66` | M | bug | Datei-basierte Ports härter prüfen | — | — |
| `R76` | M | feature | Flake-Lock-Auto-Update: wöchentlicher Workflow mit `nix flake check` | — | — |
| `R93` | M | feature | `scripts/systemd-facts.sh`: host-seitiges JSON-Bundle („was systemd hier kann") aus `systemctl list-units --ou… | — | — |
| `R97` | M | docs | `docs/HOST-INTERFACE.md`: eine Seite „Host-Schnittstelle" | — | — |
| `T12` | M | feature | QEMU-Smoke-Test lokal freischalten (Stufe 3 der Prüf-Leiter) | — | — |
| `R99` | L | feature | `medinix gather <symptom>` | — | — |

## W5 — Features (nicht freigegeben) (16 Punkte, ~70 h)

_Braucht pro Punkt eine YAGNI-Pruefung. Mehrere Punkte doppeln bereits laufende Infrastruktur (VictoriaLogs, VictoriaMetrics) oder Pocket-ID-Features._

| ID | Aufwand | Art | Punkt | Abnahme | Quellen |
|---|---|---|---|---:|---:|
| `N-27-01` | S | feature | nftables GeoIP-Sets evaluieren | — | — |
| `N-27-02` | S | feature | caddy-ratelimit durch nftables ersetzen | — | — |
| `N-29-04` | S | feature | /home/moritz/repos/mediNix-core/docs/agents/shared/scripts/scan_inconsistencies.py kennt ADR-0000 §14 nicht un… | — | — |
| `R100` | S | feature | Doc-Nit (N): `docs/agents/07-patterns-misc/nixos-llm-first-workflow/SKILL.md:183` ist stale (`nix-env -iA nixp… | — | — |
| `R88` | S | feature | `git branch -d refactor/decades-conformance` lokal und remote | — | — |
| `T14` | S | refactor | 515 mDNS-Refresh umbauen. ⚠️ Der Punkt sagt selbst: `.path`-Trigger ist bereits systemd-nativ, „Umbau = latera… | — | — |
| `R72` | M | feature | `50-core/gpu.nix` (Vendor-Abstraktion intel/amd/nvidia), `50-core/network-cidrs.nix`, `rebuild-guard.nix` | — | — |
| `R73` | M | security | `vpn-killswitch-test.sh` | — | — |
| `R75` | M | feature | Prometheus-Scraper fehlt | — | — |
| `R81` | M | feature | Deferred-Deletion-Queue: | — | — |
| `R24` | L | feature | FIDO2 / Passkey-only Authentifizierung | — | — |
| `R37` | L | feature | Generator `medinix-meta.py new-service` („Ankreuzbogen Schicht 3"): fragt 8 Felder, prüft Paketexistenz live ü… | — | — |
| `R74` | L | feature | Pocket-ID Auto-Enrollment + Multi-User/RBAC über versiegelte Credentials | — | — |
| `R80` | L | feature | Vector + Loki + Grafana | — | — |
| `R82` | L | feature | Label-basiertes Automounting/MergerFS | — | — |
| `R98` | L | feature | `arr-provision` bündeln: 8 Einzel-CLIs (`arr-sync-*`) → ein `arr-provision <subcommand>` (weniger Entry-Points… | — | — |

## Was der Fahrplan nicht regelt

- **Reihenfolge innerhalb einer Welle** ist frei; Abhängigkeiten stehen als
  `depends_on` im Task.
- **Welle 5 ist nicht freigegeben.** Jeder Punkt dort braucht zuerst die Frage:
  brauchen wir das wirklich, oder ist es Wunschdenken?
- **Schätzungen sind Richtwerte.** Die drei unsichersten Punkte: `R47`
  (Architekturentscheidung), `R55`/`R56` (breite Refactors).
