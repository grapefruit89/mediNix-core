# Snippet- & Lösungs-Register (mediNix-core)

> Aggregiert alle `better`-Entscheidungen mit konkreten `proposed_change`-Vorgaben.
> Bildet die unmittelbare Implementierungsvorlage für anstehende Refactorings.

| ID | Vorgeschlagene Änderung / Snippet | Quelle | Warum besser (Rationale) |
| :--- | :--- | :--- | :--- |
| `S-01` | catchAllSites rendert 'respond "Get off my lawn" 404' für *.${domain}, sowohl HTTP als auch HTTPS. | `02-caddy-catch-all` (`D-02-01`) | `abort` schließt TCP ohne HTTP-Status. CrowdSec-Szenario `http-scan-uniques_404` matcht auf 404 und feuert bei `abort... |
| `S-02` | hub.collections um "crowdsecurity/http-probing" erweitern. | `03-crowdsec-scan-ban` (`D-03-01`) | Im Ist-Zustand enthält 516-crowdsec.nix nur `crowdsecurity/caddy`. Ohne `crowdsecurity/http-probing` fehlt das Szenar... |
| `S-03` | Dauer auf duration = "168h" anheben oder Option `medinix.crowdsec.banDuration` einführen. | `03-crowdsec-scan-ban` (`D-03-03`) | Scannende Bots wechseln ihre IPs nicht im 4-Stunden-Takt; 7 Tage Ban-Dauer hält wiederkehrende Scan-Wellen fern und e... |
| `S-04` | *.cred und *.encrypted in .gitignore ergänzen. | `04-credentials-systemd-creds` (`D-04-03`) | Auch wenn .cred-Dateien mit TPM2+Hostkey hardwaregebunden sind, lecken sie Metadaten (Dienstnamen, Rotationszeitpunkt... |
| `S-05` | Testweise UNIX_SOCKET + TRUST_PROXY=true setzen, Audit-Log prüfen. Wenn IPs erscheinen: umstellen. | `04-credentials-systemd-creds` (`D-04-04`) | Pocket ID unterstützt UDS nativ (UNIX_SOCKET). Bug #1249 (Client-IPs leer) ist in Gin PR #3359 gefixt, wahrscheinlich... |
| `S-06` | httpAddress = unix:///run/oauth2-proxy/oauth2-proxy.sock; 511 forward_auth-Upstream anpassen. | `04-credentials-systemd-creds` (`D-04-04`) | Pocket ID unterstützt UDS nativ (UNIX_SOCKET). Bug #1249 (Client-IPs leer) ist in Gin PR #3359 gefixt, wahrscheinlich... |
| `S-07` | Modul entfernen oder per Option standardmäßig deaktivieren. 515-blocky.nix übernimmt Split-DNS. | `05-mdns-vs-blocky` (`D-05-01`) | Caddy rendert keine .local-Sites (laut README). Avahi publiziert nutzlose Records, erzeugt Multicast-Traffic (UDP 535... |
| `S-08` | WAN_IP-Ermittlung auf modularen Provider-Dispatch (Router/DNS) umstellen. Speedport-Adapter: speedport-api public_ip_... | `06-dns-wan-ip-provider` (`D-06-01`) | Im Ist-Zustand nutzt 513-cloudflare-dns.nix externe HTTP-Echo-Dienste (https://ifconfig.me, https://api.ipify.org). D... |
| `S-09` | ROUTER_IP aus Default-Gateway ableiten für lokale Router-Abfragen. | `06-dns-wan-ip-provider` (`D-06-02`) | Ein Hardcodieren von 192.168.2.1 bricht sofort bei geändertem Subnetz oder Router-Tausch. Das Default-Gateway (ip rou... |
| `S-10` | Einführen von options.medinix.dns.ddns.wanIp.provider. | `06-dns-wan-ip-provider` (`D-06-04`) | Ermöglicht den nahtlosen Router-Wechsel (z. B. Speedport zu FritzBox) über eine deklarative NixOS-Option, ohne Skript... |
| `S-11` | Empfehlung für hybride PQC-Kex (mlkem768x25519) in SSH-Hardening ergänzen. | `07-pqc-hndl` (`D-07-03`) | OpenSSH unterstützt ab Version 9.9/10.0 standardmäßig hybriden Schlüsselaustausch nach FIPS 203 (ML-KEM-768 + X25519)... |
| `S-12` | Option für debugReject mit Log-Präfix zur Diagnose vorschlagen. | `08-firewall-nftables` (`D-08-03`) | Beim Debuggen von Netzwerk- und VPN-Problemen führt Default-DROP zu zeitraubenden Timeouts. Ein umschaltbarer Schalte... |
| `S-13` | Empfohlene Modul-Blacklist (z. B. medinix.recommended.blacklistedKernelModules) vorschlagen. | `09-kernel-hardening` (`D-09-03`) | Im Chat (Nachrichten 100–101) fragte der Nutzer explizit nach Kernel-Blacklisten für Consumer-/Homelab-Hardware. Obsk... |
| `S-14` | Empfehlung für schedutil / auto-cpufreq in Host-Dokumentation aufnehmen. | `10-power-management` (`D-10-01`) | Auf einem Headless-Homelab-Server bietet schedutil in Verbindung mit auto-cpufreq eine blitzschnelle, bedarfsgerechte... |
| `S-15` | GuC/HuC Kernel-Parameter i915.enable_guc=3 als Host-Voraussetzung vermerken. | `10-power-management` (`D-10-02`) | Für Intel CPUs der 9. Generation (i3-9100 Coffee Lake) entlastet die GuC/HuC-Firmware die CPU bei Video-Transcoding (... |
| `S-16` | 515-mdns.nix durch 515-blocky.nix ersetzen (UID 5150, Port 53, Split-DNS). | `11-51-tree-struktur` (`D-11-01`) | mDNS (515-mdns.nix) ist tote Konfiguration und entfällt. Durch die Nachnutzung des Slots 515 für Blocky bleibt die de... |
| `S-17` | Modul löschen bzw. durch Blocky ersetzen. | `11-51-tree-struktur` (`D-11-02`) | Caddy rendert bereits keine `.local`-Sites mehr. Avahi verbraucht Ressourcen und leckt interne Hostnamen im LAN. DNS-... |
| `S-18` | LAN-Publishing entfernen und WAN-IP-Ermittlung über Provider-Lib anbinden. | `11-51-tree-struktur` (`D-11-03`) | Das bisherige 513 vermischt WAN-DDNS, LAN-A-Records und HTTP-Echo-Abfragen. Die Trennung in reines WAN-DDNS und eine ... |
| `S-19` | Präambel erweitern: Dezimalrahmen als fraktales Dateisystem- und Ordnungsprinzip etablieren. | `12-adr-dezimalrahmen` (`D-12-01`) | Die Beschränkung auf reine Daemon-Module erzeugt künstliche Inkonsistenzen (z. B. Unsicherheit über die Rolle von Fou... |
| `S-20` | Abschnitt über Credentials-Speicherorte und Secret-Pfade ergänzen. | `12-adr-dezimalrahmen` (`D-12-03`) | Die Speicherung von Credentials darf weder Magic Numbers noch unkontrollierte Ablagen im Git erzeugen. Ein dedizierte... |
| `S-21` | customConfig zwingend nach forward_auth und IP-Filtering einsortieren. | `14-config-review-51-ingress` (`D-14-01`) | Wird customConfig vor den Forward-Auth- oder CrowdSec-Blöcken gerendert, können fehlerhafte oder unvorsichtige Snippe... |
| `S-22` | Validierung über semantische IP/CIDR-Parser-Funktion abbilden. | `14-config-review-51-ingress` (`D-14-02`) | Einfache String-Checks (z. B. auf '192.168.') erkennen ungültige Subnetzmasken nicht und können bei komplexen Netzwer... |

## Detaillierte Snippets & Handlungsanweisungen

### `S-01`: Caddy Catch-All: `abort` durch `respond 404` ersetzen, damit CrowdSec Scan-Verkehr erkennt und bannen kann.
- **Datei:** `/home/moritz/repos/mediNix-core/51-ingress/511-caddy.nix`
- **Quelle:** `02-caddy-catch-all` / Decision `D-02-01`
- **Warum besser:** `abort` schließt TCP ohne HTTP-Status. CrowdSec-Szenario `http-scan-uniques_404` matcht auf 404 und feuert bei `abort` nie. `respond 404` liefert das nötige Signal für die Ban-Kette (CrowdSec → nftables-Bouncer).
- **Ist-Zustand:** `catchAllSites rendert 'abort' für *.${domain} (Zeilen ~339–348).`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
catchAllSites rendert 'respond "Get off my lawn" 404' für *.${domain}, sowohl HTTP als auch HTTPS.
```

