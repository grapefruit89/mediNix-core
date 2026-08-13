---
title: VPN & Killswitch
type: Concept
---
# VPN & Killswitch

**SSoT (Single Source of Truth) für VPN-Confinement in mediNix-core**

- **RestrictNetworkInterfaces**: Services, die übers VPN müssen (wie SABnzbd), binden wir hart an das VPN-Interface (z.B. `wg0`).
- **DNS**: DNS-Leaks müssen verhindert werden; der Service muss zwingend den DNS des VPN-Providers nutzen.
- **Policy-Routing**: Wir nutzen Policy-Routing (via nftables/WireGuard fwmark), um sicherzustellen, dass nur autorisierter Traffic den Tunnel nutzt oder verlässt.
- **Kein netns**: Wir verzichten auf komplexe Network Namespaces (netns), da Systemd-Features (wie `RestrictNetworkInterfaces`) und Policy-Routing robuster und nativer sind.
