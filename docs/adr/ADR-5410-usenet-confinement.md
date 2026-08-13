# VPN Kill-Switch für SABnzbd (Defense-in-Depth)

Dieses Dokument hält die architektonische Evolution, alle "Lessons Learned" und die überwundenen Stolpersteine bei der Entwicklung des VPN-Kill-Switches fest. Es dient als Referenz dafür, warum das System exakt so gebaut ist, wie es in `525-usenet-confinement.nix` steht.

## Zielsetzung ("Safety Magnet")
Ein Usenet-Downloader (SABnzbd) soll strikt an ein WireGuard-VPN (`vpn0`) gebunden werden. 
*   **Fail-Closed:** Wenn das VPN ausfällt, darf kein Traffic auf das reguläre Internet (`eth0`) ausweichen. Das System muss wie ein "Sicherheits-Magnet" stromlos in einen komplett blockierten Zustand fallen.
*   **KISS (Keep It Simple, Stupid):** Keine reaktiven Watchdog-Skripte (die externe APIs wie `ipify.org` abfragen).
*   **Erreichbarkeit:** Der Dienst muss nativ über `127.0.0.1` für den Reverse-Proxy des Hosts erreichbar bleiben.

---

## Die Evolution: Warum nicht die Alternativen?

### Variante 1: Network Namespaces (Der "NixFlix"-Ansatz)
Theoretisch die sauberste Isolation (komplett eigener Netzwerk-Stack).
*   **Problem:** Verletzt das KISS-Prinzip (benötigt `veth`-Paare, Bridges, NAT) und zerstört die einfache Erreichbarkeit über `127.0.0.1`. Der Host-Proxy kommt nur über umständliches Port-Forwarding an die Web-UI. 
*   *Erkenntnis: Für reinen Outbound-Traffic (Usenet) ist das massiver Overkill.*

### Variante 2: Reines nftables (Der alte mediNix-Ansatz)
Nur eine Firewall-Regel (`meta skuid drop`), die Pakete der Dienst-UID auf `eth0` verbietet.
*   **Der fatale Fehler (DNS-Leak):** Wenn SABnzbd einen lokalen DNS-Resolver (z.B. Blocky auf `127.0.0.1`) befragt, passiert dieses Paket die Firewall legal (da es zu `lo` geht). Blocky löst die Anfrage dann aber unter *seiner eigenen* UID über `eth0` auf. Die UID-Firewall-Regel greift hier nicht!

---

## Die finale Lösung: Die 4 Säulen (Variante 3)

Um das DNS-Leck und andere Bypasses zu verhindern, nutzt dieses Modul vier voneinander unabhängige, proaktive Barrieren im Kernel:

1.  **Physische Barriere (eBPF):** `RestrictNetworkInterfaces = [ "lo" "vpn0" ]`. Dies blockt egress-Pakete auf Cgroup-Ebene (noch vor dem Routing!).
2.  **Der Routing-Magnet:** UID-basiertes Policy Routing zwingt den Traffic in eine dedizierte Tabelle. Diese Tabelle hat eine permanente `blackhole default`-Route. Fällt das VPN aus, fällt der Traffic unweigerlich ins schwarze Loch.
3.  **Die Tripwire-Canary:** Eine unabhängige `nftables`-Regel lauscht direkt auf dem WAN-Ausgang und zählt/blockt Pakete. ACHTUNG: Ein Zähler > 0 bedeutet, dass Säule 2 (Routing/Blackhole) versagt hat, nicht Säule 1, da eBPF noch nach netfilter (POSTROUTING) ausgeführt wird.
4.  **Runtime Assertion:** `ExecStartPre` und `ExecStartPost` verifizieren beim Start, ob Routing, Firewall und eBPF-Hooks *tatsächlich* aktiv sind, andernfalls startet der Dienst nicht.

---

## Stolpersteine und Lessons Learned (Die Security-Fixes)

Auf dem Weg zu dieser Architektur wurden durch intensive Reviews etliche kritische Sicherheitslücken und Denkfehler aufgedeckt und im Code gepatcht:

### 1. Das IPv6-Loch
*   **Problem:** Wenn man nur IPv4-Routen (`0.0.0.0/0`) absichert, läuft IPv6-Traffic komplett am Policy-Routing vorbei.
*   **Lösung:** IPv6 auf Kernel-Ebene für den Dienst deaktivieren durch `RestrictAddressFamilies` (erlaubt nur `AF_UNIX`, `AF_INET` und `AF_NETLINK`).

### 2. UID-Morphing
*   **Problem:** Wenn SABnzbd gehackt wird und seine UID ändert (z.B. auf `root`), greift das UID-Routing nicht mehr.
*   **Lösung:** Strikte systemd-Härtung (`NoNewPrivileges = true`, `CapabilityBoundingSet = ""`, `RestrictSUIDSGID`), um die UID permanent festzunageln.

