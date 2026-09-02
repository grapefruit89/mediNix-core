---
id: 510-logos
title: logorepo sprite ↔ modules
---

Source: https://github.com/grapefruit89/logorepo
Sprite: https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/dist/icons.svg
Single file: https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/ID.svg

18 symbols. Filename = id. It is `pocket-id.svg`, not `pocket id.svg`.

| id | logo | module |
| --- | --- | --- |
| acme | [acme.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/acme.svg) | `514-acme.nix` |
| audiobookshelf | [audiobookshelf.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/audiobookshelf.svg) | `552-audiobookshelf.nix` |
| bitwarden | [bitwarden.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/bitwarden.svg) | not a mediNix service |
| caddy | [caddy.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/caddy.svg) | `511-caddy.nix` |
| cloudflare | [cloudflare.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/cloudflare.svg) | `513-cloudflare-dns.nix` |
| feishin | [feishin.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/feishin.svg) | `554-feishin.nix` |
| jellyfin | [jellyfin.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/jellyfin.svg) | `551-jellyfin.nix` |
| lidarr | [lidarr.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/lidarr.svg) | `535-lidarr.nix` |
| navidrome | [navidrome.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/navidrome.svg) | `553-navidrome.nix` |
| nixos | [nixos.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/nixos.svg) | flake |
| ntfy | [ntfy.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/ntfy.svg) | observability |
| pocket-id | [pocket-id.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/pocket-id.svg) | `512-pocket-id.nix` |
| prowlarr | [prowlarr.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/prowlarr.svg) | `536-prowlarr.nix` |
| radarr | [radarr.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/radarr.svg) | `533-radarr.nix` |
| recyclarr | [recyclarr.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/recyclarr.svg) | recyclarr |
| seerr | [seerr.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/seerr.svg) | `555-seerr.nix` |
| sonarr | [sonarr.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/sonarr.svg) | `532-sonarr.nix` |
| unraid | [unraid.svg](https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/unraid.svg) | host |

No `readarr.svg` yet. 534 has no tile icon.

## WAN vs not

Two faces, not five:

- **WAN** = `stream` (family apps, no Caddy SSO) + `public` (OIDC).
- **Not WAN** = `internal` / `none` (Arr, SAB).
- `idp` is only Pocket-ID so the browser can log in. Not a family tile.

`landing = true` draws a tile on the family page. It does not change exposure.
Internal services never get a tile.
