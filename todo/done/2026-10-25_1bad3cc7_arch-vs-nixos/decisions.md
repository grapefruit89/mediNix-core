# Entscheidungs-Register (mediNix-core)

> Generiert am 2026-10-25 14:07:13 aus 14 Blöcken der Chat-Historie.

## Zusammenfassung

- **Blöcke:** 14
- **Entscheidungen gesamt:** 42
  - **Status:** 29 decided, 13 proposed, 0 rejected, 0 open
  - **Verdicts:** 22 better, 20 neutral (Status Quo), 0 worse, 0 unknown
- **Todos:** 24

## Detaillierte Entscheidungsliste

### Block `01-arch-vs-nixos`: Arch Linux vs. NixOS – Grundphilosophie, Immutabilität & Wartbarkeit
*Diskutiert die architektonischen und philosophischen Unterschiede zwischen Arch Linux (imperativ, Rolling Release, manuelle Disziplin, maximale Nutzersouveränität) und NixOS (deklarativ, atomare Upgrades, unveränderlicher Nix-Store, Git-versionierte Infrastruktur). Es wird geklärt, dass Passkeys/FIDO2 auf beiden Systemen unterstützt werden, NixOS jedoch strukturelle Konsistenzgarantien bietet. Ansible wird als Hilfsmittel für Arch diskutiert, aber nicht als Ersatz für NixOS.*

#### `D-01-01`: NixOS bleibt die verbindliche Betriebssystem-Basis für mediNix-core; Arch Linux oder imperative Distributionen werden nicht eingesetzt.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. NixOS bietet strukturelle Garantien (deklarative Konfiguration, atomare Upgrades, schreibgeschützter Nix-Store, Rollback-Fähigkeit), die den Wartungsaufwand im Homelab minimieren und Drift ausschließen.
- **Pro:** Deklarative Reproduzierbarkeit per Git, Atomare Upgrades und triviales Rollback, Isolierter, unveränderlicher /nix/store, Keine Konfigurationsdrift über Zeit
- **Con:** Steile Lernkurve für die Nix-Sprache, Höherer Speicherbedarf für Generationen vor Garbage Collection
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/flake.nix` (exists)
    - *Ist:* Flake-basierte NixOS-Konfiguration mit isolierten Modulen, Checks und CI-Gates.
    - *Soll:* Keine Änderung – Bestätigung des Architektur-Fundaments.
  - `/home/moritz/repos/mediNix-core/docs/adr/ADR-0003-architektur-manifest.md` (exists)
    - *Ist:* Deklaratives Architektur-Manifest für mediNix als reproduzierbare NixOS-Appliance.
    - *Soll:* Keine Änderung nötig.

#### `D-01-02`: Keine externen Konfigurationsmanagement-Tools (wie Ansible) für die Basis-Konfiguration von mediNix-core einsetzen.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. Ansible auf NixOS einzusetzen erzeugt zwei konkurrierende Wahrheitsquellen und bricht das deklarative Single-Source-of-Truth-Prinzip von NixOS.
- **Pro:** Einheitliche SSoT in Nix-Flakes, Keine Python-/SSH-Abhängigkeit auf dem Zielhost für das Konfigurationsmanagement, Konsistente State-Validierung vor dem Build
- **Con:** NixOS-spezifisches Wissen erforderlich
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/flake.nix` (exists)
    - *Ist:* Rein deklaratives Flake ohne imperative Provisioner.
    - *Soll:* Keine Änderung.

### Block `02-caddy-catch-all`: Caddy Catch-All für unbekannte Subdomains & TLS-Zertifikatsstrategie
*Behandelt den Umgang von Caddy mit unbekannten Subdomains (Catch-All) und Scannern sowie die TLS-Zertifikatsstrategie für interne Dienste. Unbekannte Subdomains werden als Scan-Verkehr eingestuft. Statuscodes 666 (nicht RFC-konform) und 403 (verrät Existenz) wurden verworfen. Im Code wurde für unbekannte Subdomains (*.${domain}) ein harter abort (TCP Connection Drop) in Caddy implementiert. Für interne Subdomains wurde tls internal (lokale CA mit manueller Trust-Verteilung auf Endgeräten) verworfen; stattdessen ist ACME DNS-01 mit echtem Zertifikat über Cloudflare gesetzt.*

#### `D-02-01`: Caddy Catch-All: `abort` durch `respond 404` ersetzen, damit CrowdSec Scan-Verkehr erkennt und bannen kann.
- **Status:** `decided` | **Verdict:** `better`
- **Rationale:** `abort` schließt TCP ohne HTTP-Status. CrowdSec-Szenario `http-scan-uniques_404` matcht auf 404 und feuert bei `abort` nie. `respond 404` liefert das nötige Signal für die Ban-Kette (CrowdSec → nftables-Bouncer).
- **Pro:** CrowdSec kann Scanner bannen, Ban-Kette funktioniert, Body kann 'Get off my lawn' enthalten
- **Con:** Scanner bekommt HTTP-Antwort statt TCP-Close (minimaler Info-Gewinn)
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/511-caddy.nix` (exists)
    - *Ist:* catchAllSites rendert 'abort' für *.${domain} (Zeilen ~339–348).
    - *Soll:* catchAllSites rendert 'respond "Get off my lawn" 404' für *.${domain}, sowohl HTTP als auch HTTPS.

#### `D-02-02`: Kein tls internal (lokale CA) für interne Dienste; stattdessen ACME DNS-01 Challenge für echte Zertifikate ohne manuelle CA-Installation.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. Status Quo im Code (514-acme.nix / 511-caddy.nix). Der Nutzer lehnt manuelle CA-Installation auf Endgeräten (Smartphones, TVs) strikt ab. ACME DNS-01 ermöglicht öffentlich vertrauenswürdige Zertifikate ohne Portweiterleitung.
- **Pro:** Keine manuelle Root-CA-Verteilung auf Endgeräten nötig, Funktioniert auf allen Smart-TVs und Mobilgeräten out-of-the-box, Kein offener Port 80/443 für HTTP-01/TLS-ALPN-01 nötig
- **Con:** Abhängigkeit von Cloudflare DNS API Token für die DNS-01 Challenge
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/514-acme.nix` (exists)
    - *Ist:* ACME-Konfiguration nutzt DNS-01 Provider Lego mit Cloudflare DNS.
    - *Soll:* Keine Änderung.
  - `/home/moritz/repos/mediNix-core/51-ingress/511-caddy.nix` (exists)
    - *Ist:* tlsDirective nutzt acme/certmagic Zertifikate oder Host-Zertifikate.
    - *Soll:* Keine Änderung.

### Block `03-crowdsec-scan-ban`: CrowdSec Scan-Erkennung & nftables-Bouncer Ban-Kette
*Beschreibt die vollständige Kette zur Abwehr und Sperrung von Scannern unbekannter Subdomains: Caddy fungiert als Sensor (liefert 404), CrowdSec als Detektor (erkennt Unique-404-Scans via Szenario http-scan-uniques_404) und der nftables-Bouncer als Aktor (sperrt die Angreifer-IP auf allen Ports in der Kernel-INPUT-Chain). Statuscodes 403 und 666 sowie HTTP-Tarpits wurden verworfen. Zur Komplettierung der Kette muss in 516-crowdsec.nix die Collection crowdsecurity/http-probing nachgerüstet werden.*

