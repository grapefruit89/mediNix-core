# mediNix-core

Portable NixOS module set for a mediNix media-stack host.
Systemd-native, flat, numbered by ADR-0000. No Docker, no hardcoded deployment IPs.

A service describes itself. Ingress organs only consume that description.

## Architecture (decimal framework, ADR-0000)

**[Architecture manifesto (constitution v2.0)](50-core/MANIFEST.md)**

1. **Tri-state boundary.** mediNix does not take over the host (`mkForce` is banned). The host admin chooses `managed`, `external`, or `off`.
2. **Fail-closed.** No unsafe fallbacks (DNS leaks, silent auth, dead virtual hosts).
3. **Zero containers.** systemd only.
4. **Dendritic modules.** Drop a service file; do not edit the edge engine.

| Domain | Role | Modules |
| --- | --- | --- |
| `51-ingress` | Reverse proxy, TLS, DNS, mDNS, OIDC, landing page | 510 how-to, 511-caddy, 512-pocket-id, 513-cloudflare-dns, 514-acme, 515-mdns, 518-landingpage |
| `52-security` | Core security, Credentials, VPN | 520-core-security, 521-creds, 525-vpn-interface, 526-vpn-killswitch |
| `53-acquisition` | *arr indexers | 532-sonarr, 533-radarr, 534-readarr, 535-lidarr, 536-prowlarr |
| `54-transfer` | Usenet + mover | 541-sabnzbd, 543-mover |
| `55-playback` | Playback & Requests | 551-jellyfin, 552-audiobookshelf, 553-navidrome, 554-feishin, 555-seerr |
| `57-maintenance` | Storage, Optimize, sync, backup, provision | 570-storage, 571-sqlite-wal, 572-recyclarr, 573-exportarr, 574-provisioning, 575-update-notifier, 576-backup, 577-drift-detection, 578-orphan-cleanup, 579-backup-ssh |
| `58-observability` | Notifications & Watchdogs | 581-ntfy, 583-runtime-guard, 584-post-boot-watchdog |
| `59-guardrails` | Assertions | 591-cross-domain |

How to attach a new program: [`51-ingress/510-ingress-SERVICE.md`](51-ingress/510-ingress-SERVICE.md).

## Service map

| Service | Num | Port | UID | GID | caddyClass | Bind |
| --- | --- | --- | --- | --- | --- | --- |
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
| Feishin | 554 | – | – | 5000 | stream | – (static SPA) |
| Seerr | 561 | 5610 | 5610 | 5000 | public | 127.0.0.1 |
| ntfy | 581 | 5810 | 5810 | 5000 | public | 127.0.0.1 |

**caddyClass / `accessGroup`:** `stream` (media, no auth), `internal` (LAN abort), `public` (forward-auth when on), `idp` (Pocket ID UI), `none` (no vhost). `.local` is always HTTP.

## Quickstart

```nix
{
  inputs.mediNix-core.url = "github:grapefruit89/mediNix-core";

  outputs = { nixpkgs, mediNix-core, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        mediNix-core.nixosModules.default
        {
          medinix = {
            enable     = true;
            domain     = "example.com";
            ingress.tls.acmeHost = "example.com";
            ingress.tls.acmeCredential = "/path/to/cf.cred";
            jellyfin.enable       = true;
            storage.mediaRoot     = "/data/media";
            storage.metadataDir   = "/data/cache";
          };
        }
      ];
    };
  };
}
```

## TLS

`514-acme.nix` issues a wildcard via NixOS ACME / Lego (Cloudflare DNS-01).
Caddy never talks to Let's Encrypt (`auto_https off`). 511 reads
`/var/lib/acme/{acmeHost}/fullchain.pem` and `key.pem`.

## Guardrails

Misconfig fails the build (`config.assertions`, ADR-0000 fail-closed).
Host decisions after import: [`ADMIN-HANDOFF.md`](ADMIN-HANDOFF.md).

## Layout

- `default.nix` — `medinix.*` options
- `lib/` — registry, service-factory
- `51-ingress/` — organs + [`510-ingress-SERVICE.md`](51-ingress/510-ingress-SERVICE.md)
- `docs/` — ADRs, [`docs/INDEX.md`](docs/INDEX.md)
- `flake.nix` — `nixosModules.default`

## License

MIT, see `LICENSE` if present.
