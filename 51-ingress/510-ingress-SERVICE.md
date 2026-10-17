# 510 — Attach a service to Caddy, Pocket ID and the landing page

How-to for domain **51-ingress**. File id `510` is the service-attachment layer for the ingress modules in this domain.

511, 513, 515 and 518 do not know program names. Everything a service needs lives in **its own** module plus one `lib/registry.nix` entry.

Template: [`5xx-service.example.nix`](../docs/examples/5xx-service.example.nix)

## The access path (who gets in)

`_1` owns the **whole** access path — the door *and* who gets through. The
concrete chain depends on `accessGroup`, the auth mode and the ownership model;
it is not a fixed pipeline.

```
WAN
  ↓
Caddy / 511
  ↓
forward_auth — only `public`  →  oauth2-proxy (517)  →  Pocket ID (512)
  ↓
service
```

DNS, TLS/ACME, mDNS and the landing page are **separate ingress concerns**, not
steps in the request chain:

```
DNS (513) · TLS/ACME (514) · mDNS (515) · landing (518)
```

**Numbering rule:** the number is the service's **identity** (port/UID = num × 10),
**not** its position in a chain. The numbers stay stable. Current slots: `511`
caddy · `512` pocket-id · `513` cloudflare-dns · `514` acme · `515` mdns · `516`
crowdsec · **`517` oauth2-proxy (forward-auth, ADR-517)** · `518` landingpage ·
`519` guardrails. Port/UID of 517 = **5170** (num × 10).

Domain guardrails: **`519`** — advisory assertions (no nginx/httpd/iptables; Caddy +
firewall stay on; fail2ban is now Legacy — RT-3 aufgelöst, CrowdSec 516 ist der
Edge-Bouncer). Escape hatch: `medinix.ingress.guardrails`.
## Checklist

1. Add the service to `lib/registry.nix` (`port`, `uid`, `stateDir`, `caddyClass`).
2. Copy a service module; add `enable` in the options module if it does not exist yet.
3. Inside `lib.mkIf cfg.enable`:
   - bind the process to `127.0.0.1:<port>`
   - set `medinix.ingress.vhosts."<name>".accessGroup`
4. On the host: `medinix.<name>.enable = true;`
5. **Do not** edit 511, 513, 515 or 518.

## vHost — that is the whole contract

```nix
medinix.ingress.vhosts."seerr" = {
  accessGroup = "public";   # stream | public | internal | idp | none
};
```

| `accessGroup` | Internet | Family tile |
| --- | --- | --- |
| `stream` | WAN, no Caddy SSO, fat media | yes |
| `public` | WAN, forward_auth when on | yes |
| `idp` | WAN login (Pocket-ID only) | no |
| `internal` / `none` | not WAN | no |

518 is only the renderer. `stream` or `public` on the service module is enough.
Per-vhost overrides that 518 actually reads: `ingress.vhosts."<name>".landing = false`
hides the tile, `.iconId = "<id>"` picks a sprite id, `.iconSvg = "<svg…>"` inlines
one. Without an override the manifest decides (`ui.showOnLanding`, default `true`).

### Per-vhost overrides — the rest of the contract

Declared in `default.nix` (`ingress.vhosts.<name>.*`), read where noted. Every
field is optional; an unset field lets the service manifest decide.

| Field | Type | Effect | Read by |
| --- | --- | --- | --- |
| `accessGroup` | enum (`stream`/`public`/`idp`/`internal`/`none`) | the class above; `idp` is reserved for the IdP, `stream` needs the manifest's own declaration or `ingress.streamAck` | 511, 513, 515, 518 via `lib/ingress-access.nix` |
| `landing` | bool or `null` | `false` hides the tile for this host | 518 |
| `iconId` | str | sprite id, beats `manifest.<name>.ui.icon` and the service name | 518 |
| `iconSvg` | lines | inline SVG instead of the sprite (trusted operator input, not escaped) | 518 |
| `allowUnauthenticated` | bool or `null` | acknowledges a `public` vhost that gets no `forward_auth` | 511 (assertion) |
| `unauthenticatedPaths` | list of paths | auth bypass paths; a `public` vhost with any entry is a build error | 511 |
| `customConfig` | lines | raw Caddy directives appended to the site — the owner escape hatch | 511 |

## Sprite

Repo file: `50-core/icons.svg` (copy of logorepo `dist/icons.svg`).
Caddy URL: `/icons.svg`

```html
<use href="/icons.svg#{service}"></use>
```

The sprite id resolves as **`ingress.vhosts."<name>".iconId` → `manifest.<name>.ui.icon` → the vhost key** (in that order). `logos/sonarr.svg` is the source drawing, not the sprite. Do not `<use>` a jsDelivr URL (CORS). Do not open the GitHub blob page as an image.

## accessGroup detail

| Group | HTTPS `{name}.{domain}` | Auth | `.local` |
| --- | --- | --- |
| `stream` | yes, no compression | never | HTTP + CIDR abort |
| `internal` | yes, abort outside `trustedCidrs` | never | same abort |
| `public` | yes | `forward_auth` when enabled | CIDR abort |
| `idp` | yes, no abort | never | CIDR abort |
| `none` | no vhost | — | no vhost |

## Pocket ID — once per host

