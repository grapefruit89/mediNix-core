---
id: "GUIDE-52-identity-passkeys"
title: "GUIDE 5200 identity passkeys"
domain: 52
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - passkeys
  - security
links:
  adr: ""
  repo-harvest: ""
---
# 🔐 Sovereign Identity: Der Passkey Standard

In mynixos folgen wir dem Zero-Trust Prinzip. Identität wird nicht durch unsichere Passwörter, sondern durch kryptografische Passkeys (WebAuthn) nachgewiesen.

## 🚀 Warum PocketID?
- **Passwordless:** Keine Datenbank mit Passwörtern, die gestohlen werden kann.
- **OIDC Provider:** Standardisierte Anbindung für alle Dienste (Caddy mTLS, Web-Apps).
- **Self-Hosted:** Du behältst die volle Kontrolle über deine Identitätsdaten.

## 🧩 Architektur-Integration (Layer 40)
PocketID wird als zentraler Dienst in `modules/services/identity.nix` definiert (Arion-basiert).

## 🛡️ SRE-Hardening
- Der Zugriff auf das PocketID-Backend wird zusätzlich durch den **Cloudflare Tunnel** (mTLS) gesichert.
- Secrets für OIDC-Clients werden via `sops-nix` verwaltet.
