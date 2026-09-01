# 510 — Attach a service to Caddy, Pocket ID and the landing page

How-to for domain **51-ingress**. File id `510` sits in front of the organs 511–518. Domain 50 is core (options, factory), not this guide.

511, 513, 515 and 518 do not know program names. Everything a service needs lives in **its own** module plus one `lib/registry.nix` entry.

Template: [`510-service.example.nix`](510-service.example.nix)

## Checklist

1. Add the service to `lib/registry.nix` (`port`, `uid`, `stateDir`, `caddyClass`).
2. Copy a service module; add `enable` in the options module if it does not exist yet.
3. Inside `lib.mkIf cfg.enable`:
   - bind the process to `127.0.0.1:<port>`
   - set `medinix.ingress.vhosts."<name>"`
4. On the host: `medinix.<name>.enable = true;`
5. **Do not** edit 511, 513, 515 or 518.

## vHost fields

```nix
medinix.ingress.vhosts."seerr" = {
  accessGroup = "public";   # stream | internal | public | idp | none
  landing     = true;
  iconSvg     = ''<svg …></svg>'';
};
```

| Field | Effect |
| --- | --- |
| `accessGroup` | 511 template (see below) |
| `landing = true` and `iconSvg != ""` | tile on `https://{domain}` and `http://home.local` |
| otherwise | no tile, no fallback icon |
| `dns.hostnames.<name>` | public label; default is the registry key |

## accessGroup

| Group | HTTPS `{name}.{domain}` | Auth | `.local` |
| --- | --- | --- |
| `stream` | yes, no compression | never | HTTP, no auth, no abort |
| `internal` | yes, abort outside `trustedCidrs` | never | same |
| `public` | yes, compression | `forward_auth` when enabled host-wide | same |
| `idp` | yes, no abort | never (deadlock shield) | same |
| `none` | no vhost | — | no vhost |

`.local` never gets TLS, forward-auth or a WAN abort.

## Pocket ID — once per host, not per service

```nix
medinix.pocketId.enable = true;
medinix.pocketId.exposure = "idp";          # login UI at pocket-id.{domain}
medinix.ingress.auth.mode = "forward-auth";
# empty forwardAuthUpstream → 127.0.0.1:<pocket-id-port>
```

511 then puts the auth wall only on `accessGroup = "public"`. `stream`, `internal`, `idp` and `.local` stay open.

External proxy instead of Pocket ID:

```nix
medinix.ingress.auth.mode = "forward-auth";
medinix.ingress.authProxyPresent = true;
medinix.ingress.auth.forwardAuthUpstream = "127.0.0.1:4180";
# leave pocketId.enable = false
```

`skipPaths` (health checks without login) go on the vhost or under `ingress.auth.skipPaths`.

## Landing page

518 only reads vhosts. A tile exists exactly when the service module sets `landing = true` and an SVG — see `555-seerr.nix`.

```nix
medinix.ingress.landing.enable = true;   # default
```

No entry in 518, no icon map, no `preferred` list.

## Host setup (once)

```nix
medinix.enable = true;
medinix.domain = "example.tld";
medinix.ingress.enable = true;
medinix.ingress.tls.acmeHost = "example.tld";
medinix.ingress.tls.acmeCredential = "/path/to/cf.cred";  # systemd credential, KEY=value
```

DNS (513) and mDNS (515) take names from the same vhost set. A new program is a new vhost, not an edit to 513 or 515.

## Anti-pattern

Do not do this:

```nix
services.caddy.virtualHosts."foo.example.tld".extraConfig = "…";
```

That bypasses the engine (554-feishin still does). Register a vhost and let 511 render it. Feishin needs a later `static` template because it is not a `reverse_proxy`.