#### `D-03-01`: CrowdSec Hub-Collections um `crowdsecurity/http-probing` erweitern, um das Szenario `http-scan-uniques_404` zur Scan-Erkennung zu aktivieren.
- **Status:** `decided` | **Verdict:** `better`
- **Rationale:** Im Ist-Zustand enthält 516-crowdsec.nix nur `crowdsecurity/caddy`. Ohne `crowdsecurity/http-probing` fehlt das Szenario `http-scan-uniques_404`, das wiederholte 404-Aufrufe unbekannter Subdomains detektiert. Die Erweiterung schließt die Detektionslücke der Ban-Kette.
- **Pro:** Scan-Erkennung für unbekannte Subdomains greift zuverlässig, Vollständige Kette: Caddy (404) -> CrowdSec (Scan-Alert) -> nftables (Drop), Standard-Hub-Szenario ohne fragile Custom-Regeln
- **Con:** Minimaler Mehraufwand für Szenario-Download und Evaluation im CrowdSec-Daemon
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/516-crowdsec.nix` (exists)
    - *Ist:* hub.collections = [ "crowdsecurity/caddy" ]; (Zeile 153).
    - *Soll:* hub.collections um "crowdsecurity/http-probing" erweitern.

#### `D-03-02`: Firewall-Bouncer (nftables) als alleiniger Durchsetzungs-Aktor: Bans sperren Angreifer-IPs kernel-nah auf allen Ports (INPUT-Chain).
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. `services.crowdsec-firewall-bouncer` ist in `516-crowdsec.nix` bereits implementiert und sperrt IPs systemweit via nftables, sobald `hostIntegration.nftables == "managed"` gesetzt ist.
- **Pro:** Kernel-Drop auf allen Ports (SSH, HTTP, HTTPS), Keine Socket- oder CPU-Belastung im Webserver bei gebannten IPs, Zentraler Bouncer nach ADR-516 ohne App-Layer-Overhead
- **Con:** Erfordert Host-Hoheit über die Firewall (`hostIntegration.nftables = "managed"`)
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/516-crowdsec.nix` (exists)
    - *Ist:* services.crowdsec-firewall-bouncer ist aktiv mit settings.mode = 'nftables' und createRulesets = true.
    - *Soll:* Keine Änderung – Status Quo funktioniert wie entworfen.

#### `D-03-03`: Ban-Dauer für Scanner im CrowdSec-Default-Profil von 4h auf 168h (7 Tage) verlängern.
- **Status:** `proposed` | **Verdict:** `better`
- **Rationale:** Scannende Bots wechseln ihre IPs nicht im 4-Stunden-Takt; 7 Tage Ban-Dauer hält wiederkehrende Scan-Wellen fern und entlastet das Log-Parsing nachhaltig.
- **Pro:** Nachhaltiger Schutz gegen Botnetze, Entlastung von Caddy und CrowdSec, Weniger wiederholte Verbindungsversuche
- **Con:** Falls eine IP versehentlich gebannt wird (False Positive), ist die Sperre länger aktiv (erfordert manuelles cscli decisions delete)
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/516-crowdsec.nix` (exists)
    - *Ist:* profiles.[0].decisions.[0].duration = "4h"; (Zeile 168).
    - *Soll:* Dauer auf duration = "168h" anheben oder Option `medinix.crowdsec.banDuration` einführen.

### Block `04-credentials-systemd-creds`: systemd-creds Secret-Management, HNDL-Schutz & UDS-Architektur
*Definiert die verbindliche Secret-Architektur für mediNix-core: systemd-creds mit TPM2/Host-Key-Bindung ist der alleinige Standard; sops-nix und agenix sind verworfen. Strikte Granularität: Genau eine .cred-Datei pro Dienst (keine Sammel-Datei). Wegen Harvest-Now-Decrypt-Later (HNDL) und Metadaten-Recon dürfen auch verschlüsselte .cred-Dateien niemals in öffentliche Repositories committet werden. Unix Domain Sockets (UDS) werden nur dort genutzt, wo Upstream es nativ anbietet (Caddy Admin, ggf. oauth2-proxy); künstliche socat-Bridges vor Pocket ID werden als Over-Engineering verworfen.*

#### `D-04-01`: systemd-creds (mit TPM2 / Host-Key) als verbindlicher Secret-Standard; sops-nix und agenix werden verworfen.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. 521-creds.nix und ADR-521 setzen systemd-creds bereits verbindlich durch. Keine externen Binaries, keine GPG-Keyrings, native Einbindung via LoadCredentialEncrypted.
- **Pro:** Nativ in systemd integriert ohne externe KMS/GPG-Tools, Hardware-Bindung an TPM2 schützt vor Diebstahl des Blobs, Secrets landen niemals im Nix-Store oder in Umgebungsvariablen
- **Con:** Setzen des Namens-Parameters (--name) muss exakt mit LoadCredentialEncrypted übereinstimmen
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/52-security/521-creds.nix` (exists)
    - *Ist:* Erzwingt versiegelte systemd-creds (.encrypted/.cred) und verbietet Klartextdateien.
    - *Soll:* Keine Änderung – Status Quo ist verbindlich.
  - `/home/moritz/repos/mediNix-core/docs/adr/ADR-521-secret-management.md` (exists)
    - *Ist:* Verankert systemd-creds und verbietet sops-nix explizit.
    - *Soll:* Keine Änderung.

#### `D-04-02`: Strikte Granularität: Genau eine separate `.cred`-Datei pro Secret (keine Sammel-Passwort-Datei).
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. 521-creds.nix definiert bereits separate Dateien pro Dienst (sonarrApiKeyFile, jellyfinAdminPasswordFile, etc.). Verhindert, dass ein kompromittierter Dienst Zugriff auf die Secrets anderer Dienste erhält (Isolation / Least Privilege).
- **Pro:** Strikte Isolation: Dienste sehen nur ihre eigene Credential, Minimale Blast-Radius bei Kompromittierung eines Dienstes, Saubere Zuordnung im systemd-Creds-Verzeichnis
- **Con:** Mehrere .cred-Dateien müssen einzeln versiegelt werden
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/52-security/521-creds.nix` (exists)
    - *Ist:* Jedes Secret besitzt eine eigene Variable (sonarrApiKeyFile, jellyfinAdminPasswordFile, etc.).
    - *Soll:* Keine Änderung.

#### `D-04-03`: Verschlüsselte `.cred`-Dateien dürfen NIEMALS in öffentliche Repositories committet werden (Schutz vor Harvest-Now-Decrypt-Later und Metadaten-Recon).
- **Status:** `decided` | **Verdict:** `better`
- **Rationale:** Auch wenn .cred-Dateien mit TPM2+Hostkey hardwaregebunden sind, lecken sie Metadaten (Dienstnamen, Rotationszeitpunkte) und stellen ein HNDL-Risiko dar. Secrets verbleiben lokal in geschützten Pfaden (z.B. ~/.secrets/ oder privates Git).
- **Pro:** Schutz vor Harvest-Now-Decrypt-Later (HNDL) für verschlüsselte Blobs, Kein Metadaten-Leak über eingesetzte Dienste auf GitHub, Strikte Einhaltung der Sicherheitsregel (keine Secrets im öffentlichen Repo)
- **Con:** Erfordert separates lokales Secret-Handling oder privates Backup-Repo
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/52-security/521-creds.nix` (exists)
    - *Ist:* Pfade zu versiegelten .encrypted/.cred Blobs werden deklariert.
    - *Soll:* Keine Änderung.
  - `/home/moritz/repos/mediNix-core/.gitignore` (exists)
    - *Ist:* Schützt *.key, *.age, *.env; *.cred und *.encrypted fehlen bisher.
    - *Soll:* *.cred und *.encrypted in .gitignore ergänzen.

