# mediNix-core — Roadmap & Backlog

Zentrale Sammelstelle für laufende Aufgaben, geplante Features, verworfene Ansätze und abgeschlossene Meilensteine.

> [!IMPORTANT]
> **Eiserne Regel für Agenten:** Neue Ideen wandern **ausschließlich** in `## Backlog`. Nie unaufgefordert Produktivcode ändern. Vor jeder Änderung `.agent-state.json` prüfen — dort steht der Entscheidungs-Korridor (Whitelist/Blacklist, 21 Regeln).
>
> **Historie:** Dies ist die **einzige** Roadmap. Bis 2026-10-15 existierten vier konkurrierende (`docs/ROADMAP.md`, `docs/ROADMAP-DEZIMALRAHMEN-MIGRATION.md`, `docs/PHASE4-SPEC.md`); sie liegen unverändert als Momentaufnahmen in `docs/audit/2026-10-15/`.

---

## In Progress

- [x] **(2026-10-15) Doku-Konsolidierung:** erledigt — eine Roadmap (dieses Dokument), Ledger/Handoff korrigiert, Fehlversuche archiviert, Repo-Aufraeumen (L-040/L-041) durchgefuehrt.

---

## Backlog

*Priorisiert, P0 zuerst. Jeder Eintrag nennt die Quelle, damit die Vorgeschichte nachvollziehbar bleibt.*

### P0 — Verfassungs-Verstöße in Guardrails und Vorlagen

- [x] **OCI/Podman widerspricht ADR-0000** an zwei Stellen (behoben `b9a146f`; die Vorlage wurde dabei komplett verfassungskonform neu geschrieben): die Assertion-Meldung in `50-core/500-host-baseline.nix:73` nennt „optional rootless Podman via oci-containers" als zulässig, und `docs/examples/5xx-service.example.nix:9-10` führt OCI als „Prio 2". Korrekt ist: keine Container (ADR-0000, `docs/NO-CONTAINERS.md`). Quelle: Migrations-Roadmap §3.7.
- [x] **Toter Pfad** `config.decimalFramework.manifest` (behoben `b9a146f`) in `lib/decimal-framework.nix:85` — die Option existiert nicht, nur `config.medinix.manifest`. Quelle: §3.8.
- [x] **Tautologische Assertion:** (behoben `b9a146f`; geprüft wird jetzt die Verdrahtung: die Unit muss unter dem abgeleiteten Benutzer laufen) die Prüfung „Port und UID müssen num*10 entsprechen" kann nie fehlschlagen, weil beide readOnly aus `num` abgeleitet werden. Ersetzen durch eine Prüfung, dass die abgeleiteten Werte auch wirklich benutzt werden (systemd-Unit/User). Quelle: §3.5.
- [x] `docs/AGENTS.md` ist veraltet (behoben `eccf872`; Zeiger auf das Root-`AGENTS.md`) (nennt mediahost `192.168.0.10` und `/opt/data/50-mediNix`) und widerspricht dem Root-`AGENTS.md`. Ersetzen durch einen Kurz-Zeiger, Inhalt archivieren.

### P0 — Service-Ankreuzbogen (Formalisierung)

- [x] Auswahlfelder als `types.enum` (behoben `24f5ee5`; `ui.group` und `ops.priority` sind Enums, `ramBudget` ist ein Format-Pattern — die Werte stammen aus den 14 bestehenden Einträgen). **Dabei gelernt:** NixOS-Typen sind **lazy** — ein Enum auf einem Feld, das niemand liest, feuert nie. Deshalb liest eine neue Assertion die drei Felder für jeden Eintrag: `ui.group`, `ops.priority`, `ramBudget` (heute freie Strings). Die erlaubten Werte **aus den bestehenden Manifest-Einträgen ableiten**, nicht raten. `accessGroup`, `monitoring.type`, `metrics.type`, `arr.role` sind bereits Enums.
- [x] `docs/examples/SERVICE-TEMPLATE.nix` verfassungskonform (behoben `b9a146f`; Eigentümer-Tabelle + korrektes `mkMerge`-Muster inklusive): kein `users.users`, kein `Group`, kein `stateDir`-Port-Suffix, keine OCI-Zeile — nur Manifest + optional `execStart`.
- [ ] Optional Schicht 3: Generator `medinix-meta.py new-service` (fragt 8 Felder, prüft Paketexistenz live über den NixOS-MCP).

### P1 — Ratsche vervollständigen

