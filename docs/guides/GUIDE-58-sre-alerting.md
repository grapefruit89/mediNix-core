---
id: "GUIDE-58-sre-alerting"
title: "GUIDE 58 — SRE-Alerting: ntfy statt Matrix"
domain: 58
status: active
complexity: 2
last_reviewed: 2026-10-17
tags:
  - alerting
  - observability
  - sre
links:
  adr: ""
  repo-harvest: ""
---
# 💬 SRE-Alerting: ntfy statt Matrix

Kein Matrix, kein `matrix-hook`. Der interne Benachrichtigungs-Backend ist **ntfy**
(`58-observability/581-ntfy.nix`).

## 🛡️ ntfy (581)
- Loopback-Bind auf dem Registry-Port, tmpfs-State, `network`-Profil,
  `accessGroup = internal`.
- Auth passiert an **Caddy** (Abort + `trustedCidrs`), nicht in ntfy;
  `auth-default-access = read-write`. Assertion verbietet `public`/`stream`/`idp`.
- „Caddy ist die Wand": ein deklarierter, aber nicht auflösbarer vHost ist ein
  **Build-Fehler** (RT-5).

## 🕐 Uhren & Wächter, die melden
- `583-runtime-guard.nix` — **stündlich**: nftables-VPN-Objekte, `ss` auf
  Wildcard-`0.0.0.0`/`::` an Registry-Ports, VPN-Interface.
- `584-post-boot-watchdog.nix` — **einmalig** nach Boot: Registry-Units mit
  `ActiveState=failed`.
- `587-disk-health.nix` — SMART + Spindown-Erhalt.

## 📌 Leitsatz
**Detection, not enforcement** — die Sicherheitsgrenze ist Caddy + 526 +
systemd-Profile, nicht das Monitoring.

Quellen: `58-observability/README.md`, Root-`README.md` (Service Map).
