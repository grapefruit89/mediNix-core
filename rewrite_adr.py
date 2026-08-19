import os

PATH = "docs/adr/ADR-5410-usenet-confinement.md"

content = """# ADR-5410: VPN Kill-Switch Architektur (SABnzbd)

Dieses Dokument hält die architektonische Evolution und alle "Lessons Learned" bei der Entwicklung des VPN-Kill-Switches fest, insbesondere nach dem großen Red-Team-Audit durch "Grok" im August 2026.

## Zielsetzung ("Safety Magnet")
Ein Usenet-Downloader (SABnzbd) soll strikt an ein WireGuard-VPN (`wg0`) gebunden werden. 
*   **Fail-Closed:** Wenn das VPN ausfällt, darf kein Traffic auf das reguläre Internet (`eth0`) ausweichen.
*   **KISS (Keep It Simple, Stupid):** Keine Fremd-Abhängigkeiten (3rd-Party Flakes) und keine überzüchteten BPF-Spielereien.
*   **Dendritisch:** Der Killswitch darf die Dienste nicht hart einkodieren. Dienste abonnieren den Killswitch über ihre UID.

---

## Die Evolution: Warum nicht die Alternativen?

### 1. Network Namespaces (NetNS / Der "NixFlix"-Ansatz)
Theoretisch die stärkste Isolation. Das Interface existiert nur im Namespace.
*   **Problem:** In NixOS gibt es nativ keine deklarative Möglichkeit, das elegant zu bauen, ohne auf Third-Party-Module (wie `github:Maroka-chan/VPN-Confinement`) zurückzugreifen. Wir lehnen es ab, kritische Sicherheitsinfrastruktur an externe Flakes auszulagern (Abhängigkeits-Risiko). Ein Eigenbau über Bash-Scripte (`ip netns add`) verletzt das KISS-Prinzip massiv.

### 2. Das BPF-Monster (`RestrictNetworkInterfaces`)
Der vorherige `mediNix-core`-Ansatz nutzte `RestrictNetworkInterfaces` (eBPF), komplexe RPDB-Skripte und UDS-Socket-Sperren.
*   **Problem:** Völlig überzüchtet (300+ Zeilen Code). `RestrictNetworkInterfaces` führte zu subtilen Boot-Race-Conditions mit dem WireGuard-Interface. Zu viele bewegliche Teile, die geräuschlos brechen konnten. Verletzt das KISS-Prinzip.

### 3. Einfacher „VPN-only“-User (Nur `meta skuid drop`)
Nur eine Firewall-Regel, die Pakete auf `eth0` verbietet.
*   **Problem:** Schwach, da der Kernel trotzdem versuchen kann, über die Haupttabelle zu routen. Kein sauberes lokales Routing.

---

## Die finale Lösung: Gehärtetes Policy-Routing (Variante 1)

Wir haben uns nach einem harten Red-Team-Audit für reines, pure-Linux **Policy-Routing** (nftables + ip rule) entschieden. Der Code liegt zentral unter `52-security/526-vpn-killswitch.nix` und wird dendritisch von den Diensten konsumiert.

### Die 3 Säulen der Architektur:

1. **Policy-Routing via fwmark:**
   - Wir nutzen genau eine dedizierte Routing-Tabelle (z.B. `table 51820`).
   - `nftables` markiert alle Egress-Pakete der abonnierten UIDs (z.B. SABnzbd).
   - In dieser Tabelle gibt es eine permanente Blackhole-Route (`unreachable default metric 100`) und eine VPN-Route (`default dev wg0 metric 10`).

2. **Absolute Fail-Closed Garantie (Kein `ExecStop`):**
   - Der Systemd-Service, der die Routing-Tabelle aufbaut, hat absichtlich **kein `ExecStop`**.
   - Die Blackhole-Route wird beim Booten in den Kernel geschrieben und bleibt dort für immer stehen. Ein Absturz des Routing-Services führt nicht zum Leak (Fail-Closed).
   - Durch `before = [ "sabnzbd.service" ]` wird erzwungen, dass die Routen stehen, bevor der Dienst das erste Paket senden kann.

3. **DNS Isolation ohne Leak:**
   - Wir injizieren über `BindReadOnlyPaths` eine eigene `resolv.conf` in den SABnzbd-Container, die exklusiv auf den DNS-Server des VPN-Providers zeigt.
   - Da `nftables` UDP-Port 53 von dieser UID markiert, wird auch die DNS-Anfrage zwingend durch den Tunnel (oder das Blackhole) gezwungen.

## Prowlarr-Notbremse (Achtung!)
Prowlarr (Indexer) darf **niemals** durch das VPN geroutet werden, da Usenet/Torrent-Indexer VPN-IPs aggressiv sperren oder mit Captchas fluten. Dank der dendritischen Architektur wurde Prowlarr einfach aus der Subscription in `536-prowlarr.nix` entfernt.
"""

with open(PATH, 'w', encoding='utf-8') as f:
    f.write(content)

