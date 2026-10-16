---
id: "GUIDE-51-ingress-deep-dive"
title: "GUIDE 51 — Ingress Deep-Dive: Caddy + Pocket ID + forward_auth"
domain: 51
status: active
complexity: 2
last_reviewed: 2026-10-17
tags:
  - ingress
links:
  adr: ""
  repo-harvest: ""
---
# 🛡️ Ingress Deep-Dive: der Zugangspfad

Der Pfad ist kein starres Pipeline-Objekt, sondern hängt vom `accessGroup` ab:

```
WAN → Caddy (511) → optional forward_auth (512 / externes Auth-Gateway) → Dienst
```

> **Pocket ID ist ein OIDC-IdP, nicht der forward_auth-Endpoint.** `forward_auth`
> braucht ein Upstream wie `oauth2-proxy` / `tinyauth` / `caddy-security`
> (`authProxyPresent = true` + `ingress.auth.forwardAuthUpstream`).

## 🧩 accessGroup (Zugriffs-Vertrag)
| Gruppe | HTTPS `{name}.{domain}` | Auth | `.lan` |
|---|---|---|---|
| `stream` | ja | nie (App-Login) | HTTP + CIDR-Abort |
| `internal` | ja | Abort außerhalb `trustedCidrs` | Abort |
| `public` | ja | `forward_auth` (wenn an) | CIDR-Abort |
| `idp` | ja | WAN-Login (nur Pocket ID) | CIDR-Abort |
| `none` | kein vHost | — | kein vHost |

## 🛡️ Wichtig
- `.lan` ist **keine** Trust-Boundary — nur CIDR-gegated (`lanAbort`).
- Ein `public`-vHost ohne Auth bricht den **Build**, außer
  `auth.mode = "forward-auth"` oder `allowUnauthenticated = true`.
- Auth-Header werden gestrippt (`request_header` **vor** `forward_auth`), damit ein
  LAN-Client keinen `Remote-User`-Header spoofen kann.

## ⚠️ Anti-Pattern
`services.caddy.virtualHosts` von Hand schreiben — registriere einen vHost, 511
rendert ihn.

Quellen: `51-ingress/510-ingress-SERVICE.md`, `docs/ingress-security-matrix.md`
(R3, F5, Laufzeit-Matrix), `51-ingress/511-caddy.nix`.