Pocket-ID is an **OIDC identity provider**, not the forward-auth endpoint.
`forward_auth` needs an explicit auth gateway upstream (oauth2-proxy,
ADR-517); Pocket-ID itself is **not** a valid `forwardAuthUpstream`.

```nix
medinix.pocketId.enable = true;
medinix.pocketId.exposure = "idp";
medinix.pocketId.setupCompleted = true;   # RT-2, siehe unten — Pflicht bei "idp"
medinix.ingress.auth.mode = "forward-auth";
medinix.ingress.auth.forwardAuthUpstream = "http://127.0.0.1:5170";  # 517, num × 10
medinix.authProxyPresent = true;
```

**Bootstrap-Reihenfolge (RT-2):** Pocket-ID öffnet `/setup`, **bis der erste
Account existiert** — der erste Besucher wird dabei der Admin. `exposure = "idp"`
ist deshalb erst nach der Ack `setupCompleted = true` erlaubt:

```
1. exposure = "internal"     # LAN-only, CIDR-Abort
2. {name}.{domain}/setup     # Admin + Passkey anlegen
3. setupCompleted = true
4. exposure = "idp"
```

- `forwardAuthUpstream` must be the **auth gateway** (517, oauth2-proxy), **not**
  Pocket ID. `forwardAuthUri` defaults to `/oauth2/auth`.
- **Bootstrap order (RT-2):** Pocket-ID serves `/setup` **until the first account
  exists** — and the first visitor becomes the admin. So `exposure = "idp"`
  requires the ack `setupCompleted = true`:
  `exposure = "internal"` → create admin + passkey at `{name}.{domain}/setup` →
  `setupCompleted = true` → `exposure = "idp"`.
- `medinix.authProxyPresent = true` is the **ack** that this upstream really
  exists. Without it, 511 refuses to build as soon as `auth.mode = "forward-auth"`
  is set — fail-closed instead of silently unauthenticated.

511 puts the auth wall only on `public`. `stream` stays App-Login.

## Host setup (once)

```nix
medinix.enable = true;
medinix.domain = "example.tld";
medinix.ingress.enable = true;
# MANDATORY as soon as any vhost or the landing page is on — 511 aborts
# otherwise ("no implicit trust of RFC1918/CGNAT"). Put your real LAN nets here.
medinix.ingress.trustedCidrs = [ "192.168.2.0/24" "10.0.0.0/8" ];
medinix.ingress.tls.acmeHost = "example.tld";
medinix.ingress.tls.acmeCredential = "/path/to/cf.cred";
```

`tls.mode` has three states: ACME via `tls.acmeHost` (the usual path), `"internal"`
(self-signed, LAN-only) and `"custom"` (your own cert paths). `"off"` (default)
serves WAN vhosts over **plain HTTP** — only for LAN-only/testing hosts.

## What makes the build fail (fail-closed)

511 refuses to render a half-secured ingress. A new service hits these **first** —
in this order:

| Assertion (511) | Trigger | Fix |
| --- | --- | --- |
| `trustedCidrs is empty but vhosts/landing are enabled` | no `ingress.trustedCidrs` | set your real LAN CIDR(s) |
| `public vhost(s) without authentication` | `accessGroup = "public"` while `auth.mode != "forward-auth"` | set `auth.mode = "forward-auth"`, or acknowledge with `allowUnauthenticated = true` |
| `public vhost(s) with unauthenticatedPaths (auth bypass)` | a path allowlist on a `public` vhost | drop the paths, use `accessGroup = "stream"`, or `allowUnauthenticated = true` |
| `declared but unresolvable` | `ingress.vhosts."foo"` without `medinix.foo.enable` | enable the service or drop the vhost entry |
| `trustedCidrs enthält Nicht-Private-Netze oder /0` | a public CIDR | private ranges only |
| `acmeCredential == dns.ddns.cloudflareTokenCredential` | one token for ACME **and** DDNS | issue two separate tokens (ADR-514/R11) |

`unauthenticatedPaths` is deliberately an **authentication bypass** list; it is
forbidden on `public` unless you also set `allowUnauthenticated = true`. The ack
is the point — a path allowlist alone is never enough.

## Anti-pattern

Do not write `services.caddy.virtualHosts` by hand. Register a vhost; 511 renders it.

## Edge-Bouncer (516)

`516` ist kein Caddy-Service: kein Port, kein vHost (`caddyClass = "none"`). Die
Engine liest die Access-Logs von `caddy-media` aus dem Journal und erzeugt
Ban-Entscheidungen; der Firewall-Bouncer setzt sie in nftables um — nur wenn
`medinix.hostIntegration.nftables = "managed"` (ADR-516-crowdsec,
`docs/ADMIN-HANDOFF.md`). `fail2ban` ist damit Legacy (519, RT-3 aufgelöst):
genau **ein** Edge-Bouncer.

## Verify

After `nixos-rebuild switch`:

```bash
systemctl status caddy-media          # or caddy.service in global mode
curl -sI https://seerr.example.tld | head -1     # 200/302, not connection refused
curl -sI https://seerr.example.tld | grep -i 'strict-transport-security'   # TLS on
dig +short seerr.example.tld          # wildcard *.{zone} -> wan.{zone} (513)
```

Without TLS (`tls.mode = "off"`) the vhost answers on `http://` only.
