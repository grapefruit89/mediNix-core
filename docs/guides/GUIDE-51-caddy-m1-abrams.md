---
id: "GUIDE-51-caddy-m1-abrams"
title: "GUIDE 5110 caddy m1 abrams"
domain: 51
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - caddy
  - ingress
links:
  adr: ""
  repo-harvest: ""
---
# 🛡️ Caddy M1 Abrams: Der Ingress-Standard

Caddy ist das Gesicht deines Systems nach außen. Wir nutzen die "M1 Abrams" Edition für maximale Sicherheit.

## 🚀 Key Features
- **ACME DNS-01:** Zertifikate via Cloudflare DNS Challenge (Keine offenen Ports 80/443 für ACME nötig).
- **mTLS Ready:** Vorbereitet für interne Client-Zertifikat-Validierung.
- **Sops Integration:** Das Cloudflare Token wird sicher via SRE Tor 4 bereitgestellt.

## 🧩 Modul-Integration
Der Caddy-Dendrit liegt in `modules/services/caddy.nix`.

## 🛡️ Hardening
- **ProtectSystem=strict**
- **PrivateTmp=true**
- **NoNewPrivileges=true**
