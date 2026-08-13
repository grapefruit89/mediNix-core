---
id: "GUIDE-51-tailnet-zero-trust"
title: "GUIDE 5100 tailnet zero trust"
domain: 51
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - ingress
links:
  adr: ""
  repo-harvest: ""
---
# 🌐 Tailnet Zero-Trust: Sicherer Zugang ohne Port-Forwards

In mynixos ist Tailscale das Rückgrat deines Netzwerks. Wir folgen dem Zero-Trust Prinzip: Keine offenen Ports am Router.

## 🛡️ Die Tailscale-SSH Strategie
Wir nutzen konsequent **Tailscale-SSH**.
- **Vorteil:** Authentifizierung erfolgt über dein Tailscale-Login (OIDC/Identity).
- **Sicherheit:** Kein klassischer SSH-Port (22) muss im LAN oder Internet offen sein.

## 🔍 MagicDNS & AdGuard
Der Tower nutzt Tailscale MagicDNS zur internen Namensauflösung.
- **Integration:** AdGuardHome fungiert als Upstream-DNS für das Tailnet, um Werbung systemweit zu filtern.

## 🚀 Automatisierung (Stick-Ready)
Wir nutzen Patterns aus ironicbadger's `jankey`, um den Tower beim ersten Boot via ephemeral Auth-Keys (in Sops verschlüsselt) in das Tailnet einzubinden.