#### `D-04-04`: UDS nur für Dienste, die es nativ unterstützen. Pocket ID kann UDS (seit v2.18.0 wahrscheinlich bugfrei), oauth2-proxy ebenfalls. Keine socat-Bridges für Dienste, die es nicht können.
- **Status:** `proposed` | **Verdict:** `better`
- **Rationale:** Pocket ID unterstützt UDS nativ (UNIX_SOCKET). Bug #1249 (Client-IPs leer) ist in Gin PR #3359 gefixt, wahrscheinlich in Pocket ID v2.18.0. oauth2-proxy unterstützt UDS ebenfalls nativ. Umstellung würde Defense-in-Depth verbessern. Test nötig.
- **Pro:** Kein TCP-Loopback für Auth-Gatekeeper, Datei-Permissions als Zugangskontrolle
- **Con:** Bug-Risiko bei Pocket ID (Audit-Log-IPs leer, falls v2.18.0 den Fix nicht enthält), Test nötig
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/512-pocket-id.nix` (exists)
    - *Ist:* TCP-Loopback 127.0.0.1:5120. Kein UNIX_SOCKET konfiguriert.
    - *Soll:* Testweise UNIX_SOCKET + TRUST_PROXY=true setzen, Audit-Log prüfen. Wenn IPs erscheinen: umstellen.
  - `/home/moritz/repos/mediNix-core/51-ingress/517-oauth2-proxy.nix` (exists)
    - *Ist:* TCP-Loopback 127.0.0.1:5170.
    - *Soll:* httpAddress = unix:///run/oauth2-proxy/oauth2-proxy.sock; 511 forward_auth-Upstream anpassen.

### Block `05-mdns-vs-blocky`: mDNS/515 raus, Blocky als Split-DNS (Pilot)
*Avahi/mDNS (515-mdns.nix) ist in der aktuellen Caddy-Konfiguration bereits tote Konfiguration – 511-caddy.nix rendert keine .local-Sites (laut README: '511 renders NO Caddy site for .local'). Mit Blocky als internem Split-DNS ist mDNS redundant. Entscheidung: 515-mdns raus, Blocky übernimmt *.lan und *.m7c5.de → Caddy-IP. .lan und .{domain} bleiben die zwei Namensräume, beide in Caddy gerendert. Voraussetzung: .lan muss per Unicast-DNS aufgelöst werden (Blocky oder Speedport).*

#### `D-05-01`: mDNS/515 wird entfernt; Blocky übernimmt die interne Namensauflösung als Split-DNS.
- **Status:** `decided` | **Verdict:** `better`
- **Rationale:** Caddy rendert keine .local-Sites (laut README). Avahi publiziert nutzlose Records, erzeugt Multicast-Traffic (UDP 5353), bietet Angriffsfläche (historische CVEs) und startet einen Prozess pro Alias. Blocky ist bereits im Stack und kann Split-DNS zentral, auditierbar, subnetz-übergreifend.
- **Pro:** Avahi-Daemon raus, 20 avahi-publish-Prozesse raus, Kein Multicast-Traffic mehr, Zentrale, auditierbare Auflösung, Funktioniert über Subnetzgrenzen
- **Con:** .lan braucht DNS-Auflösung (Blocky oder Speedport), Geräte, die kein DNS nutzen (IoT mit hardcodiertem DNS), finden .lan nicht
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/515-mdns.nix` (exists)
    - *Ist:* Avahi publiziert {service}.local via avahi-publish; systemd.paths auf /run/systemd/netif/leases restartet bei jeder Lease-Änderung. userServices = true publiziert alle User-Services, nicht nur mediNix.
    - *Soll:* Modul entfernen oder per Option standardmäßig deaktivieren. 515-blocky.nix übernimmt Split-DNS.
  - `/home/moritz/repos/mediNix-core/51-ingress/511-caddy.nix` (exists)
    - *Ist:* Rendert http://{name}.lan (CIDR-gated via lanAbort) und https://{name}.{domain}. Rendert KEINE .local-Sites (laut README explizit).
    - *Soll:* Keine Änderung nötig – .lan bleibt, .{domain} bleibt.
  - `/home/moritz/repos/mediNix-core/lib/ingress-access.nix` (exists)
    - *Ist:* accessGroupOf, isWan, caddyUnitOf – wird von 511/513/518 genutzt.
    - *Soll:* Keine Änderung nötig.

#### `D-05-02`: .lan und .{domain} bleiben die beiden Namensräume. Keine .local-Sites in Caddy.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Der User wollte .local/mDNS löschen und durch {service}.lan ersetzen. Die Prüfung ergab: .local war nie in Caddy gerendert. .lan ist bereits der LAN-Namensraum, .{domain} der WAN-Namensraum. Keine neue Struktur nötig. (Status Quo, keine Änderung – verdict von better auf neutral korrigiert.)
- **Pro:** Zwei klar getrennte Namensräume, Weniger bewegliche Teile, Konsistenz mit bestehender 511-caddy.nix
- **Con:** keine
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/511-caddy.nix` (exists)
    - *Ist:* lanSites = http://{name}.lan, wanSites = https://{name}.{domain}, internalSites = https://{name}.{domain} + lanAbort.
    - *Soll:* Keine Änderung.

### Block `06-dns-wan-ip-provider`: DNS WAN-IP-Ermittlung, Router-Provider-Dispatch & RFC1918-Recon-Schutz
*Definiert die WAN- und LAN-IP-Ermittlung für Cloudflare DDNS (513) sowie den Schutz vor Reconnaissance. Externe Web-Echo-Dienste (ifconfig.me, ipify.org) sollen durch lokale Router-Abfragen (Speedport/Fritzbox) oder DNS-Resolver abgelöst werden. Die Router-IP darf nicht hartcodiert werden, sondern wird dynamisch als Default-Gateway ermittelt. Ein modularer Provider-Dispatch (types.enum) ermöglicht Router-Wechsel. publishLanRecord = false bleibt verbindlicher Standard, um RFC1918-Leaks in öffentlichem DNS (Recon-Gold) zu verhindern; interne Auflösung erfolgt strikt über Split-DNS.*

#### `D-06-01`: WAN-IP-Ermittlung: Externe Echo-Dienste (ifconfig.me, ipify.org) durch lokalen Router-Dispatch oder DNS-Query ablösen.
- **Status:** `proposed` | **Verdict:** `better`
- **Rationale:** Im Ist-Zustand nutzt 513-cloudflare-dns.nix externe HTTP-Echo-Dienste (https://ifconfig.me, https://api.ipify.org). Diese erzeugen Drittanbieter-Abhängigkeiten, lecken IP-Abfragen und sind instabil (Captive Portals, Rate-Limits). Die lokale Abfrage des Routers oder ein direkter DoH/DNS-Query ist privatsphäreschonender und robuster.
- **Pro:** Keine Datenleaks an fremde Web-Dienste (ifconfig.me), Unabhängig von HTTP-Rate-Limits externer Echo-Services, Schnellere und lokal auditierbare IP-Ermittlung
- **Con:** Erfordert router-spezifische Implementierung (Speedport/Fritzbox)
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/513-cloudflare-dns.nix` (exists)
    - *Ist:* Nutzt for url in https://ifconfig.me https://api.ipify.org (Zeilen 188–195).
    - *Soll:* WAN_IP-Ermittlung auf modularen Provider-Dispatch (Router/DNS) umstellen. Speedport-Adapter: speedport-api public_ip_v4 via Default-Gateway.