### 3. Das systemd-resolved D-Bus Leak
*   **Problem:** Selbst wenn man dem Dienst per `BindReadOnlyPaths` eine eigene `resolv.conf` (mit dem VPN-DNS) unterschiebt, könnte er heimlich über den D-Bus Socket (`/run/systemd/resolve/...`) mit dem Host-DNS sprechen.
*   **Lösung:** `InaccessiblePaths` und `PrivateMounts` blockieren den Zugriff auf den D-Bus-Socket physisch.

### 4. Der "Blinde" Watchdog (dummy0 vs. nftables)
*   **Denkfehler:** Ursprünglich wollten wir Pakete in ein `dummy0`-Interface routen und dessen Traffic überwachen. 
*   **Erkenntnis:** Wenn die Policy-Routing-Regel selbst ausfällt, geht der Traffic direkt an `eth0` – das `dummy0`-Interface würde den Leak nie mitbekommen. Nur eine Canary direkt auf dem WAN-Interface (`nftables`) ist ein echtes, unabhängiges Tripwire. Ein `dummy0` wird gar nicht benötigt, der Route-Typ `blackhole` reicht.

### 5. eBPF Check: Build-Macro vs. Runtime
*   **Denkfehler:** Wir versuchten, mit `bpftool` das Flag `BPF_FRAMEWORK` zu prüfen.
*   **Erkenntnis:** Das ist nur ein systemd-Compile-Flag. Zur Laufzeit muss stattdessen geprüft werden, ob die eBPF-Programme `cgroup_inet_egress` / `ingress` aktiv an die Cgroup des Dienstes angeheftet sind (`bpftool cgroup show ... effective`).

### 6. Fragile Cgroup-Pfade
*   **Problem:** Cgroup-Pfade wie `/sys/fs/cgroup/system.slice/...` fest in den Check einzuprogrammieren, bricht, sobald systemd die Slices ändert.
*   **Lösung:** Den Pfad dynamisch über `systemctl show -p ControlGroup` oder `/proc/$PID/cgroup` ermitteln.

### 7. Schreibrechte trotz Sandboxing
*   **Problem:** `ProtectSystem = "strict"` macht das Dateisystem read-only, der Dienst stürzte ab.
*   **Lösung:** Explizite Freigabe über `StateDirectory = "sabnzbd"` und `ReadWritePaths`.

### 8. Race-Conditions beim Start und Firewall-Reloads
*   **Problem:** Ein `ExecStartPost` läuft minimal nach Dienststart. In dieser Millisekunde könnten Pakete leaken. Noch gefährlicher: Wenn die Canary-Regel in einem einfachen Oneshot-Service installiert wird, verschwindet sie bei einem `nixos-rebuild switch`, wenn NixOS die Firewall neu lädt.
*   **Lösung:** Ein hartes `ExecStartPre`-Skript prüft vor dem Start, ob die Policy-Routen und die nftables-Regel exakt existieren. Die Canary selbst wurde vollständig deklarativ über `networking.nftables.tables` konfiguriert. So überlebt sie jeden Firewall-Reload garantiert.

### 9. Das Localhost Relay (Der schlimmste Blinde Fleck)
*   **Problem:** SABnzbd darf weiterhin mit dem Loopback-Interface (`lo`) sprechen (damit der Reverse-Proxy funktioniert). SABnzbd könnte aber *selbst* eine Verbindung zu einem lokalen Dienst aufbauen (z.B. HTTP-Proxy, Prowlarr) und diesen als WAN-Relay missbrauchen. Ein weiterer Angriffsvektor sind UNIX-Sockets (UDS), die sich netfilter komplett entziehen.
*   **Lösung:** Ein massiver Ausbau der IPC-Isolation (`InaccessiblePaths` blockiert den physischen Zugriff auf UDS-Backend-Ordner wie `/run/medinix` und D-Bus) und ein genialer nftables-Trick: `meta skuid <UID> oifname "lo" ct state new counter drop`. Das verbietet dem Dienst, *neue* Verbindungen über `lo` aufzubauen. Er darf aber auf eingehende Proxy-Requests antworten.

---
**Fazit:** 
Durch die Abstraktion in eine generische Fabrik und das Abdichten des Localhost-Relay-Angriffsvektors ist die Architektur nun auf dem Level eines echten **Gold Standards**. Leaks sind strukturell sowohl auf direktem Wege (eth0) als auch auf indirektem Wege (Localhost Relays / IPC) ausgeschlossen. Die Behauptung "vier Mechanismen müssten gleichzeitig versagen" war anfangs zu optimistisch, da der Relay-Angriff alle vier Mechanismen gleichzeitig umging. Jetzt haben wir eine Architektur, die jeden dieser Angriffsvektoren unabhängig und präzise blockiert – und das bei vollem Erhalt des KISS-Prinzips (nativ `127.0.0.1`, kein netns-Overhead).