- [x] **Dekaden-Rollen prüfen** (ADR-0000 §3) (behoben `b9a146f` für die prüfbare Hälfte: `flake.nix` erzwingt Datei-Dekade == Ordner-Dekade, der Contract die Slot-0-Regel; beide als feuernd bewiesen. Die *Bedeutung* der Rollen `_0.._9` bleibt Dokumentation): kein Check erzwingt die 10-Slot-Taxonomie `_0.._9`; `flake.nix` prüft nur „führende Ziffer == 5", `folder_lint.sh` nur „≥3 Dateien". Quelle: §3.10.
- [x] `checks.mediNix-stack-eval` erweitern (`9d4d0a4`: 18 Dienste — pocket-id, feishin, recyclarr, diskHealth, mdns, ddns ergänzt; **avahi/smartd laufen als Teil von `discovery.mdns` bzw. `diskHealth` mit**). Die Erweiterung fand sofort drei vorbestehende Konflikte (Ledger L-029…L-031)
- [x] `checks.mediNix-ports-verdrahtet`: zweiter Riegel neben dem Zahlen-Check (`b9a146f`-Nachfolger). Prüft, dass der Manifest-Port beim Daemon ankommt: 10 Dienste über Unit-Umgebung/nixpkgs-Settings, **gatus+ntfy** über die gerenderte YAML, **jellyfin** über das Seed-Template; `feishin` bleibt als einziger Dienst ohne Daemon ausgewiesen. Quelle: UPGRADE-MATRIX B1.
- [x] **Ratsche-Volldeckung** (2026-10-15): die Belegung erzeugt jetzt **43 fachliche Units** (vorher ~30) - `cloudflare-ddns`, drei `acme-*`, sieben `mediNix-*`-Maintenance-Units. Dabei fiel ein echter Bug auf: ein Kommentar in 513 interpolierte `${cfg.domain}` und brach den Unit-Build, wenn nur `ddns.zone` gesetzt war (L-033)
- [x] **nixmeta-Header-Check** (2026-10-15): `checks.nixmeta-check` (Python + PyYAML) erzwingt Header, YAML-Gültigkeit, `id/title/domain/last_reviewed` und `domain == Ordnerpräfix`; 24 Dateien repariert → **67/67 konform**. Zwei Negativtests belegen, dass er feuert
- [ ] **NIXMETA-Header vollständig nachziehen:** der Check ist eine *Ratsche* — offen bleiben `folder` (42/67), `status` (43/67), `complexity` (32/67) und `links.adr` (17/67). Dabei die **zwei Dialekte** zusammenführen (`sprite:` + flaches `adr:` in 55/56-playback vs. `links.adr`). Braucht Urteilsvermögen je Modul (complexity 1–5, primärer ADR) — deshalb bewusst nicht automatisiert
- [x] **Unit-Skripte als Check bauen** (L-037): `checks.mediNix-unit-scripts` baut die Skript-Derivationen der Voll-Stack-Belegung (50 Werte, Sekunden) und fängt SC2050 & Co. lokal und in der CI. Ursprungsbefund L-036
- ~~**Unit-Skripte als Check bauen**~~ erledigt (siehe oben), offene Variante: `writeShellApplication` laesst shellcheck laufen, aber nur beim *Bauen* — `--no-build` ist blind dafuer. Ein Check `mediNix-unit-scripts`, der die `.drv`-Pfade aus dem String-Kontext der Unit-Skripte baut (77 Derivationen, Sekunden statt Minuten), schliesst diese Klasse lokal UND in der CI
- [x] **513: Token aus `argv` geholt** (L-039) — nativ per `curl --variable token@$RUNTIME_DIRECTORY/cf-token --expand-header` (0600-Datei, `unset TOKEN`); `lib/mk-secure-curl.nix` damit `deprecated`
- [x] **Service-Map generieren:** `scripts/gen_service_map.py` leitet die Map in `docs/INDEX.md` (Marker-Zone `SERVICE-MAP START/END`) aus `lib/registry.nix` ab, fail-closed (unbekanntes Registry-Muster = Abbruch mit Zeilennummer); `--check` läuft in `order-lint`. Die Ordner-`AGENTS.md`-Tabellen waren bereits generiert (`medinix-meta.py generate-docs`).
- [x] **`docs/TODO.md`-Aktualitaet in CI:** `python3 scripts/gen_todo.py --check` in `order-lint.yml` (ec5fb91).

