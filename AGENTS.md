# mediNix-core — AGENTS.md

> [!IMPORTANT]
> **REINE LOKALE AUSFÜHRUNG:** Es existieren keine externen Remote-Hosts. Jeglicher SSH- oder rsync-Zugriff auf externe Test-Hosts ist strikt untersagt. Alle Builds, AST-Checks und Flake-Prüfungen finden ausschließlich lokal statt.

---

## Eiserne Agenten-Arbeitsregeln (Strikte Arbeitsdisziplin)

1. **Vor jeder Code-Änderung (Pre-Check):**
   - Prüfe zwingend [`.agent-state.json`](file:///home/moritz/repos/mediNix-core/.agent-state.json) auf bekannte Sackgassen und Fehler (`dead_ends_and_failures`).
   - Konsultiere [`docs/adr/llm-index.json`](file:///home/moritz/repos/mediNix-core/docs/adr/llm-index.json) für aktive Architekturentscheidungen und Namenskonventionen.
2. **Nach jeder Code-Änderung (Post-Record):**
   - Dokumentiere jeden Fix, Refactor oder Invarianten-Schutz in [`.agent-state.json`](file:///home/moritz/repos/mediNix-core/.agent-state.json) unter `recent_refactorings`.
   - Trage genutzte GitHub-Repositories, Doku-Quellen oder Upstream-Muster in [`docs/UPSTREAM-SOURCES.md`](file:///home/moritz/repos/mediNix-core/docs/UPSTREAM-SOURCES.md) ein.
3. **Ideen-Verwaltung (Zero Code-Drift):**
   - Neue Projekt-Ideen, Erweiterungen oder Refactoring-Gedanken gehören **ausschließlich** in die [`ROADMAP.md`](file:///home/moritz/repos/mediNix-core/ROADMAP.md) (Abschnitt `Backlog`), niemals unaufgefordert oder spekulativ in den Code.
4. **Verfassungs-Zwang (ADR-0000):**
   - Jede Code-Änderung muss die Kern-Invarianten einhalten und wird per `nix flake check` lokal verifiziert.

---

## Architektur-Invarianten (ADR-0000, NICHT verhandelbar)

- **Dezimalrahmen (UPG):** `Port = UID = Primär-GID = ServiceNum × 10`. Die geteilte Gruppe `media` (GID 5000) ist **ausschließlich** als `extraGroups`/supplementary zulässig, niemals als Primärgruppe. Geteilte Ablagen: `2775 root:media` (SetGID), damit neue Dateien die Gruppe `media` erben.
- **Flache Struktur:** `XX-domain/NNN-service.nix` — nie tiefer verschachteln.
- **systemd-native:** Kein Docker, keine Container-Engines, kein Network Namespace (`netns`). VPN-Confinement erfolgt rein über `meta skuid` und Route-Hook Policy Routing.
- **Chameleon Caddy:** `config.services.caddy.enable` → inject in globalen Caddy | sonst → dedizierter `caddy-media` Unit-Besitzer.
- **Binding:** Alle Backend-Dienste binden ausschließlich an `127.0.0.1` (nur Ingress ist exponiert).
- **Fail-closed:** Assertions bedeuten sofortigen Build-Abbruch (`throw`), niemals stille Warnungen oder Ignorieren.
- **Keine Inline-Secrets:** Ausschließlich `LoadCredentialEncrypted` oder `EnvironmentFile`.
