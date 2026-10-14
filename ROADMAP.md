# mediNix-core — Roadmap & Backlog

Zentrale Sammelstelle für neue Feature-Ideen, laufende Entwicklungsaufgaben und abgeschlossene Meilensteine.

> [!IMPORTANT]
> **Eiserne Regel für Agenten:** Neue Feature-Ideen, Erweiterungsvorschläge oder architektonische Gedanken wandern **ausschließlich** als Ticket in den Abschnitt `[Backlog / Ideen]`. Niemals eigenmächtig oder unaufgefordert Änderungen am Produktivcode vornehmen!

---

## [In Progress]
*Aktuelle Arbeitspakete in aktiver Bearbeitung:*

- [x] **Agentic Workflow Härtung:**
  - Etablierung der maschinenlesbaren Status-Registry ([`.agent-state.json`](file:///home/moritz/repos/mediNix-core/.agent-state.json)) inkl. Verweis auf [`docs/adr/llm-index.json`](file:///home/moritz/repos/mediNix-core/docs/adr/llm-index.json).
  - Zentrale Upstream-Quellenverankerung ([`UPSTREAM-SOURCES.md`](file:///home/moritz/repos/mediNix-core/UPSTREAM-SOURCES.md)).
  - Agenten-Arbeitsverfassung mit ADR-0000 Zwang in [`AGENTS.md`](file:///home/moritz/repos/mediNix-core/AGENTS.md) und [`CLAUDE.md`](file:///home/moritz/repos/mediNix-core/CLAUDE.md).

---

## [Backlog / Ideen]
*Ideenspeicher für zukünftige Entwicklungszyklen (nicht ungefragt implementieren):*

- [ ] **Modul 516 (CrowdSec Bouncer):**
  - Implementierung eines vollwertigen CrowdSec-Moduls als Ersatz für die Übergangslösung mit Fail2ban auf den Caddy-Access-Logs (RT-3).
- [ ] **Pocket-ID Auto-Enrollment Helper (Abschnitt 12):**
  - Automatisierte REST-API-Skripte zur Registrierung von OIDC-Clients (z. B. für Jellyfin/Audiobookshelf) direkt beim Initial-Boot.
- [ ] **Multi-User Delegation & RBAC:**
  - Standardisiertes User-Provisioning für Audiobookshelf und Navidrome via versiegelte systemd-Credentials (`medinix.*.adminPasswordCredential`).
- [ ] **Observability & Health-Stack (ADR-58x):**
  - Prometheus Node-Exporter & Caddy-Metrics-Scraping im 58-observability-Modul.
- [ ] **Automated Flake Lock Auto-Update:**
  - GitHub Actions Workflow für wöchentliche Dependabot/Flake-Input-Updates mit automatisiertem `nix flake check`.

---

## [Done]
*Erfolgreich implementierte und verifizierte Meilensteine:*

- [x] **CI "Flake Check" Reparatur & VM-Härtung (2026-10-14):**
  - Nixfmt-Formatierung in `574-provisioning.nix`.
  - QEMU-Smoke-Test Ressourcen angehoben (2048 MB / 2 Kerne) und WireGuard Device-Teardown via `ip link del dev wg0` korrigiert.
  - Ingress-Header-Strip Check mit `medinix.domain` und Zeilenvergleichs-Assertion repariert.
  - nftables Route-Chain Syntaxfehler (`chain vpn_mark`, kein `policy accept;`) behoben.
  - VHost-Check in `checks.mediNix-ntfy-vhost-and-admin-socket` auf `.lan` aktualisiert.
  - Remote CI-Lauf `38573556486` grün (Success, Exit-Code 0).
- [x] **Open-Source Standardisierung (2026-10-14):**
  - Standard-MIT-Lizenzdatei ([`LICENSE`](file:///home/moritz/repos/mediNix-core/LICENSE)) erstellt.
  - Lizenz- und Homelab-Hinweise in [`README.md`](file:///home/moritz/repos/mediNix-core/README.md) dokumentiert.
- [x] **LLM Markdown Digest Pipeline (2026-10-14):**
  - Export-Skript `.github/scripts/export-folders.sh` auf Plaintext-ToC, Syntax-Highlighting und 4-fach Backtick-Fencing umgestellt.
  - GitHub Actions Workflow `.github/workflows/export-folders.yml` auf nativen POSIX-Stack ohne Fremd-Python-Tools migriert und auf `digests`-Branch isoliert.
- [x] **Issue-Tracker Bereinigung (2026-10-14):**
  - Schließen von 5 historischen Chat-Dump-Issues (#2 bis #6) und Bereinigen des obsoleten Pull Requests #1 (`51-ingress-contracts`).
- [x] **Red-Team Runde 3: 51-ingress Dissektion (2026-10-02):**
  - RT-1 bis RT-9 Ingress-Sicherheitsmatrix implementiert (Unix Admin-Socket, First-Run-Race-Schutz, strukturierte JSON Access-Logs).
- [x] **ADR-0000 Verfassung & Dezimalrahmen:**
  - Mathematische Port- und UID-Gleichheit (`Port = UID = Num * 10`), GID 5000, 10-Domänen-Architektur und flache Modulstruktur.