- [ ] **Registry-Felder richtigstellen (offene Frage):** `lib/registry.nix` setzt `gid = 5000` (flat GID) und bei `mkNoPortWithUnit` `uid = null`, obwohl 513 real `uid = 5130` läuft; Guardrail `591:68` verlangt sogar `s.gid == 5000`. Widerspruch zu ADR-0000 §4/§5 (UPG) — Entscheidung nötig, ob die Felder auf `number * 10` umgestellt werden.
- [ ] **Datei-basierte Ports härter prüfen:** für jellyfin den gerenderten XML-Inhalt greppen (heute nur Seed-Platzhalter + Substitution im Quelltext)
- [x] Negativtest „eine kaputte Konfiguration muss brechen" (`9d4d0a4`: drei dauerhafte Checks — `negative-slot0-daemon`, `negative-identity-wired`, `negative-ankreuzbogen` (Paar-Vergleich). Der Dekaden-Check lässt sich nicht als nixosSystem prüfen (er liest Ordner); er wurde per gestagter Probe bewiesen — teilweise erledigt: die vier neuen Gates wurden 2026-10-15 per gestagter Probe-Datei als feuernd **bewiesen**; ein *dauerhafter* Check dafür fehlt noch (die Assertions selbst testen). Quelle: B4.

### P1 — Dienste und Betrieb

- [ ] 516 CrowdSec Bouncer (ersetzt die Fail2ban-Übergangslösung auf Caddy-Logs). Der `lib.fakeHash` in 511 ist bereits entfernt; das Modul fehlt.
- [ ] `lib/gpu.nix` (Vendor-Abstraktion intel/amd/nvidia), `lib/network-cidrs.nix`, `rebuild-guard.nix`. Quellen: UPGRADE-MATRIX A6/A7/A8.
- [ ] `vpn-killswitch-test.sh` (echter Egress-Leak-Test), `on-demand-http.nix` (Socket-Activation für Lidarr/Readarr). Quellen: E5/D8.
- [ ] Pocket-ID Auto-Enrollment Helper; Multi-User/RBAC über versiegelte Credentials.
- [ ] Prometheus Node-Exporter + Caddy-Metrics (teilweise vorhanden: 585-exporters, 582-gatus).
- [ ] Flake-Lock-Auto-Update (wöchentlicher Workflow mit `nix flake check`).

### P2 — Observability/Logging-Ausbau

- [ ] Vector + Loki + Grafana: Journal + Caddy-JSON-Logs, 7 Tage Retention, Storage auf Tier B, Grafana hinter Caddy am Unix-Socket.
- [ ] HDD-freundliche Deferred-Deletion-Queue (`hdparm -C`-Check, Force nach `maxAgeDays = 7`).
- [ ] Label-basiertes Automounting/MergerFS (teilweise: `570-storage.nix` kann MergerFS-Pools, das Einhängen macht der Host).

### P2 — Aufräumen

- [x] Die 4 nie verdrahteten `lib`-Module entschieden (971203c): markiert statt geloescht (`abc-tiering`/`_helpers` → `deprecated`, `wait-for-api`/`mk-secure-curl` → `draft`, `mk-secure-curl` inzwischen `deprecated`). Ursprungs-Notiz:  `abc-tiering.nix` (von `storage.backends.hot/cold` überholt), `mk-secure-curl.nix`, `wait-for-api.nix`, `_helpers.nix`.
- [x] `docs/AGENT_SOURCES.md` und `docs/UPSTREAM-SOURCES.md` zusammengelegt (L-041): eine Liste, Abschnitt 2 in `docs/UPSTREAM-SOURCES.md`; die alte Datei ist Zeiger.
- [ ] `git branch -d refactor/decades-conformance` lokal und remote — ist in `audit-2026-10-15` gemergt.

---

## Verworfen

*Dauerhaft ausgeschlossen. Vollständige Begründung, Beweis und `revive_if` stehen im Korridor (`.agent-state.json` → `corridor.blacklist`).*

| Was | Warum | Regel |
|---|---|---|
| sops / age / agenix / sops-nix | Nutzerentscheidung projektweit; Standard ist `systemd-creds` | AB-013 |
| OCI/Container für Dienste | ADR-0000, `docs/NO-CONTAINERS.md` | AB-017 |
| `DynamicUser = true` | zerstört die UID-Isomorphie (einzige Ausnahme: `alert-ntfy@`, identitätslos) | AB-007 |
| netns-Confinement, eBPF-Killswitch | abgelöst durch nftables `meta skuid` + Route-Hook | AB-007 |
| Zwei Service-Engines / doppeltes Eigentum | harter Eval-Abbruch; jetzt: genau ein Eigentümer pro Option | AB-002 |
| Port-suffizierte `stateDir`s (`/var/lib/<name>-<port>`) | ADR-0000 §9 | AB-006 |
| `mkForce` als Problemlöser | MANIFEST §2 | AB-008 |
| Inline-Hardening statt `lib/hardening-profiles.nix` | ein Ort für die Härtungspolitik | AB-009 |
| Upstream-Module mit `DynamicUser` übernehmen | stiller ADR-Bruch (Gatus-/ntfy-Fall) | AB-019 |
| Einzel-Check ohne erzwungenen `toplevel` | verdeckt Voll-Stack-Fehler über Tage | AB-020 |
| Audiobookshelf QuickSync/VA-API | reiner Audioserver — kein Codec-Nutzen, schwächt die Sandbox | docs/ROADMAP §4 (alt) |
| Allround-Apps (Vaultwarden, Paperless, Home Assistant, Forgejo, Cockpit, AMP) | gehören auf den Host, nicht in einen Media-Flake | ebd. |
| Host-Netzwerk-DNS (Blocky, AdGuardHome) | Host-/Router-Aufgabe | ebd. |
| Zentrale Shared-DBs (PostgreSQL, Valkey) | mediNix bleibt autonom mit isolierten SQLite-Datenbanken | ebd. |
| `lib.recursiveUpdate` für Sandbox-Attrs | überschreibt später `ExecStartPre` kommentarlos → `mkMerge` nutzen | UPGRADE-MATRIX N2 |

