---
title: VPN & Killswitch
type: Concept
last_reviewed: 2026-10-17
---
# VPN & Killswitch

**Concept — Soll-Architektur, keine Behauptung „das System macht das bereits
vollständig".** VPN-Confinement ist ein **Contract aus mehreren Schichten**, nicht
eine einzige Direktive:

```text
VPN-required service
  → erlaubte Netzwerk-Interface(s)   (RestrictNetworkInterfaces)
  → Policy-Routing                   (nftables skuid → fwmark → Routing-Table)
  → Killswitch (harter Drop)         (nftables output-Filter)
  → DNS-Policy                       (resolv.conf aus dem Credential-Store)
  → Fail-closed-Verhalten
```

- **RestrictNetworkInterfaces** — POLICY (eine Seite des Contracts): cgroup-BPF-
  Socketfilter im Kernel. Dienste, die übers VPN müssen (SABnzbd), werden hart an
  `[ "lo", "<vpnIf>" ]` gebunden — die Assertion in `54-transfer/541-sabnzbd.nix`
  verbietet jedes weitere Interface. `[ "lo" ]` allein (z.B. Pocket-ID,
  `51-ingress/512-pocket-id.nix`) ist die ganz andere Aussage „local-only".
- **Policy-Routing + Killswitch** — IMPLEMENTATION: `services.vpnKillSwitch`
  (`52-security/526-vpn-killswitch.nix`) markiert Pakete per `meta skuid <uid>` in
  eine eigene Routing-Table (`fwmark`, Default 51820). Die Table trägt ein
  `unreachable default` als fail-closed-Fallback und erst bei vorhandener
  Tunnel-IP ein `default dev <vpnIf>`. Ein zweiter `output`-Filter (Grundhaltung
  `accept`, dann pro UID) **droppt** alles, was nicht markiert über das
  VPN-Interface geht.
- **DNS** — IMPLEMENTATION (Runtime): `dnsServers` darf nicht leer sein
  (Assertion gegen `127.0.0.1`-Leaks); eine generierte `resolv.conf` wird per
  `BindReadOnlyPaths` in die Dienste gemountet, so dass sie den DNS des Providers
  sehen. Bewiesen wird Leak-Freiheit erst durch Runtime-Evidenz, nicht durch
  Konfiguration.
- **Kein netns** — ENTSCHEIDUNG: Keine Network Namespaces; systemd-Features
  (`RestrictNetworkInterfaces`) plus nftables-Policy-Routing gelten als robuster
  und nativer. Zusätzliche fail-closed-Wächter: UID-Kette
  Registry↔Instanz↔systemd-User (R15) und IPv6 (R16: IPv6 bleibt aus, solange
  kein IPv6-Killswitch aktiv ist), `checkReversePath = "loose"`.

## Evidenz-Hierarchie

```text
Concept → Contract → Nix-Assertion / generierte Config → Test → Runtime-Evidenz
```

Konfiguration und Tests beweisen einen *Teil*; die DNS-/Egress-Behauptung beweist
nur Runtime.

## Referenzen

- `52-security/526-vpn-killswitch.nix` — skuid-Policy-Routing + Killswitch-Ketten
- `52-security/525-vpn-interface.nix` — flake-verwaltetes WireGuard (TPM-Sealed-Key)
- `54-transfer/541-sabnzbd.nix` — RestrictNetworkInterfaces + nftables (dual)
- `docs/adr/ADR-526-vpn-killswitch.md` — Entscheidung (kein netns)
