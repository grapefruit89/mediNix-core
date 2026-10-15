# mediNix-core — Upstream-Quellen & Referenzen

Zentrales Verzeichnis aller Upstream-Repositories, Bibliotheken, Standards und Dokumentationen, die als architektonische Grundlage oder Inspiration für Module in mediNix dienen.

> [!TIP]
> **Eiserne Regel für Agenten:** Wenn Code, Logiken oder Architekturen aus externen Repositories, NixOS-Modulen oder Dokus übernommen oder adaptiert werden, muss die Quelle zwingend mit Upstream-URL und Zweck in diese Tabelle eingetragen werden.

---

## Quellennachweise & Inspirationen

| Funktion / Modul | Upstream-Repository / Quelle | Zweck / Genutzter Ansatz |
|---|---|---|
| **511 Ingress / Caddy** | [caddyserver/caddy](https://github.com/caddyserver/caddy) | Reverse Proxy, automatisches TLS, Unix Admin-Socket (`admin unix//run/caddy-media/admin.sock`), `request_header -<Header>` Stripping vor Forward-Auth, Access-Log-Formatierung. |
| **512 Pocket-ID** | [stonith404/pocket-id](https://github.com/stonith404/pocket-id) | Schlanker OIDC Identity Provider (SQLite + Go/Svelte), Passkey-first Authentifizierung im Heimnetzwerk. |
| **513 Cloudflare DDNS** | [cloudflare/api-schemas](https://github.com/cloudflare/api-schemas) | REST-API zur Aktualisierung von DNS-A-Records und Pruning von kanonischen FQDN-Subdomains. |
| **515 mDNS Aliases** | [avahi/avahi](https://github.com/avahi/avahi) | Lokale Multicast-DNS Veröffentlichung (`{service}.local -> LAN-IP`) für Zero-Config Erkennung im Subnetz. |
| **526 VPN Killswitch** | [WireGuard/wireguard-linux](https://git.zx2c4.com/wireguard-linux) & [netfilter/nftables](https://git.netfilter.org/nftables/) | Confinement via `meta skuid` und `type route hook output priority mangle` Markierung für fwmark-basiertes Policy Routing (ohne Network Namespaces). |
| **551 Jellyfin** | [jellyfin/jellyfin](https://github.com/jellyfin/jellyfin) | Systemd-natives Medien-Streaming, Transcoding, 5510 Dezimal-Port-Zuordnung. |
| **552 Audiobookshelf** | [advplyr/audiobookshelf](https://github.com/advplyr/audiobookshelf) | Hörbuch- und Podcast-Server mit geschütztem Setup-Flag und First-Run-Race-Absicherung (RT-2). |
| **553 Navidrome** | [navidrome/navidrome](https://github.com/navidrome/navidrome) | Schlanker Subsonic-kompatibler Musikserver; Admin-Pre-Seeding via `ND_DEVAUTOCREATEADMINPASSWORD`. |
| **561 Seerr** | [Fallenbagel/jellyseerr](https://github.com/Fallenbagel/jellyseerr) | Medien-Anfrageportal mit nativer Jellyfin-/Plex-Integration auf Port 5610. |
| **574 Servarr Provisioning** | [Sonarr/Sonarr](https://github.com/Sonarr/Sonarr), [Radarr/Radarr](https://github.com/Radarr/Radarr), [Prowlarr/Prowlarr](https://github.com/Prowlarr/Prowlarr) | Automatisches Setup von API-Keys, Root Folders, Download Clients und Qualitäts-Profilen. |
| **581 ntfy** | [binwiederhier/ntfy](https://github.com/binwiederhier/ntfy) | HTTP-basiertes Push-Benachrichtigungssystem für Statusmeldungen und Alerting. |
| **NixOS Tests / VM-Runner** | [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs) (`nixos/lib/testing/python.nix`) | Headless Python-basierte QEMU Test-Treiber für automatisierte Integrationstests (`testers.runNixOSTest`). |
| **CI Action** | [cachix/install-nix-action](https://github.com/cachix/install-nix-action) | Schnelle und deterministische Nix-Installation im GitHub Actions Runner. |
