---
id: 51-ingress
title: Ingress & Edge Domain
description: Manages reverse proxies, DNS, certificates, and authentication.
aliases: [Ingress, Edge, Caddy]
tags: [architecture, medinix, ingress, caddy, dns, acme, oidc]
last_reviewed: 2026-09-01
---

# 51-ingress: Ingress & Edge Domain

The **Ingress Domain** is the front door of mediNix-core: routing, TLS termination, DNS anchors, mDNS, and OIDC. It does **not** own individual applications.

The rule that everything else hangs from:

> **A service describes itself. Ingress organs only consume that description.**

No program names belong in 511, 513, 515, or 518. Seerr knowledge lives in `555-seerr.nix`. Jellyfin knowledge lives in `551-jellyfin.nix`. A new service is a new module plus a vhost registration — never an edit to the landing page, the DNS pruner, or the Caddy engine.

## How a service joins the edge

Enable the service in **its own module**. Then register one vhost. That is the whole ingress contract.

```nix
# 555-seerr.nix — the service owns metadata, 51-ingress does not
lib.mkIf cfg.enable {
  # … systemd, users, package …

  medinix.ingress.vhosts."seerr" = {
    accessGroup = reg.caddyClass;   # stream | internal | public | idp | none
    landing     = true;             # appear on the family page
    iconSvg     = ''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">
        …
      </svg>
    '';
  };
}
```

| Field | Who sets it | Who reads it |
| --- | --- | ---
| `cfg.enable` | service module | systemd unit in that same file |
| `ingress.vhosts.<name>` | service module | 511, 513, 515, 518 |
| `accessGroup` | service module | 511 templates |
| `landing = true` | service module | 518 (tile or not) |
| `iconSvg` | service module | 518 (rendered as-is) |
| `dns.hostnames.<name>` | host / DNS options | 511 + 518 public URL, 513 prune alias |

If `landing` is missing or `iconSvg` is empty, 518 skips the name. There is no fallback glyph and no central icon map.

Optional public alias, still generic:

```nix
medinix.dns.hostnames.seerr = "seerr";   # https://seerr.{domain}
```

518 / 511 resolve `cfg.dns.hostnames.${name} or name`. They do not special-case `seer` vs `seerr`.

## SVGs today, sprites later

**Today:** each service inlines its SVG on the vhost. 518 prefixes internal SVG ids (`id="a"` → `id="seerr-a"`) so several tiles can share one HTML page without gradient collisions. That is rendering hygiene, not program logic.

**Later (sprite):** keep the same contract. A service can switch `iconSvg` to a fragment that references a sprite sheet:

```html
<svg viewBox="0 0 96 96"><use href="/icons.svg#seerr"/></svg>
```

or 518 can learn a single extra field such as `iconId` and emit `<use href="…#id">`. The landing page still must not grow a map from program name → icon. The sprite is a packaging change, not a new inventory.

Do not put the sprite *inside* 518 as `icons.jellyfin = …`. That would recreate the list this domain just deleted.

## Organs stay small and generic

```
Service module
    │  enable + vhost + accessGroup + landing + iconSvg
    ▼
medinix.ingress.vhosts          ← single declarative registry
    │
    ├─ 511  Caddy engine        routes, TLS, policy
    ├─ 512  Pocket ID           IdP process only
    ├─ 513  Cloudflare DNS      four anchors + prune vhost names
    ├─ 514  ACME / Lego         wildcard files for 511
    ├─ 515  Avahi / mDNS        {name}.local + home.local
    └─ 518  Landing HTML        tiles from landing+iconSvg
```

| Module | Allowed to know | Forbidden |
| --- | --- | ---
| **511** | vhosts, accessGroup, domain, TLS files, auth mode | program names, icons, DNS writes, Avahi policy |
| **512** | Pocket ID process + `vhosts."pocket-id"` | Caddyfile, ACME, DNS |
| **513** | `attrNames vhosts` + `dns.hostnames` values | `feishin`, `jellyfin`, any second inventory |
| **514** | `acmeHost`, Cloudflare token | Caddy ACME, HTTP-01 |
| **515** | vhost names + `home` when landing is on | Caddy, TLS, HTML |
| **518** | `landing`, `iconSvg`, public host | preferred lists, icon maps, `/go/*`, JS, Caddy |

Chameleon (511 only):

- `auto` — read `services.caddy.enable`. Never attach to a random Caddy process.
- `global` — inject `virtualHosts` into the NixOS-managed `services.caddy`.
- `standalone` — run hardened `caddy-media` from one generated Caddyfile.

Global and standalone share one `allSites` list.

## Addresses

```
https://{name}.{domain}     Lego wildcard (514), policy from accessGroup
http://{name}.{domain}      301 → HTTPS when TLS is on
http://{name}.local         HTTP only; no TLS, no auth, no WAN abort
https://{domain}            landing (LAN abort)
http://home.local           same HTML, HTTP
```

Cloudflare stays grey (`proxied = false`). 513 keeps four records (`wan`, `lan`, `*`, apex) and deletes leftover per-service A/AAAA/CNAME for names that appear in `ingress.vhosts`. Access control is Caddy `trustedCidrs`, not Cloudflare.

## Dezimalrahmen

| ID | File | Role |
| --- | --- | --- |
| **511** | `511-caddy.nix` · ADR-5110 | Chameleon Caddy. Stock package, `auto_https off`. |
| **512** | `512-pocket-id.nix` · ADR-5120 | OIDC on `127.0.0.1:5120`. Enable is explicit. Exposure via `pocketId.exposure` / `vhosts."pocket-id".accessGroup`. |
| **513** | `513-cloudflare-dns.nix` · ADR-5130 | Anchor DDNS. Dumb prune of vhost names. |
| **514** | `514-acme.nix` · ADR-5140 | Wildcard DNS-01. Group `caddy`, not `media`. Reload target overlaid by 511. |
| **515** | `515-mdns.nix` · ADR-5150 | Sole Avahi owner. IPv4-first LAN publish. |
| **518** | `518-landingpage.nix` · ADR-5180 | `ingress.landing.root` only. 511 serves it. |

## What is closed vs still open

Closed in this wave:

- 511 P0 (`dns.hostnames ? n`), forward-auth contract, hostname collision assertion, Avahi removed from 511
- 512 explicit enable + declared IdP exposure
- 513 prune from vhosts/aliases only — no hardcoded service names
- 518 generic renderer — no `preferred`, no icon map, no fallback art
- Service-owned SVGs (see `555-seerr.nix`)

Still open (master plan steps 4–7):

- 514: document plain-token as opt-in fallback; keep reload overlay as the contract with 511
- 515: name set from the same vhost registry (drop any leftover second inventory); Avahi ownership already belongs here
- Runtime matrix: `nix flake check`, `caddy validate`, global/standalone × TLS × auth
- `554-feishin.nix` still bypasses the 511 engine — register a vhost there if DNS prune / landing should see it
- Sprite sheet for icons — later, without putting names back into 518

The master plan is **not obsolete**. It is the ownership map. The implementation has absorbed 511–513 and 518; 514/515/acceptance are the remaining checklist, not a redesign.
