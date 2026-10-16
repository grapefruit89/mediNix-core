---
id: "0011"
title: "ADR-0011 — UID-basiertes nftables-Routing vs. Network Namespaces (netns)"
domain: 00
status: Accepted
complexity: 3
last_reviewed: 2026-10-12
tags:
  - architecture
  - security
  - vpn
  - nftables
  - networking
links:
  adr: ADR-526-vpn-killswitch
---

# ADR-0011: UID-basiertes nftables-Routing vs. Network Namespaces (netns)

## Status
**Accepted**

---

## 1. Kontext: VPN-Isolation ohne Container-Overhead

In mediNix gilt das Zero-Container- und Bare-Metal-Prinzip (Dezimalrahmen-Verfassung ADR-0000): Alle Dienste laufen nativ auf dem Host unter systemd.

Für den Usenet-Downloader (**SABnzbd**, UID 5410) ist ein ausnahmsloser VPN-Zwang (Killswitch) gefordert:
* Bei Ausfall des WireGuard-Tunnels (`wg-medinix` / `wg0`) darf kein einziges Paket über das WAN-Interface des Hosts leaken (Fail-Closed).
* Lokale Fachdienste (Sonarr UID 5320, Radarr UID 5330) müssen die SABnzbd-API jedoch uneingeschränkt über `127.0.0.1:5410` (Loopback) erreichen können.

In der NixOS- und Homelab-Community existieren zwei Hauptansätze für VPN-Isolation:
1. **Network Namespaces (`netns` / `PrivateNetwork = true` / externe Flakes wie VPN-Confinement)**
2. **Natives Linux Policy Routing (UID-basiertes `nftables` + `ip rule` + cgroup-BPF)**

---

## 2. Warum Network Namespaces (`netns`) in mediNix verboten sind

Die Evaluierung von `netns` zeigte gravierende architektonische Nachteile für mediNix:

1. **Verlust der Socket-Identität (`skuid`-Stripping):**
   Wenn Pakete einen Network Namespace über ein `veth`-Paar in den Host-Namespace verlassen, geht die ursprüngliche Linux-Socket-UID (`meta skuid`) verloren. Auf dem Host erscheinen die Pakete als UID 0 (root). Dadurch versagen alle host-weiten `nftables`-Filterregeln, die auf Dienst-UIDs basieren.

2. **Bruch der lokalen Inter-Service-Kommunikation:**
   In einem isolierten Network Namespace besitzt der Dienst sein eigenes `lo` (Loopback). Sonarr und Radarr auf dem Host können `127.0.0.1:5410` nicht mehr kontaktieren, ohne komplexe Port-Forwards (`socat`, `veth`-Brücken oder Proxy-Daemons) einzurichten. Dies widerspricht dem KISS-Prinzip (Keep It Simple, Stupid) fundamental.

3. **Abhängigkeit von Drittanbieter-Flakes:**
   Deklaratives `netns` in NixOS erfordert oft externe Flakes (Supply-Chain-Risiko, Link-Rot) oder fehleranfällige imperative Shell-Skripte (`ip netns add`).

---

## 3. Entscheidung: 3-Ebenen-Wächter für UID-basiertes Routing

Wir etablieren natives, bare-metal **Policy Routing** mit einer 3-stufigen Defense-in-Depth-Architektur:

### Ebene 1: Host & Globale Invarianten (`50-core/500-host-baseline.nix`)
* **Verbot von `netns`:** WireGuard-Namespaces (`networking.wireguard.useNetworkNamespace`) sind global verboten.
* **Exklusivitäts-Ratsche:** Ausschließlich `sabnzbd` (UID 5410) darf in `services.vpnKillSwitch.instances` registriert sein (kein Torrenting, kein Prowlarr-VPN-Routing).

### Ebene 2: Firewall & Routing-Engine (`52-security/`)
* **Fail-Closed Routing Table (`table 51820`):** Eine permanente Blackhole-Route (`unreachable default metric 100`) fängt Traffic ab, falls der VPN-Tunnel nicht steht.
* **`checkReversePath = "loose"`:** Der Linux-Kernel verwirft asymmetrische Routing-Pfade bei WireGuard, wenn strict Reverse-Path-Filtering aktiv ist (`checkReversePath = true`). Daher setzt mediNix `checkReversePath = lib.mkDefault "loose";` und `logReversePathDrops = true`, gesichert durch Assertions in `525-vpn-interface.nix` und `526-vpn-killswitch.nix`.
* **DNS-Leak-Schutz:** `medinix.vpn.dns` darf nicht leer sein. Die confinierten Dienste erhalten via `BindReadOnlyPaths` eine eigene `resolv.conf`, die ausschließlich auf die VPN-DNS-Server zeigt.

### Ebene 3: Service-Confinement (`54-transfer/541-sabnzbd.nix`)
* **Verbot von `PrivateNetwork`:** Assertion stellt sicher, dass `PrivateNetwork = false` bleibt, damit `127.0.0.1` frei für *arr-Verbindungen ist.
* **cgroup-BPF Socket-Filter:** `RestrictNetworkInterfaces = [ "lo" vpnIf ]` blockiert alle anderen Netzwerkinterfaces direkt im Linux-Kernel.
* **UID-Verankerung:** Assertion stellt sicher, dass SABnzbd im Killswitch exakt an UID 5410 gebunden ist.

---

## 4. Konsequenzen

1. **Kein Leaking möglich:** Weder Kernel-Routing-Drift noch ein Dienst-Absturz können unverschlüsselten Traffic über WAN leiten.
2. **Reibungslose lokale Integration:** Sonarr und Radarr kommunizieren nativ über `127.0.0.1:5410` mit SABnzbd ohne jegliche Latenz oder Proxy-Hops.
3. **Formale Absicherung:** Compile-Time-Assertions in Layer 50, 52 und 54 verhindern, dass zukünftige Commits versehentlich `netns` oder unzulässige Killswitch-Instanzen einführen.
