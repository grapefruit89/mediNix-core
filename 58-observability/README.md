---
id: 58-observability
title: Observability
---

# 58-observability

Notifications and watchdogs. No WAF.

| ID | Module | Role |
| --- | --- | --- |
| 581 | ntfy | push notifications |
| 583 | runtime-guard | hourly bind / VPN check |
| 584 | post-boot-watchdog | restart failed units after boot |

CrowdSec was removed. Edge is Caddy + nft + assertions, not a half-wired bouncer.
