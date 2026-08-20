---
id: "ADR-5260-vpn-killswitch"
title: "VPN Kill-Switch Architecture (Policy Routing)"
domain: 52
status: active
complexity: 3
last_reviewed: 2026-08-20
tags:
  - security
  - vpn
  - network
---
# ADR-5260: VPN Kill-Switch Architecture (Policy Routing)

This document captures the architectural evolution and "lessons learned" during the development of the VPN kill-switch, particularly following the major Red-Team audit in August 2026.

## Objective ("Safety Magnet")
A Usenet downloader (SABnzbd) must be strictly bound to a WireGuard VPN (`wg0`).
*   **Fail-Closed:** If the VPN fails, no traffic is allowed to fall back to the regular internet interface (`eth0`).
*   **KISS (Keep It Simple, Stupid):** No third-party dependencies (flakes) and no over-engineered BPF complexity.
*   **Dendritic:** The kill-switch must not hardcode services. Services subscribe to the kill-switch via their UID.

---

## The Evolution: Why reject the alternatives?

### 1. Network Namespaces (NetNS / The "NixFlix" Approach)
Theoretically the strongest isolation, as the interface only exists within the namespace.
*   **Problem 1 (Dependencies):** In NixOS, there is no native declarative way to build this elegantly without relying on third-party modules (like `github:Maroka-chan/VPN-Confinement`). We refuse to outsource critical security infrastructure to external flakes due to supply-chain and link-rot risks. Building it manually via bash scripts (`ip netns add`) massively violates the KISS principle.
*   **Problem 2 (skuid Loss):** When attempting to combine `netns` with host-side `skuid` routing, a critical networking limitation arises. When a packet leaves a Network Namespace and crosses into the host namespace via a `veth` pair, it loses its original socket UID (appearing as UID 0 / root on the host). This completely breaks any host-side `nftables` rules that try to filter based on the service's UID. While excellent for Torrenting (due to port forwarding needs), it is too complex for outbound-only HTTP traffic.

### 2. The BPF Monster (`RestrictNetworkInterfaces`)
The previous `mediNix-core` approach used `RestrictNetworkInterfaces` (eBPF), complex RPDB scripts, and UDS socket blocking.
*   **Problem:** Completely over-engineered (300+ lines of code). `RestrictNetworkInterfaces` caused subtle boot race conditions with the WireGuard interface. Too many moving parts that could break silently.

### 3. Simple "VPN-only" User (Only `meta skuid drop`)
Just a firewall rule dropping packets on `eth0`.
*   **Problem:** Weak, as the kernel might still attempt to route via the main table. No clean local routing policy.

---

## The Final Solution: Hardened Policy Routing (Variant 1)

Following a strict Red-Team audit, we opted for pure-Linux **Policy Routing** (`nftables` + `ip rule`). The central code resides in `52-security/526-vpn-killswitch.nix` and is consumed dendritically by services.

### The 3 Pillars of the Architecture:

1. **Policy Routing via fwmark:**
   - We use exactly one dedicated routing table (e.g., `table 51820`).
   - `nftables` marks all egress packets originating from subscribed UIDs (e.g., SABnzbd).
   - This routing table contains a permanent blackhole route (`unreachable default metric 100`) and a VPN route (`default dev wg0 metric 10`).

2. **Absolute Fail-Closed Guarantee (No `ExecStop`):**
   - The systemd service configuring the routing table intentionally has **no `ExecStop`**.
   - The blackhole route is written into the kernel during boot and remains there permanently. A crash of the routing service does not result in a leak (Fail-Closed).
   - By using `before = [ "sabnzbd.service" ]`, we guarantee the routes are established before the service can send its first packet.

3. **DNS Isolation without Leaks:**
   - We inject a custom `resolv.conf` into the SABnzbd container using `BindReadOnlyPaths`, pointing exclusively to the VPN provider's DNS server.
   - Because `nftables` marks UDP port 53 for this UID, the DNS query is forcibly routed through the tunnel (or into the blackhole).

## Prowlarr Emergency Brake (Warning!)
Prowlarr (the Indexer) must **never** be routed through the VPN, as Usenet/Torrent indexers aggressively block VPN IPs or flood them with CAPTCHAs. Thanks to the dendritic architecture, Prowlarr was simply unsubscribed in `536-prowlarr.nix`.