#### `D-06-02`: Keine festen Router-IPs hardcodieren: Der Router wird zur Laufzeit dynamisch als Default-Gateway aus der Routing-Tabelle ermittelt.
- **Status:** `decided` | **Verdict:** `better`
- **Rationale:** Ein Hardcodieren von 192.168.2.1 bricht sofort bei geändertem Subnetz oder Router-Tausch. Das Default-Gateway (ip route show default | awk '{print $3}') ist die einzige robuste Invariante für den Router-Zugriff.
- **Pro:** Portabel über unterschiedliche IP-Bereiche und Subnetze, Keine Magic Numbers im Nix-Code, Übersteht Subnetzänderungen ohne Rebuild
- **Con:** Minimaler Shell-Aufruf zur Laufzeit nötig
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/513-cloudflare-dns.nix` (exists)
    - *Ist:* LAN_IP wird dynamisch ermittelt (ip route get 1.1.1.1); Router-IP ist noch nicht als Gateway-Variable abstrahiert.
    - *Soll:* ROUTER_IP aus Default-Gateway ableiten für lokale Router-Abfragen.

#### `D-06-03`: publishLanRecord = false bleibt Standard: Keine RFC1918-Adressen in öffentlichem Cloudflare-DNS publizieren (Schutz vor Recon-Gold).
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. 513-cloudflare-dns.nix publiziert RFC1918-Records nur bei explizitem Opt-In. Interne Namen gehören ins Split-DNS (Blocky), nicht in öffentliche DNS-Zonen, da sie Angreifern die interne Netzwerktopologie verraten würden.
- **Pro:** Keine Preisgabe interner IP-Adressen an die Öffentlichkeit, Schutz vor DNS-Reconnaissance, Klare Trennung zwischen öffentlichem WAN-Anchor und lokalem DNS
- **Con:** LAN-Zugriff erfordert funktionierenden internen DNS-Resolver (Blocky)
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/513-cloudflare-dns.nix` (exists)
    - *Ist:* publishLanRecord ist optional und standardmäßig inaktiv.
    - *Soll:* Keine Änderung.
  - `/home/moritz/repos/mediNix-core/docs/adr/ADR-513-cloudflare-dns.md` (exists)
    - *Ist:* Dokumentiert gray-cloud DNS-only Architektur.
    - *Soll:* Keine Änderung.

#### `D-06-04`: Modularen Provider-Dispatch für DDNS via `types.enum` anbieten (z. B. Speedport, FritzBox, DNS/DoH, External).
- **Status:** `proposed` | **Verdict:** `better`
- **Rationale:** Ermöglicht den nahtlosen Router-Wechsel (z. B. Speedport zu FritzBox) über eine deklarative NixOS-Option, ohne Skripte im Modul umschreiben zu müssen.
- **Pro:** Erweiterbare Architektur für verschiedene Router-Modelle, Deklarative Umschaltung via NixOS-Option, Fallback auf DoH/DNS wenn Router keine API bietet
- **Con:** Zusätzliche Optionen und Implementierungsaufwand für Adapter
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/513-cloudflare-dns.nix` (exists)
    - *Ist:* Feste for-Schleife mit ifconfig.me / ipify.org.
    - *Soll:* Einführen von options.medinix.dns.ddns.wanIp.provider.

### Block `07-pqc-hndl`: Post-Quantum-Kryptografie (PQC) & Harvest-Now-Decrypt-Later (HNDL) Analyse
*Analysiert die Bedrohung durch Harvest-Now-Decrypt-Later (HNDL) im Kontext von Git-Repos und Secret-Management sowie den aktuellen Stand standardisierter Post-Quantum-Kryptografie (NIST FIPS 203/204/205). Agenix mit ssh-ed25519 auf GitHub ist anfällig für HNDL. Reine PQC-Verschlüsselung existiert in aktuellen Toolstacks noch nicht produktiv, sondern nur als hybride Verfahren (OpenSSH mlkem768x25519 für Kex, age v1.3+ hybrid). systemd-creds ist zwar nicht PQC-algorithmisch, neutralisiert HNDL jedoch durch physische Hardware-Bindung an den lokalen TPM2-Chip, solange Blobs nicht öffentlich hochgeladen werden.*

#### `D-07-01`: Verzicht auf Agenix wegen fehlender PQC-Fähigkeit und HNDL-Gefahr bei asymmetrisch verschlüsselten Git-Secrets.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. Agenix nutzt klassische SSH-Public-Keys (Ed25519/RSA), die von Quantencomputern gebrochen werden können. Auf GitHub abgelegte Ciphertexte sind ein direktes HNDL-Ziel.
- **Pro:** Keine HNDL-exponierten verschlüsselten Secrets in Git, Kein Vertrauen auf ungehärtete asymmetrische Verschlüsselung, Reduktion externer Tool-Abhängigkeiten
- **Con:** Keine rein Git-basierte Secret-Synchronisation zwischen Nodes
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/docs/adr/ADR-521-secret-management.md` (exists)
    - *Ist:* Schließt sops/age/agenix aus und setzt auf systemd-creds.
    - *Soll:* Keine Änderung.

#### `D-07-02`: systemd-creds mit TPM2+Hostkey als HNDL-Resistenz durch Hardware-Bindung (keine algorithmische PQC, aber physikalische Bindung).
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. Ein Angreifer kann ohne Zugriff auf den physischen TPM2-Chip des Hosts die .cred-Dateien nicht entschlüsseln. Die Hardware-Bindung neutralisiert HNDL für lokale Offline-Blobs.
- **Pro:** Physische Bindung verhindert Entschlüsselung auf fremden Maschinen, Unabhängig von zukünftigen Kryptoanalysen klassischer Kurven solange TPM2 intakt ist, Nativ im Linux-Ökosystem
- **Con:** Nicht exportierbar auf andere Hardware ohne Neu-Verschlüsselung, Keine mathematische PQC-Garantie
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/52-security/521-creds.nix` (exists)
    - *Ist:* Deklariert versiegelte .encrypted/.cred Pfade.
    - *Soll:* Keine Änderung.

#### `D-07-03`: Hybride Post-Quantum-Kex (`mlkem768x25519-sha256`) für SSH-Verbindungen als Standard etablieren.
- **Status:** `proposed` | **Verdict:** `better`
- **Rationale:** OpenSSH unterstützt ab Version 9.9/10.0 standardmäßig hybriden Schlüsselaustausch nach FIPS 203 (ML-KEM-768 + X25519). Dies schützt administrative SSH-Sessions gegen HNDL im Netzwerk-Traffic.
- **Pro:** Netzwerk-Traffic gegen HNDL geschützt, NIST-standardisiertes FIPS-203-Verfahren, Hybrid: Sicherheit wenn mindestens ein Algorithmus hält
- **Con:** Minimal größere SSH-Handshake-Pakete
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/docs/adr/ADR-52-ssh-port-policy.md` (exists)
    - *Ist:* Definiert Port-Policy und Key-Only Auth, aber noch keine explizite Kex-Vorgabe für PQC.
    - *Soll:* Empfehlung für hybride PQC-Kex (mlkem768x25519) in SSH-Hardening ergänzen.

