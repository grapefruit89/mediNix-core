---
id: "GUIDE-52-identity-passkeys"
title: "GUIDE 52 — Identity: Pocket ID (Passkeys & OIDC)"
domain: 52
status: active
complexity: 2
last_reviewed: 2026-10-17
tags:
  - passkeys
  - security
links:
  adr: ""
  repo-harvest: ""
---
# 🔐 Identity: Pocket ID (Passkeys & OIDC)

Passwordless-Zugang über Passkeys (WebAuthn); zentraler IdP ist **Pocket ID**.
Modul: `51-ingress/512-pocket-id.nix` (nicht `modules/services/identity.nix`,
**nicht** Arion-basiert).

## 🚀 Eigenschaften
- **OIDC-Provider** — ausschließlich IdP, kein eingebauter Auth-Proxy.
- **Exposure:** `medinix.pocketId.exposure = "idp"` → WAN-Login erreichbar, **kein**
  `forward_auth` (Access-Matrix-Zeile `idp`).
- **Bootstrap-Sperre (RT-2):** Pocket-ID öffnet `/setup`, **bis der erste Account
  existiert** — der erste Besucher wird der Admin (upstream Issue #1275). Deshalb
  verlangt `exposure = "idp"` die Ack `medinix.pocketId.setupCompleted = true`.
  Erststart: `exposure = "internal"` → Admin + Passkey anlegen →
  `setupCompleted = true` → `exposure = "idp"`. Gleiche Sperre wie 552/553.
- **Bootstrap-Sperre (RT-2):** Pocket-ID öffnet `/setup`, **bis der erste Account
  existiert** — der erste Besucher wird der Admin (upstream Issue #1275). Deshalb
  verlangt `exposure = "idp"` die Ack `medinix.pocketId.setupCompleted = true`.
  Erststart: `exposure = "internal"` → Admin + Passkey anlegen →
  `setupCompleted = true` → `exposure = "idp"`. Gleiche Sperre wie 552/553.
- **forward_auth** braucht ein separates Auth-Gateway (`authProxyPresent` +
  `ingress.auth.forwardAuthUpstream`). Pocket ID selbst ist **kein** gültiger
  `forwardAuthUpstream` (F5).
- **Ownership:** genau **ein** Besitzer pro `users.users.<n>` (Engine, nicht Modul).
- **TLS:** über `514-acme` + Caddy — **kein** Cloudflare-Tunnel.

## 🧩 Anbindung reviewen
`512` bindet an die Engine: Identity ist ein Dienst im Dezimalrahmen (`512`,
UID/Port 5120), kein Sonderpfad.

Quellen: `51-ingress/512-pocket-id.nix`, `51-ingress/510-ingress-SERVICE.md`,
`docs/ingress-security-matrix.md` (F5), `52-security/README.md`.
