---
id: "README"
title: "README"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - general
links:
  adr: ""
  repo-harvest: ""
---
# mediNix-core

Portables NixOS-Modul-Repository für eine mediNix Media-Stack-Infrastruktur.
Systemd-native, flach, dezimal-gerahmt (ADR-0000). Kein Docker, kein Chroma,
keine Hardcoded-IPs.

## Architektur (Dezimal Framework, ADR-0000)

| Domain | Zweck | Module |
|--------|-------|--------|
| `51-ingress` | Caddy Reverse Proxy + OIDC + DDNS | 511-caddy, 512-pocket-id, 513-cloudflare-dns |
| `52-security` | Firewall, Kernel, SSH, Credentials | 521-nftables, 522-kernel, 523-ssh, 524-systemd-credentials |
| `53-acquisition` | *arr Stack (Usenet Indexer/Downloader) | 532-sonarr, 533-radarr, 534-readarr, 535-lidarr, 536-prowlarr |
| `54-transfer` | Usenet Downloader + WAL + Mover | 541-sabnzbd, 542-sqlite-wal, 543-mover |
| `55-playback` | Media Playback (stream) | 551-jellyfin, 552-audiobookshelf, 553-navidrome, 554-feishin, 559-playback-tuning |
| `56-requests` | Request Management | 561-jellyseerr |
| `57-maintenance` | Optimierung, Sync, Provisioning | 571-sqlite-optimize, 572-recyclarr, 573-exportarr, 574-provisioning |
| `58-observability` | Notifications | 581-ntfy |
| `59-guardrails` | Assertions, SSH, Backup | 591-assertions, 592-rollout, 593-no-password-auth, 593-emergency-user, 594-backup-ssh, 596-security-assertions |

## Service Map

| Dienst | Num | Port | UID | GID | caddyClass | Bind |
|--------|-----|------|-----|-----|------------|------|
| Caddy | 511 | 5110 | 5110 | 5000 | stream | 127.0.0.1 |
| Pocket-ID | 512 | 5120 | 5120 | 5000 | public | 127.0.0.1 |
| Cloudflare-DNS | 513 | – | – | 5000 | none | – |
| Sonarr | 532 | 5320 | 5320 | 5000 | internal | 127.0.0.1 |
| Radarr | 533 | 5330 | 5330 | 5000 | internal | 127.0.0.1 |
| Readarr | 534 | 5340 | 5340 | 5000 | internal | 127.0.0.1 |
| Lidarr | 535 | 5350 | 5350 | 5000 | internal | 127.0.0.1 |
| Prowlarr | 536 | 5360 | 5360 | 5000 | internal | 127.0.0.1 |
| SABnzbd | 541 | 5410 | 5410 | 5000 | internal | 127.0.0.1 |
| Jellyfin | 551 | 5510 | 5510 | 5000 | stream | 127.0.0.1 |
| Audiobookshelf | 552 | 5520 | 5520 | 5000 | stream | 127.0.0.1 |
| Navidrome | 553 | 5530 | 5530 | 5000 | stream | 127.0.0.1 |
| Feishin | 554 | 5540 | 5540 | 5000 | stream | 127.0.0.1 |
| Jellyseerr | 561 | 5610 | 5610 | 5000 | public | 127.0.0.1 |
| ntfy | 581 | 5810 | 5810 | 5000 | public | 127.0.0.1 |

**caddyClass:**
- `stream` → WAN, kein Proxy, `flush_interval -1`, keine Kompression (Jellyfin/ABS/Navidrome/Feishin/Caddy)
- `internal` → LAN only, externe IPs geblockt (Sonarr/Radarr/Readarr/Lidarr/Prowlarr/SABnzbd)
- `public` → LAN + WAN, Kompression (Pocket-ID/Jellyseerr/ntfy)
- `none` → kein Caddy vHost (Cloudflare-DNS)

## Quickstart

```nix
# flake.nix
{
  inputs.mediNix-core.url = "github:grapefruit89/mediNix-core";

  outputs = { nixpkgs, mediNix-core, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        mediNix-core.nixosModules.default
        {
          grapefruitMedia = {
            enable     = true;
            domain     = "m7c5.de";
            ingress.tls.acmeHost = "m7c5.de";  # liest /var/lib/acme/m7c5.de/ (Host: security.acme)
            jellyfin.enable        = true;
            audiobookshelf.enable  = true;
            navidrome.enable       = true;
            sonarr.enable          = true;
            radarr.enable          = true;
            prowlarr.enable        = true;
            sabnzbd.enable         = true;
            storage.mediaRoot      = "/data/media";
            storage.metadataDir    = "/data/cache";
          };
        }
      ];
    };
  };
}
```

## TLS

`ingress.tls.acmeHost` leitet automatisch `/var/lib/acme/{acmeHost}/cert.pem` +
`key.pem` ab. **`security.acme` (Lego, DNS-01 via Cloudflare) wird vom Host
konfiguriert**, nicht von mediNix-core. Caddy liest nur das fertige Zertifikat.

## Observability

ntfy (581) als Push-Notifications für alle Arr-Apps + Jellyfin.
Arr-Apps: *Settings → Connect → Ntfy*, Server `http://127.0.0.1:5810`, Topic aus `observability.ntfy.topic`.

## Guardrails

Alle kritischen Fehlkonfigurationen brechen den Build (`config.assertions`, ADR-0000 fail-closed):
forward-auth ohne Proxy, VPN ohne DNS, TLS-Konflikte, DDNS ohne Token.
Soft-Warnings: firewall aus, stream ohne TLS, .NET-EOL.

## Verzeichnis

- `default.nix` — Options-API (`grapefruitMedia.*`), auto-import aller Module via `readDir`+regex
- `lib/` — registry (SSoT Ports/UID), service-factory (mkService), abc-tiering
- `docs/` — ADRs (Architecture Decision Records), INDEX.md
- `flake.nix` — `nixosModules.default` Export + CI-check Target

## Status

**Fertig (active):** alle Domain-Module 51–59, ADRs 0000–5720.
**Draft (status: draft in ADRs):** 5115 (Split-DNS note), 5710 (SQLite MCP Server), 5720 (Backup-Strategy).
**Phase 2 vorgemerkt:** 574-provisioning Ntfy-Automation, 573-exportarr Grafana-Dashboards, 592-rollout Staged-Deploy.

## License

siehe `LICENSE` (MIT, sofern vorhanden).