### `S-02`: CrowdSec Hub-Collections um `crowdsecurity/http-probing` erweitern, um das Szenario `http-scan-uniques_404` zur Scan-Erkennung zu aktivieren.
- **Datei:** `/home/moritz/repos/mediNix-core/51-ingress/516-crowdsec.nix`
- **Quelle:** `03-crowdsec-scan-ban` / Decision `D-03-01`
- **Warum besser:** Im Ist-Zustand enthält 516-crowdsec.nix nur `crowdsecurity/caddy`. Ohne `crowdsecurity/http-probing` fehlt das Szenario `http-scan-uniques_404`, das wiederholte 404-Aufrufe unbekannter Subdomains detektiert. Die Erweiterung schließt die Detektionslücke der Ban-Kette.
- **Ist-Zustand:** `hub.collections = [ "crowdsecurity/caddy" ]; (Zeile 153).`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
hub.collections um "crowdsecurity/http-probing" erweitern.
```

### `S-03`: Ban-Dauer für Scanner im CrowdSec-Default-Profil von 4h auf 168h (7 Tage) verlängern.
- **Datei:** `/home/moritz/repos/mediNix-core/51-ingress/516-crowdsec.nix`
- **Quelle:** `03-crowdsec-scan-ban` / Decision `D-03-03`
- **Warum besser:** Scannende Bots wechseln ihre IPs nicht im 4-Stunden-Takt; 7 Tage Ban-Dauer hält wiederkehrende Scan-Wellen fern und entlastet das Log-Parsing nachhaltig.
- **Ist-Zustand:** `profiles.[0].decisions.[0].duration = "4h"; (Zeile 168).`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
Dauer auf duration = "168h" anheben oder Option `medinix.crowdsec.banDuration` einführen.
```

