# 510 — Attach a service to Caddy, Pocket ID and the landing page

How-to for domain **51-ingress**. File id `510` is the service-attachment layer for the ingress modules in this domain.

511, 513, 515 and 518 do not know program names. Everything a service needs lives in **its own** module plus one `lib/registry.nix` entry.

Template: [`55x-service.example.nix`](55x-service.example.nix)

## The access path (who gets in)

`_1` owns the **whole** access path — the door *and* who gets through. The
concrete chain depends on `accessGroup`, the auth mode and the ownership model;
it is not a fixed pipeline.

```
WAN
  ↓
Caddy / 511
  ↓
optional forward_auth (512 / an explicit external auth gateway)
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
caddy · `512` pocket-id · `513` cloudflare-dns · `514` acme · `515` mdns · `518`
landingpage · `519` guardrails. **`516` and `517` are free** (planned: CrowdSec /
edge-firewall) and **not implemented**.

Domain guardrails: **`519`** — advisory assertions (no nginx/httpd/iptables/fail2ban;
Caddy + firewall stay on). Escape hatch: `medinix.ingress.guardrails`.

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

518 is only the renderer. `stream` or `public` on the service module is enough. Set `landing = false` to hide a WAN app from the icon page.

## Sprite

Repo file: `50-core/icons.svg` (copy of logorepo `dist/icons.svg`).
Caddy URL: `/icons.svg`

```html
<use href="/icons.svg#{service}"></use>
```

`{service}` is the vhost key. `logos/sonarr.svg` is the source drawing, not the sprite. Do not `<use>` a jsDelivr URL (CORS). Do not open the GitHub blob page as an image.

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
`forward_auth` needs an explicit auth gateway upstream (oauth2-proxy / tinyauth /
caddy-security); Pocket-ID itself is **not** a valid `forwardAuthUpstream`.

```nix
medinix.pocketId.enable = true;
medinix.pocketId.exposure = "idp";
medinix.ingress.auth.mode = "forward-auth";
medinix.ingress.auth.forwardAuthUpstream = "http://127.0.0.1:4180";
medinix.authProxyPresent = true;
```

511 puts the auth wall only on `public`. `stream` stays App-Login.

## Host setup (once)

```nix
medinix.enable = true;
medinix.domain = "example.tld";
medinix.ingress.enable = true;
medinix.ingress.tls.acmeHost = "example.tld";
medinix.ingress.tls.acmeCredential = "/path/to/cf.cred";
```

## Anti-pattern

Do not write `services.caddy.virtualHosts` by hand. Register a vhost; 511 renders it.