### Block `08-firewall-nftables`: nftables Firewall-Architektur, Default-DROP Policy & Debug-Reject Modus
*Definiert die Firewall-Architektur für mediNix-core: Reine deklarative nftables-Firewall ohne iptables-Altlasten. Standard-Policy ist striktes Fail-Closed (Default-DROP) auf der INPUT-Chain für alle unberechtigten Ports. Für Troubleshooting wird ein umschaltbarer Debug-Modus diskutiert, der gezielt REJECT mit Logging (systemd-journald / journalctl -k) ausgibt, anstatt Pakete stumm zu verwerfen. iptables ist unter NixOS lediglich ein Wrapper um nftables; die Steuerung erfolgt über deklarative Tabellen und den CrowdSec-Bouncer.*

#### `D-08-01`: Striktes Fail-Closed (Default-DROP) auf allen unberechtigten eingehenden Ports via nftables.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. ADR-5210 und 520-core-security.nix erzwingen Default-DROP für den WAN-Verkehr. Nur explizit erlaubte TCP-Ports (allowedTCPPorts) werden geöffnet.
- **Pro:** Maximaler Schutz gegen Port-Scanning und unautorisierte Dienste, Keine stillschweigend offenen Ports, Konsistent mit Fail-Closed-Doktrin
- **Con:** Debugging von Verbindungsproblemen schwieriger, da keine ICMP-Rückmeldung erfolgt
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/docs/adr/ADR-5210-nftables-firewall-baseline.md` (exists)
    - *Ist:* Definiert nftables-Baseline mit Default-DROP auf WAN.
    - *Soll:* Keine Änderung.
  - `/home/moritz/repos/mediNix-core/52-security/520-core-security.nix` (exists)
    - *Ist:* Enthält Guardrails für hostIntegration.firewall = managed XOR hostIntegration.nftables = managed.
    - *Soll:* Keine Änderung.

#### `D-08-02`: Reines nftables-Backend ohne legacy iptables-Kommandos verwenden.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. iptables ist in modernen NixOS-Versionen nur ein Kompatibilitäts-Wrapper. Direkte nftables-Nutzung verhindert Regelsatz-Konflikte und Drift.
- **Pro:** Atomare Regelsatz-Aktualisierung, Einheitliche Syntax für IPv4 und IPv6, Keine iptables-Drift
- **Con:** Erfordert nftables-Kenntnisse für manuelle Inspektion (nft list ruleset)
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/docs/adr/ADR-5210-nftables-firewall-baseline.md` (exists)
    - *Ist:* Verbietet imperative iptables-Kommandos.
    - *Soll:* Keine Änderung.

#### `D-08-03`: Deklarativer Debug-Modus für Firewall: Umschaltbar auf REJECT mit Kernel-Logging für Diagnose-Zwecke.
- **Status:** `proposed` | **Verdict:** `better`
- **Rationale:** Beim Debuggen von Netzwerk- und VPN-Problemen führt Default-DROP zu zeitraubenden Timeouts. Ein umschaltbarer Schalter (z. B. `medinix.firewall.debugReject = true`), der `reject with icmpx type admin-prohibited` loggt, beschleunigt die Fehlersuche erheblich.
- **Pro:** Sofortiges Feedback bei geblockten Verbindungen, Auditierbare Log-Meldungen in journalctl -k, Verhindert langes Warten auf Timeouts
- **Con:** Im Produktivbetrieb unerwünscht, da REJECT dem Scanner antwortet
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/52-security/520-core-security.nix` (exists)
    - *Ist:* recommended.firewall.checkReversePath deklariert; kein expliziter debugReject-Schalter vorhanden.
    - *Soll:* Option für debugReject mit Log-Präfix zur Diagnose vorschlagen.

### Block `09-kernel-hardening`: Kernel-Hardening: Konsumer-Profile, Sysctl-Härtung & Keine Custom Patches
*Definiert den Kernel-Hardening-Ansatz für mediNix-core auf Konsumer-Hardware: Eigene Kernel-Patches oder manuelle Kernel-Kompilierungen werden explizit abgelehnt (Wartungsaufwand, Inkompatibilitäten). Stattdessen setzt das Projekt auf standardisierte NixOS-Mechanismen: `medinix.recommended.sysctl` (kptr_restrict, dmesg_restrict, kexec_load_disabled, yama.ptrace_scope), systemd-Sandbox-Direktiven (seccomp SystemCallFilter, ProtectSystem) und optional fertige Distribution-Kernel (pkgs.linuxPackages_hardened). Kernel-Blacklists verhindern das Laden veralteter oder riskanter Module.*

#### `D-09-01`: Keine eigenen Kernel-Patches (`boot.kernelPatches`) kompilieren; stattdessen Standard-Kernel mit deklarativen Sysctl- und Modul-Härtungen nutzen.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. Eigene Kernel-Patches brechen Binärcaches, verlängern Buildzeiten drastisch und erfordern ständige Upstream-Pflege. Für Konsumer-Homelab-Hardware reicht die Konfiguration fertiger Parameter.
- **Pro:** Schnelle Updates via Binärcache ohne lokale Kernel-Kompilierung, Keine Pflege eigener C-Patches, Hohe Hardware-Kompatibilität
- **Con:** Keine experimentellen Kernel-Compiler-Flags (z.B. spezielle Clang-Sanitizer)
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/52-security/520-core-security.nix` (exists)
    - *Ist:* Definiert empfohlene Sysctl-Werte (kptr_restrict=2, dmesg_restrict=1, kexec_load_disabled=1, ptrace_scope=1).
    - *Soll:* Keine Änderung.
  - `/home/moritz/repos/mediNix-core/docs/adr/ADR-5200-privesc-audit-hardening.md` (exists)
    - *Ist:* Dokumentiert Host-Baseline und Privesc-Härtung.
    - *Soll:* Keine Änderung.