### `S-04`: Verschlüsselte `.cred`-Dateien dürfen NIEMALS in öffentliche Repositories committet werden (Schutz vor Harvest-Now-Decrypt-Later und Metadaten-Recon).
- **Datei:** `/home/moritz/repos/mediNix-core/.gitignore`
- **Quelle:** `04-credentials-systemd-creds` / Decision `D-04-03`
- **Warum besser:** Auch wenn .cred-Dateien mit TPM2+Hostkey hardwaregebunden sind, lecken sie Metadaten (Dienstnamen, Rotationszeitpunkte) und stellen ein HNDL-Risiko dar. Secrets verbleiben lokal in geschützten Pfaden (z.B. ~/.secrets/ oder privates Git).
- **Ist-Zustand:** `Schützt *.key, *.age, *.env; *.cred und *.encrypted fehlen bisher.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
*.cred und *.encrypted in .gitignore ergänzen.
```

### `S-05`: UDS nur für Dienste, die es nativ unterstützen. Pocket ID kann UDS (seit v2.18.0 wahrscheinlich bugfrei), oauth2-proxy ebenfalls. Keine socat-Bridges für Dienste, die es nicht können.
- **Datei:** `/home/moritz/repos/mediNix-core/51-ingress/512-pocket-id.nix`
- **Quelle:** `04-credentials-systemd-creds` / Decision `D-04-04`
- **Warum besser:** Pocket ID unterstützt UDS nativ (UNIX_SOCKET). Bug #1249 (Client-IPs leer) ist in Gin PR #3359 gefixt, wahrscheinlich in Pocket ID v2.18.0. oauth2-proxy unterstützt UDS ebenfalls nativ. Umstellung würde Defense-in-Depth verbessern. Test nötig.
- **Ist-Zustand:** `TCP-Loopback 127.0.0.1:5120. Kein UNIX_SOCKET konfiguriert.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
Testweise UNIX_SOCKET + TRUST_PROXY=true setzen, Audit-Log prüfen. Wenn IPs erscheinen: umstellen.
```

