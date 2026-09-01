# mediNix-core

Portable NixOS module set for a mediNix media-stack host.
Systemd-native, flat, numbered by ADR-0000. No Docker, no hardcoded IPs.

A service describes itself. Ingress organs only consume that description.

## Architecture (decimal framework, ADR-0000)

**[Architecture manifesto (constitution v2.0)](50-core/MANIFEST.md)**

1. **Tri-state boundary.** mediNix does not take over the host (`mkForce` is banned). The host admin chooses `managed`, `external`, or `off`.
2. **Fail-closed.** No unsafe fallbacks (DNS leaks, silent auth, dead virtual hosts).
3. **Zero containers.** systemd only.
4. **Dendritic modules.** Drop a service file; do not edit the edge engine.

| Domain | Role | Modules |
| --- | --- | --- |
| `51-ingress` | Reverse proxy, TLS, DNS, mDNS, OIDC, landing page | 511-caddy, 512-pocket-id, 513-cloudflare-dns, 514-acme, 515-mdns, 518-landingpage |
| `52-security` | Core security, VPN | 520-core-security, 525-vpn-interface, 526-vpn-killswitch |
| `53-acquisition` | *arr indexers | 532-sonarr, 533-radarr, 534-readarr, 535-lidarr, 536-prowlarr |
| `54-transfer` | Usenet + WAL + mover | 541-sabnzbd, 542-sqlite-wal, 543-mover |
| `55-playback` | Playback | 551-jellyfin, 552-audiobookshelf, 553-navidrome, 554-feishin, 559-playback-tuning |
| `56-requests` | Requests | 561-seerr (`555-seerr.nix`) |
| `57-maintenance` | Optimize, sync, provision | 571-sqlite-optimize, 572-recyclarr, 573-exportarr, 574-provisioning |
| `58-observability` | Notifications | 581-ntfy |
| `59-guardrails` | Assertions | 591-cross-domain, 592-environment |

How to attach a new program to Caddy, Pocket ID and the family page: [`51-ingress/SERVICE.md`](51-ingress/SERVICE.md). Copy [`51-ingress/55x-service.example.nix`](51-ingress/55x-service.example.nix).

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
| Feishin | 554 | 5540 | 5540 | 5000 | stream | 127.0.0.1 |
| Seerr | 561 | 5610 | 5610 | 5000 | public | 127.0.0.1 |
| ntfy | 581 | 5810 | 5810 | 5000 | public | 127.0.0.1 |

**caddyClass / `accessGroup`**

- `stream` — media; no compression; `flush_interval -1`; no forward-auth
- `internal` — LAN only; abort outside `trustedCidrs`; no forward-auth
- `public` — WAN + LAN; compression; forward-auth when the host enables it
- `idp` — Pocket ID login UI; no forward-auth (deadlock shield)
- `none` — no Caddy vhost

`.local` names are always HTTP: no TLS, no auth, no WAN abort.

## How a service joins the edge

Enable it in **its own module**. Register one vhost. Do not edit 511/513/515/518.

```nix
lib.mkIf cfg.enable {
  # systemd unit binds 127.0.0.1:<registry.port>

  medinix.ingress.vhosts."seerr" = {
    accessGroup = "public";
    landing     = true;
    iconSvg     = ''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">…</svg>'';
  };
}
```

A landing-page tile exists only when `landing = true` and `iconSvg` is non-empty.
Pocket ID is host-wide, not per app:

```nix
medinix.pocketId.enable = true;
medinix.pocketId.exposure = "idp";
medinix.ingress.auth.mode = "forward-auth";
```

Secrets for DNS-01 / DDNS are systemd credentials (`LoadCredentialEncrypted`), not SOPS.

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
          medinix = {
            enable     = true;
            domain     = "example.com";
            ingress.tls.acmeHost = "example.com";
            ingress.tls.acmeCredential = "/path/to/cf.cred"; # KEY=value, CF_DNS_API_TOKEN=…
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

`514-acme.nix` issues a wildcard via NixOS ACME / Lego (Cloudflare DNS-01).
Caddy never talks to Let's Encrypt (`auto_https off`). 511 reads
`/var/lib/acme/{acmeHost}/fullchain.pem` and `key.pem`.
Reload target: `caddy.service` by default, `caddy-media.service` in standalone mode.

## Observability

ntfy (581) is the push target for Arr apps and Jellyfin.
Arr: *Settings → Connect → Ntfy*, server `http://127.0.0.1:5810`, topic from `observability.ntfy.topic`.

## Guardrails

Misconfig fails the build (`config.assertions`, ADR-0000 fail-closed):
forward-auth without an upstream, VPN without DNS, TLS conflicts, ACME/DDNS without a systemd credential.
Soft warnings: firewall off, stream without TLS, .NET EOL.

## Host-admin responsibilities

mediNix-core is portable. Binary cache, impermanence, tier hardware, SSH hardening
and TPM wrapping of credential files stay host decisions. Checklist after flake import: [`ADMIN-HANDOFF.md`](ADMIN-HANDOFF.md).

## Layout

- `default.nix` — `medinix.*` options; auto-imports modules via `readDir` + regex
- `lib/` — registry (ports/UIDs), service-factory, ABC tiering
- `51-ingress/` — edge organs + [`SERVICE.md`](51-ingress/SERVICE.md)
- `docs/` — ADRs, [`docs/INDEX.md`](docs/INDEX.md)
- `flake.nix` — `nixosModules.default` + CI check

## Status

**Active:** domains 51–59, ADRs 0000–5720.
**Draft ADRs:** 5115 (split-DNS note), 5710 (SQLite MCP), 5720 (backup strategy).
**Still open on the edge:** 515 name-set cleanup, 554-feishin still bypasses the 511 engine (static SPA), runtime matrix (`nix flake check`, `caddy validate`).

## License

MIT, see `LICENSE` if present.
