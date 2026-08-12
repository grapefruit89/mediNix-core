# Warum keine Container in mediNix-core

## Entscheidung
mediNix-core nutzt ausschließlich systemd-native Dienste aus dem Nix Store.
Docker, Podman, OCI-Runtime und netns-Wrapper sind bewusst ausgeschlossen.

## Begründung
- Nix Store ist der Container-Ersatz: reproduzierbar, isoliert, rollback-fähig
- systemd-Hardening (ProtectSystem, PrivateTmp, IPAddressDeny) ersetzt Netzwerk-Isolation
- Kein Docker-Daemon = weniger Angriffsfläche, weniger RAM, weniger Komplexität
- Alle Dienste (Jellyfin, Sonarr, SABnzbd, etc.) sind nativ in nixpkgs

## Ausnahmen (Zukunft)
Falls ein Dienst nicht in nixpkgs verfügbar ist, wird zuerst geprüft:
1. Eigenes nixpkgs-Paket bauen (fetchFromGitHub + buildNpmPackage / buildDotnetPackage)
2. Nur als letzter Ausweg: OCI via systemd-nspawn (kein Docker!)

## Placeholder-Module
Für Dienste die theoretisch interessant sind aber Container brauchen würden:
- Maintainerr: wenn nixpkgs-Paket verfügbar → 576-maintainerr.nix aktivieren

## Bewusst NICHT enthalten (Usenet-Stack)
- **Autobrr** (`services.autobrr` existiert in nixpkgs): Torrent-Tracker-Rule-Bot.
  Usenet-Stack braucht keinen Torrent-Tracker-Bot — Prowlarr (536) macht bereits
  Indexer-Aggregation. Autobrr's Usenet-Support ist rudimentär, kein Ersatz für
  Prowlarr. → Nicht einbauen (ADR-0000 §5: systemd-native, Usenet-fokussiert).
