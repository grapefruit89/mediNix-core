---
id: "GUIDE-51-tailnet-zero-trust"
title: "GUIDE 51 — Remote-Zugang: WireGuard statt Tailscale"
domain: 51
status: active
complexity: 2
last_reviewed: 2026-10-17
tags:
  - ingress
links:
  adr: ""
  repo-harvest: ""
---
# 🌐 Remote-Zugang ohne Port-Forward: WireGuard statt Tailscale

mediNix-core baut **kein** Tailnet. Es gibt kein Tailscale, kein MagicDNS und
keinen Cloudflare-Tunnel — verifiziert: kein `tailscale`/`cloudflared` in den
Modulen. Der Fernzugang ist WireGuard + fail-closed Killswitch.

## 🛡️ Die zwei Module
- `52-security/525-vpn-interface.nix` — WireGuard-Interface, verschlüsselter
  Private Key.
- `52-security/526-vpn-killswitch.nix` — nftables `meta skuid`-Markierung +
  Policy-Routing + `unreachable`-Fallback, wenn die VPN-Route fehlt.

## 🔍 Was 526 wirklich ist
526 ist **Egress-Confinement**, keine „absolute Isolation". Gebundene UIDs dürfen
noch Loopback, RFC1918/ULA und das VPN-Interface erreichen; alles andere ist Drop.
Was fail-closed ist, ist **WAN ohne Tunnel**.

## 🚀 Konkreter Fall
SABnzbd (`54-transfer/541-sabnzbd.nix`, UID 5410) ist doppelt geschützt:
nftables-Policy-Routing **und** Kernel-Level
`RestrictNetworkInterfaces = [ "lo" vpnIf ]`. Kein netns
(siehe `docs/NO-CONTAINERS.md`).

Quellen: `52-security/README.md`, `docs/concepts/vpn-killswitch.md`,
`54-transfer/README.md`, `docs/TERMINOLOGY.md`.
