---
id: "ADR-517"
title: "Auth-Flow: OIDC wo möglich, Forward-Auth als Lücke, Jellyfin/Seerr ausgenommen"
domain: 51
status: active
complexity: 3
last_reviewed: 2026-10-17
tags:
  - ingress
  - auth
  - oidc
  - forward-auth
links:
  adr: ""
  repo-harvest: ""
---
# ADR-517: Auth-Flow — OIDC wo möglich, Forward-Auth als Lücke, Jellyfin/Seerr ausgenommen

## Status: active
## Date: 2026-10-17
## Source: `51-ingress/511-caddy.nix` (`forward_auth`), `51-ingress/512-pocket-id.nix` (OIDC-IdP), nixpkgs `services.oauth2-proxy`
## Related: ADR-512 (Pocket ID), ADR-521 (Secrets), ADR-0000 (Dezimalrahmen)

## Kontext
Pocket ID (512) ist ein **OIDC-Provider ohne forward-auth-Endpoint** (`511` erzwingt
das per Assertion). Für ein Login *vor* einer App braucht Caddy einen **Auth-Proxy**.
Zugleich haben nicht alle Dienste ein eigenes OIDC.

## Entscheidung

1. **Dienste MIT nativem OIDC → Pocket ID (app-nativ, kein Proxy):**
   Audiobookshelf (552), Navidrome (553). Sie bleiben `accessGroup = "stream"`
   (kein `forward_auth`); die App authentifiziert selbst gegen Pocket ID.
2. **Dienste OHNE OIDC → Caddy `forward_auth` → oauth2-proxy → Pocket ID:**
   Sonarr/Radarr/Readarr/Lidarr/Prowlarr (532–536), SABnzbd (541),
   ntfy (581), Gatus (582).
3. **Jellyfin (551) und Seerr (561) bleiben KOMPLETT aus dem Auth-Flow:**
   551 ist `stream` (kein `forward_auth`), 561 wird `public` **mit**
   `allowUnauthenticated = true` — beide haben einen eigenen Login.

## Proxy-Wahl: oauth2-proxy (tinyauth geblacklistet, caddy-security verworfen)

| Kriterium | oauth2-proxy 7.15.5 (MIT) | tinyauth 5.2.0 | caddy-security (Plugin) |
|---|---|---|---|
| Status | **gewaehlt** | **geblacklistet** (`50-core/BANNED_TECHNOLOGIES.md`: **kein Passkey-Support**) | verworfen |
| Extra-Daemon | 1 (nixpkgs-Modul `services.oauth2-proxy`) | 1 | 0 |
| Caddy-Umbau | **keiner** — `511` spricht `forward_auth` schon | keiner | **eigener Caddy-Build** (`pkgs.caddy.withPlugins` — in nixpkgs vorhanden, aber FOD + Hash-Pflege + Rebuild je Update) |
| Passkeys | ja (OIDC gegen Pocket ID) | **nein** | ja |
| Lizenz | MIT | AGPL-3.0 | — |
| Lizenzen | MIT | AGPL-3.0 | — |

**Entschieden: oauth2-proxy** — geringste bewegliche Teile am kritischsten Bauteil
(Ingress): ein kleiner Daemon aus nixpkgs, **kein** Caddy-Rebuild, `511` ist bereits
kompatibel (`authProxyPresent` + `forwardAuthUpstream` + `forwardAuthUri`).

## Konsequenzen / nötige Änderungen

- **Neu `51-ingress/517-oauth2-proxy.nix`** (loopback-only, `accessGroup = "none"`,
  Port/UID 5170 nach ADR-0000): `services.oauth2-proxy` mit `provider = "oidc"`,
  `oidcIssuerUrl` = Pocket-ID, Client-ID + **versiegelte** Secrets
  (`clientSecretFile`/`cookie.secretFile`, ADR-521), `setXauthrequest = true`.
- **`511` muss `/oauth2/*` auf jedem geschützten vhost an den Proxy routen** —
  sonst ist der Browser-Callback (`/oauth2/start`, `/oauth2/callback`) nicht
  erreichbar und `forward_auth` kann nie einloggen. Das ist der eigentliche
  fehlende Baustein.
- **Host-Config** aktiviert: `medinix.oauth2Proxy.enable = true`,
  `medinix.authProxyPresent = true`, `ingress.auth.forwardAuthUpstream` =
  `http://127.0.0.1:5170`, `forwardAuthUri = "/oauth2/auth"`.
- **561 Seerr:** `allowUnauthenticated = true` (public ohne Gate, eigener Login).
- **551 Jellyfin:** bleibt `stream` — nichts zu tun.
- **552/553:** OIDC-Client in Pocket ID registrieren; die App-Settings setzt der
  Host (bzw. eigene Optionen im jeweiligen Modul).

## Offen
- Callback-Hostname/Pfad: oauth2-proxy nutzt `proxyPrefix = "/oauth2"` **auf dem
  jeweiligen vhost** (kein eigener öffentlicher vhost nötig).
- Ob 552/553 eigene OIDC-Options bekommen oder der Host die App-Settings setzt.
