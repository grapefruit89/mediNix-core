# mediNix-core — CLAUDE.md & AGENTS.md

> [!IMPORTANT]
> **REINE LOKALE AUSFÜHRUNG:** Es existieren keine externen Remote-Hosts. Jeglicher SSH- oder rsync-Zugriff auf externe Test-Hosts ist strikt untersagt. Alle Builds, AST-Checks und Flake-Prüfungen finden ausschließlich lokal statt.

## Architektur-Invarianten (ADR-0000, NICHT verhandelbar)
- **Dezimalrahmen:** Port = ServiceNum × 10 | UID = Port | GID = 5000
- **Flache Struktur:** `XX-domain/NNN-service.nix` — nie tiefer verschachteln
- **systemd-native:** kein Docker, kein netns. WireGuard OK als `NetworkNamespacePath`/UID-Routing
- **Chameleon Caddy:** `config.services.caddy.enable` → inject | else → `caddy-media`
- **Binding:** alle Dienste auf 127.0.0.1 (nur Ingress exponiert)
- **Fail-closed:** Assertions = Build-Abbruch, nie nur Warnung
- **Keine Inline-Secrets:** nur `LoadCredentialEncrypted` / `EnvironmentFile`