#### `D-09-02`: Verteidigungsschichten über systemd-Sandboxing (seccomp, ProtectSystem, UPG) statt Kernel-Rekompilierung.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. ADR-5050 erzwingt die 5 systemd-Hardening-Säulen für alle Dienste. Seccomp-Filter und Filesystem-Isolation schützen das System prozess-nah ohne Kernel-Bruch.
- **Pro:** Granulare Isolation pro Dienst, Fehler in einem Dienst gefährden nicht den Host, Nativ in systemd ohne Performance-Verlust
- **Con:** Aufwändige Pflege von Hardening-Profilen bei neuen Diensten
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/docs/adr/ADR-5050-systemd-hardening-baseline.md` (exists)
    - *Ist:* Erzwingt die 5 Säulen des systemd-Hardenings.
    - *Soll:* Keine Änderung.
  - `/home/moritz/repos/mediNix-core/lib/service-factory.nix` (exists)
    - *Ist:* Injiziert Profile (base, web, dotnet, nodejs) mit seccomp und systemd-Schutz.
    - *Soll:* Keine Änderung.

#### `D-09-03`: Deklarative Kernel-Modul-Blacklist (`boot.blacklistedKernelModules`) und `security.lockKernelModules` gegen ungenutzte Angriffsflächen evaluieren.
- **Status:** `proposed` | **Verdict:** `better`
- **Rationale:** Im Chat (Nachrichten 100–101) fragte der Nutzer explizit nach Kernel-Blacklisten für Consumer-/Homelab-Hardware. Obskure Netzwerkprotokolle (dccp, sctp, rds, tipc), veraltete Dateisysteme oder ungenutzte Peripherietreiber können deklarativ geblockt werden. `security.lockKernelModules = true` sperrt das Nachladen nach dem Boot.
- **Pro:** Reduziert Kernel-Angriffsfläche ohne Rebuild des Kernels, Verhindert automatisches Laden angreifbarer Legacy-Protokolle, Kombinierbar mit Standard-Kernel
- **Con:** Kann Hardware-Hotplugging oder spezielle VPN-/Tunnelmodule blockieren, wenn nicht sorgfältig kuratiert
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/52-security/520-core-security.nix` (exists)
    - *Ist:* Definiert medinix.recommended.sysctl, enthält aber noch keine Modul-Blacklist.
    - *Soll:* Empfohlene Modul-Blacklist (z. B. medinix.recommended.blacklistedKernelModules) vorschlagen.

### Block `10-power-management`: Power-Management & On-Demand Effizienz für Intel i3-9100 / UHD 630
*Definiert die Power-Management- und Effizienzstrategie für den Homelab-Host (Fujitsu Esprimo Q958 mit Intel Core i3-9100 und integrierter Intel UHD 630 GPU). Ziel ist dynamische On-Demand-Leistung im Leerlauf ohne dauerhafte 100%-Taktung. Empfohlenes Setup: CPU-Governor schedutil (integriert in Linux-Scheduler), auto-cpufreq für dynamische Lastskalierung (TLP ausschließen), Intel GuC/HuC Firmware-Aktivierung via i915.enable_guc=3 für GPU-Effizienz und Hardware-Transcoding, sowie Spindown-Schutz für ruhende Platten. PSR und FBC sollen nicht manuell forciert werden.*

#### `D-10-01`: CPU-Frequenzskalierung auf modernen `schedutil`-Governor setzen und dynamische Regelung via `auto-cpufreq` einsetzen (TLP deaktivieren).
- **Status:** `proposed` | **Verdict:** `better`
- **Rationale:** Auf einem Headless-Homelab-Server bietet schedutil in Verbindung mit auto-cpufreq eine blitzschnelle, bedarfsgerechte Skalierung ohne die Laptop-spezifischen Akku-Profile von TLP. TLP und auto-cpufreq schließen sich gegenseitig aus.
- **Pro:** Extrem geringer Stromverbrauch und Abwärme im Leerlauf, Volle CPU-Leistung bei Last (z. B. Entpacken, Transcoding), Scheduler-native Skalierung ohne Userspace-Polling-Verzögerung
- **Con:** auto-cpufreq und TLP dürfen niemals gleichzeitig aktiv sein (Konflikt)
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/docs/adr/ADR-0003-architektur-manifest.md` (exists)
    - *Ist:* Beschreibt mediNix-Appliance; Power-Management ist Host-Hoheit.
    - *Soll:* Empfehlung für schedutil / auto-cpufreq in Host-Dokumentation aufnehmen.

#### `D-10-02`: Intel GPU GuC/HuC Firmware-Laden (`i915.enable_guc=3`) für UHD 630 Hardware-Beschleunigung und Energieeffizienz aktivieren.
- **Status:** `proposed` | **Verdict:** `better`
- **Rationale:** Für Intel CPUs der 9. Generation (i3-9100 Coffee Lake) entlastet die GuC/HuC-Firmware die CPU bei Video-Transcoding (Jellyfin QuickSync) und verbessert die Energieverwaltung der GPU.
- **Pro:** Hardware-beschleunigtes Transcoding in Jellyfin, Geringere CPU-Auslastung bei Medienwiedergabe, Erweiterte Energiesparmodi der GPU
- **Con:** Erfordert redistributable Firmware im Kernel
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/docs/adr/ADR-551-jellyfin-media-playback.md` (exists)
    - *Ist:* Dokumentiert Jellyfin-Transcoding und Hardware-Beschleunigung.
    - *Soll:* GuC/HuC Kernel-Parameter i915.enable_guc=3 als Host-Voraussetzung vermerken.

#### `D-10-03`: Keine manuellen Overrides für `i915.enable_psr` oder `i915.enable_fbc` setzen.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. Der Kernel verwaltet Panel Self Refresh und Framebuffer Compression ab der 8. Intel-Generation automatisch; manuelle Overrides führen auf Headless-Systemen häufig zu Instabilitäten oder Kernel-Panics.
- **Pro:** Stabiler Betrieb ohne Display-Subsystem-Crashes, Keine unnötigen Kernel-Parameter
- **Con:** keine
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/50-core/500-host-baseline.nix` (exists)
    - *Ist:* Definiert Host-Hygiene; keine manuellen i915-Flags deklariert.
    - *Soll:* Keine Änderung.

### Block `11-51-tree-struktur`: 51-ingress Ordner-Restrukturierung: 515-blocky, 513-DDNS, Lib-Auslagerung
*Definiert den bereinigten Zielbaum für den Ordner 51-ingress nach der Ausmusterung von Avahi/mDNS. Slot 515 wird für 515-blocky.nix (internes Split-DNS) nachgenutzt (UID 5150 via mkNoPortWithUnit, Port 53 manuell gesetzt). 513-cloudflare-dns.nix wird auf reines WAN-DDNS beschränkt (Entfall von publishLanRecord). Die WAN-IP-Ermittlung wird als lib/wan-ip-provider.nix ausgelagert. Das ACME DNS-01 Zertifikats-Handling und CrowdSec bleiben in ihren Dezimalslots erhalten.*

#### `D-11-01`: Dezimal-Slot 515 für `515-blocky.nix` (internes Split-DNS) nachnutzen (UID 5150 via `mkNoPortWithUnit`, Port 53 manuell gesetzt).
- **Status:** `proposed` | **Verdict:** `better`
- **Rationale:** mDNS (515-mdns.nix) ist tote Konfiguration und entfällt. Durch die Nachnutzung des Slots 515 für Blocky bleibt die dezimale Systematik der 51-Domäne (Access/Ingress) vollständig erhalten, ohne neue Fantasienummern einführen zu müssen.
- **Pro:** Behält den strengen Dezimalrahmen (51x für Ingress) bei, Nutzt freiwerdenden Slot 515 sinnvoll nach, Deterministische UID 5150 für den Blocky-Dienst
- **Con:** Port 53 kann wegen Privilegierung (<1024) nicht direkt als 5150 abgeleitet werden, sondern muss manuell deklariert werden
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/515-mdns.nix` (exists)
    - *Ist:* 515-mdns.nix deklariert Avahi und mDNS-Publishing.
    - *Soll:* 515-mdns.nix durch 515-blocky.nix ersetzen (UID 5150, Port 53, Split-DNS).

