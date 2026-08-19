---
id: 58-observability
title: Observability & Monitoring Domain
description: Monitoring, notifications, watchdogs, and Intrusion Prevention.
aliases: [Observability, Monitoring, Ntfy, CrowdSec]
tags: [architecture, medinix, observability, ntfy, crowdsec, watchdog]
---

# 58-observability: Observability & Monitoring Domain

The **Observability & Monitoring Domain** (Domain 58) is the eyes and ears of `mediNix-core`. It is responsible for letting you know when things are running smoothly, actively mitigating threats, and automatically recovering from temporary system failures. 

It does not host media or databases, but acts as a passive overlay across the entire system.

## 🎯 Core Responsibilities

1. **Push Notifications:** Running a local `ntfy.sh` instance to instantly relay alerts from the `*arr` stack, Jellyfin, and system watchdogs to your mobile devices.
2. **Intrusion Prevention:** Hosting `CrowdSec` natively to analyze Caddy access logs and actively block malicious IPs at the firewall level.
3. **Automated Recovery:** Providing a `post-boot-watchdog` that checks all media services 3 minutes after boot and automatically restarts any that failed (e.g., due to slow ZFS mounts).
4. **Runtime Integrity:** Providing a `runtime-guard` that runs hourly to ensure no service accidentally binds to `0.0.0.0` (exposing it to the WAN) and that the VPN kill-switch remains active.

## 🧩 Services in the Dezimalrahmen

Each module is strictly configured according to the mediNix Dezimalrahmen convention:

| ID  | Service | Port/UID | Responsibility |
| :--- | :--- | :--- | :--- |
| **581** | [Ntfy.sh](581-ntfy.nix) <br> [[ADR-5810]] | `5810` | Central push notification server. Exposed via Caddy to allow mobile app connectivity. |
| **582** | [CrowdSec](582-crowdsec.nix) <br> [[ADR-5820]] | N/A | Native WAF/IPS agent. Interfaces directly with Caddy (via AppSec plugin) and nftables. |
| **583** | [Runtime-Guard](583-runtime-guard.nix) <br> [[ADR-0000]] | N/A | An hourly `systemd.timer` that asserts strict firewall and binding rules, alerting via `ntfy` if broken. |
| **584** | [Post-Boot Watchdog](584-post-boot-watchdog.nix) <br> [[ADR-5043]] | N/A | A one-shot script running 180s after boot that detects and restarts failed `mediNix` systemd units. |

## 🛡️ Key Architecture Decisions

- **Native CrowdSec (No Docker):** CrowdSec is run as a native `systemd` service rather than a container. This allows it to natively integrate with the host's `nftables` firewall and read the host's Caddy logs without complex volume mounts or bridging.
- **Dynamic Watchdog Targets:** The `post-boot-watchdog` does not hardcode the services it checks. It dynamically reads `lib/registry.nix` during evaluation, meaning any new service you add to the Dezimalrahmen is automatically monitored for boot failures.
- **Self-Hosted Notifications:** Relying on `ntfy.sh` means your system does not depend on third-party SaaS notification providers (like Telegram or Discord bots), keeping all metadata and alerts completely private.