### `S-06`: UDS nur für Dienste, die es nativ unterstützen. Pocket ID kann UDS (seit v2.18.0 wahrscheinlich bugfrei), oauth2-proxy ebenfalls. Keine socat-Bridges für Dienste, die es nicht können.
- **Datei:** `/home/moritz/repos/mediNix-core/51-ingress/517-oauth2-proxy.nix`
- **Quelle:** `04-credentials-systemd-creds` / Decision `D-04-04`
- **Warum besser:** Pocket ID unterstützt UDS nativ (UNIX_SOCKET). Bug #1249 (Client-IPs leer) ist in Gin PR #3359 gefixt, wahrscheinlich in Pocket ID v2.18.0. oauth2-proxy unterstützt UDS ebenfalls nativ. Umstellung würde Defense-in-Depth verbessern. Test nötig.
- **Ist-Zustand:** `TCP-Loopback 127.0.0.1:5170.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
httpAddress = unix:///run/oauth2-proxy/oauth2-proxy.sock; 511 forward_auth-Upstream anpassen.
```

### `S-07`: mDNS/515 wird entfernt; Blocky übernimmt die interne Namensauflösung als Split-DNS.
- **Datei:** `/home/moritz/repos/mediNix-core/51-ingress/515-mdns.nix`
- **Quelle:** `05-mdns-vs-blocky` / Decision `D-05-01`
- **Warum besser:** Caddy rendert keine .local-Sites (laut README). Avahi publiziert nutzlose Records, erzeugt Multicast-Traffic (UDP 5353), bietet Angriffsfläche (historische CVEs) und startet einen Prozess pro Alias. Blocky ist bereits im Stack und kann Split-DNS zentral, auditierbar, subnetz-übergreifend.
- **Ist-Zustand:** `Avahi publiziert {service}.local via avahi-publish; systemd.paths auf /run/systemd/netif/leases restartet bei jeder Lease-Änderung. userServices = true publiziert alle User-Services, nicht nur mediNix.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
Modul entfernen oder per Option standardmäßig deaktivieren. 515-blocky.nix übernimmt Split-DNS.
```

