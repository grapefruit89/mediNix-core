# ADR-5410: SABnzbd VPN Confinement — systemd-native (no netns) (54-transfer, Port 5410)

## Status: active
## Date: 2026-08-11
## Source: Claude-Index (gold_final.json, 530-acquisition, 540-transfer), Grok "Tailscale SABnzbd Not Reachable"

## Context
SABnzbd must route through VPN (Usenet provider) but the homelab must stay
reachable on LAN. Nixflix uses network namespaces (ip netns) — high complexity,
breaks on kernel updates/reboots. User wants stability over maximal isolation.

## Decision
Use **systemd-native confinement** (NOT netns):
- `RestrictNetworkInterfaces = [ "lo" ]` + explicit bind to VPN interface
- nftables routing-domain killswitch (fail-closed: drop all non-VPN egress)
- Optional eBPF only for traffic-shaping, NOT for the VPN tunnel itself
- Assertion against eBPF-VPN drift (build-time check)

Ports: SABnzbd 5410 (decimal framework ADR-5043).

## Consequences
- ✅ Stable across reboots/kernel updates (no netns teardown races)
- ✅ Fail-closed: if VPN drops, SABnzbd cannot leak plaintext
- ✅ systemd-native, fits ADR-5000 (no docker/legacy tech)
- ⚠️ Less isolation than netns (acceptable: single-tenant homelab)
- ⚠️ eBPF optional — must not become a hard dependency

## Gold-Standard (from chat)
> "Tailscale SABnzbd Not Reachable" — the recurring failure mode is VPN routing
> breaking LAN access. systemd RestrictNetworkInterfaces + nftables domain
> kill-switch solves it without netns overhead.

## Referenz-Implementierung (UID-Routing)
Das Usenet-Confinement in `52-security/525-usenet-confinement.nix` nutzt
**UID-basiertes Routing** statt netns: Der Host (systemd-networkd routeTables
oder wg-quick) routet alle Pakete der Usenet-UIDs (SABnzbd 5410, Prowlarr 5360)
durch die VPN-Tabelle. Kein Namespace, kein Port-Mapping, Loopback zwischen
Arr-Stack weiterhin funktionsfähig.

Referenz: Nix-Grok `modules/10-network/1096-vpn.nix` (das Original-Muster für
UID-Routing + event-driven Leak-Check via systemd.path auf carrier/operstate).