#### `D-11-02`: Vollständige Ausmusterung von `515-mdns.nix` (Avahi) aus dem 51-Ingress-Tree.
- **Status:** `decided` | **Verdict:** `better`
- **Rationale:** Caddy rendert bereits keine `.local`-Sites mehr. Avahi verbraucht Ressourcen und leckt interne Hostnamen im LAN. DNS-basierte Namensauflösung via Blocky ist deterministischer und plattformübergreifend kompatibel.
- **Pro:** Entfernt ungenutzte Hintergrunddienste (Avahi-Daemon), Beseitigt mDNS-Multicast-Chatter im Heimnetz, Verhindert Verwirrung durch parallele .local-Domains
- **Con:** Erfordert funktionierenden Split-DNS-Server im LAN
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/515-mdns.nix` (exists)
    - *Ist:* Modul existiert im Repository.
    - *Soll:* Modul löschen bzw. durch Blocky ersetzen.

#### `D-11-03`: `513-cloudflare-dns.nix` auf reines WAN-DDNS beschränken und Router-Abstraktion nach `lib/wan-ip-provider.nix` auslagern.
- **Status:** `proposed` | **Verdict:** `better`
- **Rationale:** Das bisherige 513 vermischt WAN-DDNS, LAN-A-Records und HTTP-Echo-Abfragen. Die Trennung in reines WAN-DDNS und eine pure Router-Provider-Bibliothek erhöht die Wartbarkeit und verhindert Leaks privater IPs.
- **Pro:** Single Responsibility Principle für 513, Keine RFC1918-Leaks mehr in öffentlichen Cloudflare-Zonen, Wiederverwendbare Provider-Bibliothek für unterschiedliche Router
- **Con:** Aufteilung in zwei Dateien statt eines monolithischen Skripts
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/513-cloudflare-dns.nix` (exists)
    - *Ist:* Enthält LAN-Record-Logik und externe Web-Echo-Scripte.
    - *Soll:* LAN-Publishing entfernen und WAN-IP-Ermittlung über Provider-Lib anbinden.

### Block `12-adr-dezimalrahmen`: ADR-0000 Dezimalrahmen: Universelles Dateisystem- & Ordnungsprinzip
*Grundsatzdiskussion über die philosophische Tragweite des Dezimalrahmens (ADR-0000). Der Nutzer stellt klar, dass der Dezimalrahmen kein reines Modul-Schema für Daemons ist, sondern ein universelles, fraktales bzw. dendritisches Dateisystem- und Organisationsprinzip für das gesamte mediNix-Projekt. Dies umfasst die Zuordnung von Basis- und Hilfsstrukturen (Foundation), die Eliminierung von Magic Numbers durch Berechnungsregeln (number * 10) und die zukünftige systematische Verortung von Credentials.*

#### `D-12-01`: Dezimalrahmen (ADR-0000) als universelles, fraktales Ordnungsprinzip für das gesamte Repository definieren, nicht nur für NixOS-Dienstmodule.
- **Status:** `decided` | **Verdict:** `better`
- **Rationale:** Die Beschränkung auf reine Daemon-Module erzeugt künstliche Inkonsistenzen (z. B. Unsicherheit über die Rolle von Foundation, Hilfsdateien und Speicherorten). Das universelle Verständnis ordnet das gesamte System deterministisch.
- **Pro:** Einheitliche mentale Ordnung für alle Systemteile, Klarheit über Verortung von Hilfsdateien, Dokumentation und Konfiguration, Vermeidet Sonderlocken und unorganisierte Ordnerablagen
- **Con:** Erfordert konsequente Disziplin bei der Namensgebung im gesamten Projekt
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/docs/adr/ADR-0000-dezimalrahmen-verfassung.md` (exists)
    - *Ist:* Formuliert Dezimalrahmen primär als Modul- und Port/UID-Matrix.
    - *Soll:* Präambel erweitern: Dezimalrahmen als fraktales Dateisystem- und Ordnungsprinzip etablieren.

#### `D-12-02`: Eliminierung von Magic Numbers: Ports und UIDs werden ausnahmslos als Funktion der Dienstnummer (`derivation = number * 10`) berechnet.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. ADR-0000 erzwingt bereits die mathematische Ableitung, um Kollisionen im gesamten Homelab-Cluster rechnerisch auszuschließen.
- **Pro:** Mathematisch kollisionsfreie Zuweisung im Bereich 5000–5999, Keine händischen Port-Listen nötig, Koppelt Service-Identität fest an UID und Port
- **Con:** Standardports müssen via Reverse-Proxy oder Ausnahmeregelung (z.B. Port 53) gemappt werden
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/50-core/501-decimal-engine.nix` (exists)
    - *Ist:* Enthält mathematische Validierungs- und Ableitungsfunktionen.
    - *Soll:* Keine Änderung.
  - `/home/moritz/repos/mediNix-core/lib/derive.nix` (exists)
    - *Ist:* Implementiert derivePort, deriveUid, deriveGid.
    - *Soll:* Keine Änderung.

#### `D-12-03`: Systematische Verortung von Credentials: Nicht-öffentliche Secrets werden in dedizierten Creds-Ordnern gebündelt, ohne den öffentlichen Modul-Baum zu kompromittieren.
- **Status:** `proposed` | **Verdict:** `better`
- **Rationale:** Die Speicherung von Credentials darf weder Magic Numbers noch unkontrollierte Ablagen im Git erzeugen. Ein dedizierter Slot oder gesonderter Creds-Pfad harmonisiert das Secret-Management mit der Dezimalphilosophie.
- **Pro:** Strikte Isolation von sensiblen Daten, Klare Ignoriervorschriften in .gitignore, Strukturierte Ablage nach Dezimalnummern
- **Con:** Erfordert saubere Trennung zwischen Deklaration und Schlüsselmaterial
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/docs/adr/ADR-0000-dezimalrahmen-verfassung.md` (exists)
    - *Ist:* Erwähnt Credentials noch nicht als eigene Strukturkomponente.
    - *Soll:* Abschnitt über Credentials-Speicherorte und Secret-Pfade ergänzen.

### Block `13-lib-vs-50-core`: Architektur-Trennung: Top-Level lib/ vs. 50-core & Auto-Discovery von Modulen
*Klärt die architektonische Abgrenzung zwischen dem Top-Level-Ordner lib/ und der Domäne 50-core/. Der Nutzer hinterfragt die Notwendigkeit von lib/ und schlägt die Eingliederung in 50-core/ als universelle Basis vor. Die Analyse zeigt: lib/ enthält pure Nix-Funktionen (Berechnungen, Registry, Hardening-Profile), während 50-core/ NixOS-Module mit systemd-Units und Optionen deklariert. Ein automatischer Import von Modulen existiert bereits via builtins.readDir in default.nix. Pure Funktionen können nicht blind wie Plugins auto-geladen werden, da Nix strikt funktional evaluiert.*

#### `D-13-01`: Trennung zwischen reiner Funktionsbibliothek (`lib/`) und NixOS-Host-Modulen (`50-core/`) architektonisch beibehalten.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. lib/ enthält zustandslose, pure Nix-Hilfsfunktionen ohne Systemzustand. 50-core/ deklariert NixOS-Optionen und Systemd-Dienste. Das Mischen von Modulen und Utility-Funktionen würde den NixOS-Modul-Parser verlangsamen und Zyklen begünstigen.
- **Pro:** Klare Trennung: Pure Functions (Berechnung) vs. NixOS Modules (Systemzustand), Ermöglicht isoliertes Unit-Testing reiner Funktionen, Kein Mischen von Evaluierungszeitpunkten
- **Con:** Zwei Einstiegspunkte im Root-Verzeichnis (lib/ und 50-core/)
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/lib/registry.nix` (exists)
    - *Ist:* Pure Nix-Attributmenge der Dienste.
    - *Soll:* Keine Änderung.
  - `/home/moritz/repos/mediNix-core/50-core/500-host-baseline.nix` (exists)
    - *Ist:* NixOS-Modul mit options und config.
    - *Soll:* Keine Änderung.