---

## Done

### 2026-10-15 — UPG-Umstellung, Voll-Stack-Ratsche, Corridor

- [x] **Eval-Blocker beseitigt** — `lib/decimal-framework.nix` gab zusätzliche Top-Level-Attribute zurück (als Modul unzulässig). `a03d0aa` — von 0 auswertbaren Checks auf 26.
- [x] **Genau ein Eigentümer für `users.users.<dienst>`** — die Engine besitzt, die Factory nur für Units ohne Manifest-Eintrag (`ownsAccount`). `d999cf0`, `57b983b`.
- [x] **Sabnzbd auf UPG**, Registry als dritte `stateDir`-Wahrheit angeglichen, tote `needsMediaGroup`-Zweige deklariert (statix-Fund). `a798cec`.
- [x] **Voll-Stack-Ratsche** `checks.mediNix-stack-eval` (12 Dienste, erzwungener `toplevel`). `3381fc4`.
- [x] **Vier Altlasten behoben:** SABnzbd-`IPAddressAllow` (Build-Abbruch ohne VPN-Confinement), `RestartSec`-Konflikt Profil/Exporter, Gatus und ntfy (`DynamicUser` verboten; Gatus band zusätzlich Port 8080 statt 5820). `3eb4bac`, `5bbaac8`.
- [x] **Guardrail 591** auf UPG umgestellt: Unit-Gruppe ist der Dienstname **oder** `media`, und `media` muss für den Benutzer erreichbar sein. `57b983b`.
- [x] **SetGID (2775)** auf allen geteilten Ablagen (Folge der UPG-Umstellung). `782211d`.
- [x] **Entscheidungs-Korridor** in `.agent-state.json` (Schema 1.1): 10 Whitelist-Kategorien, 21 Blacklist-Regeln, 5 offene Entscheidungen, 6 getroffene. `df0352f`.
- [x] **Root-Audit nach `docs/CONVENTIONS.md` (2026-10-15):** `ADMIN-HANDOFF.md`, `UPSTREAM-SOURCES.md` und `audits/` (3 Dateien) nach `docs/` bzw. `docs/audit/2026-09/` verschoben (`git mv`); `CLAUDE.md` war byte-identisch zu `AGENTS.md` → jetzt ein Zeiger; die UPG-Invariante in `AGENTS.md` korrigiert (`media` nur `extraGroups`); Root-Ausnahmen in den CONVENTIONS dokumentiert. `b451f50`-Nachfolger.
- [x] **Werkzeugkette:** Nix nativ (Determinate 3.23.2), `mcp-nixos` 3.1.0, ShellCheck/Shfmt/Yamllint, actionlint; alle Workflows lint-clean. `7e09e60`.
- [x] **Lehre festgehalten:** `nix flake check --no-build` verdeckt nixfmt-/statix-/deadnix-Funde — die Lint-Checks müssen **gebaut** werden. `b451f50`.

### 2026-10-14 (Kurzfassung, Details im Changelog)

- [x] CI-Reparatur & VM-Härtung, MIT-Lizenz, LLM-Digest-Pipeline, Issue-Bereinigung, Red-Team Runde 3, ADR-0000-Verfassung.

---

## Herkunft und Archiv

- `docs/audit/2026-10-15/` — Momentaufnahmen der vier früheren Roadmaps, der Migrations- und der Bergungs-Matrix.
- `docs/AUDIT-LEDGER.md` — Befund-Gedächtnis mit Quelle und Rollback je Zeile.
- `.agent-state.json` — Korridor: Invarianten, Whitelist, Blacklist, offene Entscheidungen.
