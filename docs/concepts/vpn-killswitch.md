---
title: VPN & Killswitch
type: Concept
---
# VPN & Killswitch

**Concept — Soll-Architektur, keine Behauptung „das System macht das bereits vollständig".**

VPN-Confinement ist ein **Contract aus mehreren Schichten**, nicht eine einzige
Direktive:

```text
VPN-required service
  → erlaubte Netzwerk-Interface(s)   (RestrictNetworkInterfaces)
  → Routing-Policy                   (nftables / WireGuard fwmark)
  → DNS-Policy
  → Fail-closed-Verhalten
```

- **RestrictNetworkInterfaces** — POLICY (eine Seite des Contracts): Services,
  die übers VPN müssen (wie SABnzbd), werden hart an das VPN-Interface (`wg0`)
  gebunden. Die Semantik hängt aber vom Wert ab: `[ "lo" ]` (z.B. Pocket-ID,
  local-only) ist eine ganz andere Aussage als `[ "wg0" ]` (Egress durch den
  Tunnel).
- **DNS** — SOLL (Runtime-Behauptung): DNS-Leaks müssen verhindert werden; der
  Service muss den DNS des VPN-Providers nutzen. `RestrictNetworkInterfaces`
  allein garantiert das **nicht**, und Policy-Routing allein garantiert nicht,
  dass die Anwendung tatsächlich nur den gewünschten DNS-Pfad benutzt. Bewiesen
  wird das nur durch Runtime-Evidenz, nicht durch Konfiguration.
- **Policy-Routing** — IMPLEMENTATION: Policy-Routing (nftables / WireGuard
  fwmark) sorgt dafür, dass nur autorisierter Traffic den Tunnel nutzt oder
  verlässt.
- **Kein netns** — ENTSCHEIDUNG: Keine Network Namespaces; systemd-Features
  (`RestrictNetworkInterfaces`) und Policy-Routing gelten als robuster und
  nativer.

## Evidenz-Hierarchie

```text
Concept → Contract → Nix-Assertion / generierte Config → Test → Runtime-Evidenz
```

Konfiguration und Tests beweisen einen *Teil*; die DNS-/Egress-Behauptung beweist
nur Runtime.