### `S-08`: WAN-IP-Ermittlung: Externe Echo-Dienste (ifconfig.me, ipify.org) durch lokalen Router-Dispatch oder DNS-Query ablösen.
- **Datei:** `/home/moritz/repos/mediNix-core/51-ingress/513-cloudflare-dns.nix`
- **Quelle:** `06-dns-wan-ip-provider` / Decision `D-06-01`
- **Warum besser:** Im Ist-Zustand nutzt 513-cloudflare-dns.nix externe HTTP-Echo-Dienste (https://ifconfig.me, https://api.ipify.org). Diese erzeugen Drittanbieter-Abhängigkeiten, lecken IP-Abfragen und sind instabil (Captive Portals, Rate-Limits). Die lokale Abfrage des Routers oder ein direkter DoH/DNS-Query ist privatsphäreschonender und robuster.
- **Ist-Zustand:** `Nutzt for url in https://ifconfig.me https://api.ipify.org (Zeilen 188–195).`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
WAN_IP-Ermittlung auf modularen Provider-Dispatch (Router/DNS) umstellen. Speedport-Adapter: speedport-api public_ip_v4 via Default-Gateway.
```

### `S-09`: Keine festen Router-IPs hardcodieren: Der Router wird zur Laufzeit dynamisch als Default-Gateway aus der Routing-Tabelle ermittelt.
- **Datei:** `/home/moritz/repos/mediNix-core/51-ingress/513-cloudflare-dns.nix`
- **Quelle:** `06-dns-wan-ip-provider` / Decision `D-06-02`
- **Warum besser:** Ein Hardcodieren von 192.168.2.1 bricht sofort bei geändertem Subnetz oder Router-Tausch. Das Default-Gateway (ip route show default | awk '{print $3}') ist die einzige robuste Invariante für den Router-Zugriff.
- **Ist-Zustand:** `LAN_IP wird dynamisch ermittelt (ip route get 1.1.1.1); Router-IP ist noch nicht als Gateway-Variable abstrahiert.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
ROUTER_IP aus Default-Gateway ableiten für lokale Router-Abfragen.
```

### `S-10`: Modularen Provider-Dispatch für DDNS via `types.enum` anbieten (z. B. Speedport, FritzBox, DNS/DoH, External).
- **Datei:** `/home/moritz/repos/mediNix-core/51-ingress/513-cloudflare-dns.nix`
- **Quelle:** `06-dns-wan-ip-provider` / Decision `D-06-04`
- **Warum besser:** Ermöglicht den nahtlosen Router-Wechsel (z. B. Speedport zu FritzBox) über eine deklarative NixOS-Option, ohne Skripte im Modul umschreiben zu müssen.
- **Ist-Zustand:** `Feste for-Schleife mit ifconfig.me / ipify.org.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
Einführen von options.medinix.dns.ddns.wanIp.provider.
```

### `S-11`: Hybride Post-Quantum-Kex (`mlkem768x25519-sha256`) für SSH-Verbindungen als Standard etablieren.
- **Datei:** `/home/moritz/repos/mediNix-core/docs/adr/ADR-52-ssh-port-policy.md`
- **Quelle:** `07-pqc-hndl` / Decision `D-07-03`
- **Warum besser:** OpenSSH unterstützt ab Version 9.9/10.0 standardmäßig hybriden Schlüsselaustausch nach FIPS 203 (ML-KEM-768 + X25519). Dies schützt administrative SSH-Sessions gegen HNDL im Netzwerk-Traffic.
- **Ist-Zustand:** `Definiert Port-Policy und Key-Only Auth, aber noch keine explizite Kex-Vorgabe für PQC.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
Empfehlung für hybride PQC-Kex (mlkem768x25519) in SSH-Hardening ergänzen.
```

### `S-12`: Deklarativer Debug-Modus für Firewall: Umschaltbar auf REJECT mit Kernel-Logging für Diagnose-Zwecke.
- **Datei:** `/home/moritz/repos/mediNix-core/52-security/520-core-security.nix`
- **Quelle:** `08-firewall-nftables` / Decision `D-08-03`
- **Warum besser:** Beim Debuggen von Netzwerk- und VPN-Problemen führt Default-DROP zu zeitraubenden Timeouts. Ein umschaltbarer Schalter (z. B. `medinix.firewall.debugReject = true`), der `reject with icmpx type admin-prohibited` loggt, beschleunigt die Fehlersuche erheblich.
- **Ist-Zustand:** `recommended.firewall.checkReversePath deklariert; kein expliziter debugReject-Schalter vorhanden.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
Option für debugReject mit Log-Präfix zur Diagnose vorschlagen.
```

### `S-13`: Deklarative Kernel-Modul-Blacklist (`boot.blacklistedKernelModules`) und `security.lockKernelModules` gegen ungenutzte Angriffsflächen evaluieren.
- **Datei:** `/home/moritz/repos/mediNix-core/52-security/520-core-security.nix`
- **Quelle:** `09-kernel-hardening` / Decision `D-09-03`
- **Warum besser:** Im Chat (Nachrichten 100–101) fragte der Nutzer explizit nach Kernel-Blacklisten für Consumer-/Homelab-Hardware. Obskure Netzwerkprotokolle (dccp, sctp, rds, tipc), veraltete Dateisysteme oder ungenutzte Peripherietreiber können deklarativ geblockt werden. `security.lockKernelModules = true` sperrt das Nachladen nach dem Boot.
- **Ist-Zustand:** `Definiert medinix.recommended.sysctl, enthält aber noch keine Modul-Blacklist.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
Empfohlene Modul-Blacklist (z. B. medinix.recommended.blacklistedKernelModules) vorschlagen.
```

### `S-14`: CPU-Frequenzskalierung auf modernen `schedutil`-Governor setzen und dynamische Regelung via `auto-cpufreq` einsetzen (TLP deaktivieren).
- **Datei:** `/home/moritz/repos/mediNix-core/docs/adr/ADR-0003-architektur-manifest.md`
- **Quelle:** `10-power-management` / Decision `D-10-01`
- **Warum besser:** Auf einem Headless-Homelab-Server bietet schedutil in Verbindung mit auto-cpufreq eine blitzschnelle, bedarfsgerechte Skalierung ohne die Laptop-spezifischen Akku-Profile von TLP. TLP und auto-cpufreq schließen sich gegenseitig aus.
- **Ist-Zustand:** `Beschreibt mediNix-Appliance; Power-Management ist Host-Hoheit.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
Empfehlung für schedutil / auto-cpufreq in Host-Dokumentation aufnehmen.
```

### `S-15`: Intel GPU GuC/HuC Firmware-Laden (`i915.enable_guc=3`) für UHD 630 Hardware-Beschleunigung und Energieeffizienz aktivieren.
- **Datei:** `/home/moritz/repos/mediNix-core/docs/adr/ADR-551-jellyfin-media-playback.md`
- **Quelle:** `10-power-management` / Decision `D-10-02`
- **Warum besser:** Für Intel CPUs der 9. Generation (i3-9100 Coffee Lake) entlastet die GuC/HuC-Firmware die CPU bei Video-Transcoding (Jellyfin QuickSync) und verbessert die Energieverwaltung der GPU.
- **Ist-Zustand:** `Dokumentiert Jellyfin-Transcoding und Hardware-Beschleunigung.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
GuC/HuC Kernel-Parameter i915.enable_guc=3 als Host-Voraussetzung vermerken.
```

### `S-16`: Dezimal-Slot 515 für `515-blocky.nix` (internes Split-DNS) nachnutzen (UID 5150 via `mkNoPortWithUnit`, Port 53 manuell gesetzt).
- **Datei:** `/home/moritz/repos/mediNix-core/51-ingress/515-mdns.nix`
- **Quelle:** `11-51-tree-struktur` / Decision `D-11-01`
- **Warum besser:** mDNS (515-mdns.nix) ist tote Konfiguration und entfällt. Durch die Nachnutzung des Slots 515 für Blocky bleibt die dezimale Systematik der 51-Domäne (Access/Ingress) vollständig erhalten, ohne neue Fantasienummern einführen zu müssen.
- **Ist-Zustand:** `515-mdns.nix deklariert Avahi und mDNS-Publishing.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
515-mdns.nix durch 515-blocky.nix ersetzen (UID 5150, Port 53, Split-DNS).
```

### `S-17`: Vollständige Ausmusterung von `515-mdns.nix` (Avahi) aus dem 51-Ingress-Tree.
- **Datei:** `/home/moritz/repos/mediNix-core/51-ingress/515-mdns.nix`
- **Quelle:** `11-51-tree-struktur` / Decision `D-11-02`
- **Warum besser:** Caddy rendert bereits keine `.local`-Sites mehr. Avahi verbraucht Ressourcen und leckt interne Hostnamen im LAN. DNS-basierte Namensauflösung via Blocky ist deterministischer und plattformübergreifend kompatibel.
- **Ist-Zustand:** `Modul existiert im Repository.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
Modul löschen bzw. durch Blocky ersetzen.
```

### `S-18`: `513-cloudflare-dns.nix` auf reines WAN-DDNS beschränken und Router-Abstraktion nach `lib/wan-ip-provider.nix` auslagern.
- **Datei:** `/home/moritz/repos/mediNix-core/51-ingress/513-cloudflare-dns.nix`
- **Quelle:** `11-51-tree-struktur` / Decision `D-11-03`
- **Warum besser:** Das bisherige 513 vermischt WAN-DDNS, LAN-A-Records und HTTP-Echo-Abfragen. Die Trennung in reines WAN-DDNS und eine pure Router-Provider-Bibliothek erhöht die Wartbarkeit und verhindert Leaks privater IPs.
- **Ist-Zustand:** `Enthält LAN-Record-Logik und externe Web-Echo-Scripte.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
LAN-Publishing entfernen und WAN-IP-Ermittlung über Provider-Lib anbinden.
```

### `S-19`: Dezimalrahmen (ADR-0000) als universelles, fraktales Ordnungsprinzip für das gesamte Repository definieren, nicht nur für NixOS-Dienstmodule.
- **Datei:** `/home/moritz/repos/mediNix-core/docs/adr/ADR-0000-dezimalrahmen-verfassung.md`
- **Quelle:** `12-adr-dezimalrahmen` / Decision `D-12-01`
- **Warum besser:** Die Beschränkung auf reine Daemon-Module erzeugt künstliche Inkonsistenzen (z. B. Unsicherheit über die Rolle von Foundation, Hilfsdateien und Speicherorten). Das universelle Verständnis ordnet das gesamte System deterministisch.
- **Ist-Zustand:** `Formuliert Dezimalrahmen primär als Modul- und Port/UID-Matrix.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
Präambel erweitern: Dezimalrahmen als fraktales Dateisystem- und Ordnungsprinzip etablieren.
```

### `S-20`: Systematische Verortung von Credentials: Nicht-öffentliche Secrets werden in dedizierten Creds-Ordnern gebündelt, ohne den öffentlichen Modul-Baum zu kompromittieren.
- **Datei:** `/home/moritz/repos/mediNix-core/docs/adr/ADR-0000-dezimalrahmen-verfassung.md`
- **Quelle:** `12-adr-dezimalrahmen` / Decision `D-12-03`
- **Warum besser:** Die Speicherung von Credentials darf weder Magic Numbers noch unkontrollierte Ablagen im Git erzeugen. Ein dedizierter Slot oder gesonderter Creds-Pfad harmonisiert das Secret-Management mit der Dezimalphilosophie.
- **Ist-Zustand:** `Erwähnt Credentials noch nicht als eigene Strukturkomponente.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
Abschnitt über Credentials-Speicherorte und Secret-Pfade ergänzen.
```

### `S-21`: Caddy `customConfig`-Escape-Hatch strikt hinter Authentifizierungs- und Bouncer-Direktiven platzieren.
- **Datei:** `/home/moritz/repos/mediNix-core/51-ingress/511-caddy.nix`
- **Quelle:** `14-config-review-51-ingress` / Decision `D-14-01`
- **Warum besser:** Wird customConfig vor den Forward-Auth- oder CrowdSec-Blöcken gerendert, können fehlerhafte oder unvorsichtige Snippets den Zugriffsschutz für geschützte Backends komplett umgehen.
- **Ist-Zustand:** `Rendert customConfig an konfigurierbarer Stelle.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
customConfig zwingend nach forward_auth und IP-Filtering einsortieren.
```

### `S-22`: Semantische CIDR-Validierung im Ingress-Access-Layer anstelle von einfachen String-Präfix-Prüfungen implementieren.
- **Datei:** `/home/moritz/repos/mediNix-core/lib/ingress-access.nix`
- **Quelle:** `14-config-review-51-ingress` / Decision `D-14-02`
- **Warum besser:** Einfache String-Checks (z. B. auf '192.168.') erkennen ungültige Subnetzmasken nicht und können bei komplexen Netzwerkkonfigurationen fehlschlagen.
- **Ist-Zustand:** `KORREKTUR/KONFLIKT: lib/ingress-access.nix berechnet nur vHost-Access-Gruppen und enthält keine CIDR-Prüfungen. Die semantische CIDR-Validierung (Finding 4, Prefix-Grenzen /8-/32 und privater Regex) ist bereits in /home/moritz/repos/mediNix-core/51-ingress/511-caddy.nix (Zeilen 431–450) und im Optionstyp von /home/moritz/repos/mediNix-core/default.nix (Zeilen 400–415) vollständig umgesetzt.`
- **Soll-Vorgabe (Snippet / Änderung):**
```text
Keine Änderung in lib/ingress-access.nix nötig — semantische CIDR-Validierung liegt bereits in 511-caddy.nix und default.nix.
```

