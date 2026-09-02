# 510 — Attach a service to Caddy, Pocket ID and the landing page

How-to for domain **51-ingress**. File id `510` sits in front of the organs 511–518.

511, 513, 515 and 518 do not know program names. Everything a service needs lives in **its own** module plus one `lib/registry.nix` entry.

Template: [`510-service.example.nix`](510-service.example.nix)

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

```nix
medinix.pocketId.enable = true;
medinix.pocketId.exposure = "idp";
medinix.ingress.auth.mode = "forward-auth";
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