#### `D-13-02`: Auto-Import in `default.nix` bleibt auf standardisierte Dienstmodule (`XX-domain/NNN-*.nix`) beschränkt.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. default.nix durchsucht via builtins.readDir automatisch alle Domänenordner nach Moduldateien. Ein blindes Einhängen von Bibliotheken ohne Modul-Signatur ({ config, lib, pkgs, ... }) würde zu Parsing-Fehlern führen.
- **Pro:** Robuste und vorhersagbare Modul-Evaluation, Keine Parsing-Crashes bei Daten- oder Funktionsdateien, Volle Kompatibilität mit dem NixOS-Modulsystem
- **Con:** Hilfsfunktionen müssen in Modulen explizit importiert werden
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/default.nix` (exists)
    - *Ist:* Importiert XX-domain/NNN-*.nix automatisch via readDir.
    - *Soll:* Keine Änderung.

#### `D-13-03`: Gerichtete Abhängigkeiten (ADR-040): Alle Domänen dürfen Foundation (`50-core`) und `lib/` importieren; Peer-zu-Peer-Importe zwischen Service-Domänen bleiben strikt verboten.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. ADR-040 sichert die Entkopplung der Domänen. Foundation und Libs bilden die gemeinsame Basis aller Leafs.
- **Pro:** Verhindert zirkuläre Abhängigkeiten, Ermöglicht isoliertes Testen einzelner Domänen, Saubere Schichtenarchitektur (DAG)
- **Con:** Gemeinsam genutzte Hilfsfunktionen müssen in lib/ oder 50-core gehoben werden
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/docs/adr/ADR-040-gerichtete-abhaengigkeiten.md` (exists)
    - *Ist:* Definiert DAG der Importe von Leaf zu Core/Lib.
    - *Soll:* Keine Änderung.

### Block `14-config-review-51-ingress`: Config-Review 51-ingress: Caddy, Pocket-ID, ACME & LLM-Chunking-Verfahren
*Konsolidiert die verbleibenden Detailbefunde aus dem Ingress-Review (51-ingress) sowie das methodische Vorgehen bei der LLM-gestützten Wissensextraktion. Behandelt spezifische Absicherungen in Caddy (customConfig-Escape-Hatch strikt hinter Authentifizierung platzieren), semantische CIDR-Prüfungen im Ingress-Access-Layer, Pocket-ID Initialisierungs-Schutz (setupCompleted-Guardrail) und die Festlegung des JSON-Block-Verarbeitungsmodells zur verlustfreien Auswertung langer Chat-Transkripte.*

#### `D-14-01`: Caddy `customConfig`-Escape-Hatch strikt hinter Authentifizierungs- und Bouncer-Direktiven platzieren.
- **Status:** `decided` | **Verdict:** `better`
- **Rationale:** Wird customConfig vor den Forward-Auth- oder CrowdSec-Blöcken gerendert, können fehlerhafte oder unvorsichtige Snippets den Zugriffsschutz für geschützte Backends komplett umgehen.
- **Pro:** Verhindert Sicherheits-Bypasses durch individuelle Site-Konfigurationen, Erzwingt Authentifizierung und CrowdSec-Prüfung vor Backend-Routen, Deterministische Render-Reihenfolge in Caddyfile
- **Con:** Einschränkung der Flexibilität bei sehr exotischen Caddy-Direktiven
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/511-caddy.nix` (exists)
    - *Ist:* Rendert customConfig an konfigurierbarer Stelle.
    - *Soll:* customConfig zwingend nach forward_auth und IP-Filtering einsortieren.

#### `D-14-02`: Semantische CIDR-Validierung im Ingress-Access-Layer anstelle von einfachen String-Präfix-Prüfungen implementieren.
- **Status:** `proposed` | **Verdict:** `better`
- **Rationale:** Einfache String-Checks (z. B. auf '192.168.') erkennen ungültige Subnetzmasken nicht und können bei komplexen Netzwerkkonfigurationen fehlschlagen.
- **Pro:** Robuste und fehlertolerante Subnetz-Validierung, Erkennt ungültige IP-Eingaben zur Evaluierungszeit, Erhöht die Zuverlässigkeit von Zugangsregeln
- **Con:** Geringfügig komplexere Prüffunktion in Nix
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/lib/ingress-access.nix` (exists)
    - *Ist:* Prüft IP-Listen mit elementaren String-Funktionen.
    - *Soll:* Validierung über semantische IP/CIDR-Parser-Funktion abbilden.

#### `D-14-03`: LLM-Verarbeitungsstrategie: Granulares JSON-Block-Chunking mit Topic-Index und Code-Abgleich statt monolithischem Dump.
- **Status:** `decided` | **Verdict:** `better`
- **Rationale:** Ein monolithischer Prompt mit 70k+ Tokens überfordert das Context-Window, erzeugt Halluzinationen und verliert Feinheiten. Das Chunking in 14 thematische Blöcke mit striktem Schema und Code-Verifikation sichert 100% Informationstreue.
- **Pro:** Kein Kontext-Überlauf bei langen Gesprächen, Jeder Block ist atomar prüf- und freigebbar, Vollständige Rückführbarkeit auf Quell-Nachrichten
- **Con:** Mehrstufiger Prozess (Phase 0 bis 6) erfordert Workflow-Disziplin
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/todo/README.md` (exists)
    - *Ist:* Dokumentiert den Phasen-Workflow 0 bis 6.
    - *Soll:* Keine Änderung.

#### `D-14-04`: Pocket-ID Setup-Lockdown (`setupCompleted` Assertion) zur Vermeidung von Takeovers offener IdP-Instanzen nach Deployment.
- **Status:** `decided` | **Verdict:** `neutral`
- **Rationale:** Status Quo, keine Änderung – verdict von better auf neutral korrigiert. 512-pocket-id.nix und 519-ingress-guardrails.nix erzwingen bereits Assertions, damit Pocket-ID nicht unkonfiguriert im Netz exponiert wird.
- **Pro:** Verhindert feindliche Initialisierung durch Dritte, Erzwingt deterministischen Administrator-Account, Fail-closed bei unfertiger Authentifizierung
- **Con:** Initiale Einrichtung erfordert expliziten Konfigurationsschritt
- **Code-Referenzen:**
  - `/home/moritz/repos/mediNix-core/51-ingress/512-pocket-id.nix` (exists)
    - *Ist:* Enthält Guardrails für initialen Setup-Status.
    - *Soll:* Keine Änderung.
  - `/home/moritz/repos/mediNix-core/51-ingress/519-ingress-guardrails.nix` (exists)
    - *Ist:* Validiert Ingress-Sicherheitsanforderungen.
    - *Soll:* Keine Änderung.

