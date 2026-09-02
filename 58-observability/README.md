---
id: 58-observability
title: Observability
description: Notifications and runtime checks. Detection, not enforcement.
domain: 58
status: active
last_reviewed: 2026-09-02
---

# 58-observability

Detection and notification. The security boundary is Caddy, 526, and systemd profiles.

Three modules. There is no `582-crowdsec.nix`.

| ID | Module | Role |
| --- | --- | --- |
| **581** | [`581-ntfy.nix`](581-ntfy.nix) | Internal notification backend |
| **583** | [`583-runtime-guard.nix`](583-runtime-guard.nix) | Hourly runtime checks |
| **584** | [`584-post-boot-watchdog.nix`](584-post-boot-watchdog.nix) | One-shot failed-unit restart after boot |

```
581 ntfy
   ▲
   │ alerts
583 runtime-guard  — VPN table, wildcard listeners, iface
584 post-boot      — registry units with ActiveState=failed
```

## 581 ntfy

Loopback bind, registry port, tmpfs state, `network` profile, `accessGroup = internal`.

`auth-default-access = read-write`. Auth is Caddy abort + trustedCidrs, not ntfy.
Assertion rejects `public` / `stream` / `idp`.

## 583 runtime-guard

Hourly. Checks nftables VPN objects, `ss` for `0.0.0.0`/`::`/`*` on registry ports, VPN iface.
Fail → ntfy + exit 1.

Detection, not enforcement. The wall is 526. The unit has `CAP_NET_ADMIN` only to *read* nft.

## 584 post-boot watchdog

Once, 180s after boot. Restarts registry units only if `ActiveState=failed`. Not `inactive`. Not a continuous watchdog.

## Agent notes

- Keep ntfy internal.
- Do not treat 583/584 as the VPN or firewall.
- No CrowdSec in this domain.
- Registry is the unit/port list.
