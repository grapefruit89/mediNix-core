---
id: "GUIDE-51-caddy-m1-abrams"
title: "GUIDE 51 — Caddy (511): der Edge-Standard"
domain: 51
status: active
complexity: 2
last_reviewed: 2026-10-17
tags:
  - caddy
  - ingress
links:
  adr: ""
  repo-harvest: ""
---
# 🛡️ Caddy (511): der Edge-Standard

Caddy ist die **eine** WAN-Tür. Backends binden ausschließlich
`127.0.0.1:<port>`. Modul: `51-ingress/511-caddy.nix`.

## 🔑 Eigenschaften
- **TLS via ACME:** `51-ingress/514-acme.nix` holt ein Wildcard-Zertifikat über
  NixOS-ACME/Lego (Cloudflare DNS-01). Caddy selbst spricht nie mit Let's Encrypt
  (`auto_https off`) und liest `/var/lib/acme/{acmeHost}/fullchain.pem` + `key.pem`.
- **Admin-API:** nur über einen Unix-Socket im RuntimeDirectory
  (`/run/caddy-media/admin.sock`) — **nicht** auf `127.0.0.1:2019` (RT-1).
- **Zugriff:** über den `accessGroup`-Vertrag (`stream/public/internal/idp/none`)
  statt handgeschriebener vHosts.
- **Härtung:** aus `lib/hardening-profiles.nix` (`ProtectSystem=strict`,
  `PrivateTmp`, `NoNewPrivileges`, `SystemCallFilter`).
- **Secrets:** DDNS-/ACME-Token sind **versiegelte** systemd-Credentials
  (getrennte Token, nie in `argv`).

Edge-Bouncer ist **CrowdSec** (`516`), ein Log-Sink (journald); `fail2ban` ist Legacy.

Quellen: Root-`README.md` (TLS), `51-ingress/README.md`,
`docs/ingress-security-matrix.md` (RT-1), `51-ingress/510-ingress-SERVICE.md`.
