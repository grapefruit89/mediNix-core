# Anti-Pattern-Register (mediNix-core)

> Aggregiert alle verworfenen Ideen und Anti-Patterns aus den 14 Analyse-Blöcken.
> Dient als Warnkatalog für Entwickler und Coding-Agenten, um bekannte Sackgassen zu vermeiden.

| ID | Verworfenes Muster / Idee | Warum verworfen (Begründung) | Quelle (Block) |
| :--- | :--- | :--- | :--- |
| `A-01` | Arch Linux als Basis für mediNix-core nutzen | Rolling Release ohne systemimmanente Rollbacks und imperative Konfiguration verletzen das Clean-Slate- und Reproduzierbarkeits-Prinzip von mediNix. | `01-arch-vs-nixos` |
| `A-02` | Ansible für mediNix-Host-Konfiguration einsetzen | Redundant und widerspricht der deklarativen NixOS-Architektur. | `01-arch-vs-nixos` |
| `A-03` | HTTP-Statuscode 666 ('get off my lawn') für Scanner ausgeben | Nicht RFC-9110-konform; bricht HTTP-Parser und Middleboxes und liefert ein unnötiges Signal. | `02-caddy-catch-all` |
| `A-04` | HTTP-Statuscode 403 (Forbidden) für unbekannte Subdomains nutzen | Verrät dem Angreifer, dass der Host existiert und die Ressource geschützt ist; lädt zu weiterem Scanning ein. | `02-caddy-catch-all` |
| `A-05` | tls internal (Caddy lokale Root-CA) für LAN-Subdomains | Erfordert manuelle Installation und Wartung von Root-Zertifikaten auf allen Heimnetz-Geräten (TVs, Handys), was vom Nutzer explizit abgelehnt wurde. | `02-caddy-catch-all` |
| `A-06` | App-Layer-Bouncer in Caddy (Caddy CrowdSec Bouncer Modul) statt nftables-Bouncer | Ein App-Layer-Bouncer bindet Caddy-Ressourcen für jeden Request; der nftables-Bouncer verwirft Pakete kernel-nah auf allen Ports (INPUT-Chain) ohne TCP-Handshake. | `03-crowdsec-scan-ban` |
| `A-07` | HTTP-Tarpit (endlessh-ähnlich) für scannende Web-Clients | Bindet offene Sockets und Dateideskriptoren im Webserver; CrowdSec sieht dabei keine Statuscodes für adaptive Bans. | `03-crowdsec-scan-ban` |
| `A-08` | sops-nix für Secret-Management in mediNix-core nutzen | Zu komplex, undurchsichtig, externe Abhängigkeit; systemd-creds ist schlanker, nativer und systemd-integriert (in ADR-521 strikt verboten). | `04-credentials-systemd-creds` |
| `A-09` | Eine gemeinsame Passwörter-Sammeldatei (`all-secrets.cred`) für alle Dienste nutzen | Verletzt das Prinzip der geringsten Rechte (Least Privilege); ein kompromittierter Einzel-Dienst könnte alle Secrets lesen. | `04-credentials-systemd-creds` |
| `A-10` | socat-UDS-Bridge vor Pocket ID schalten, um Unix Domain Sockets zu erzwingen | Over-Engineering; erzeugt zusätzliche Prozesse pro Service, während systemd-Hardening und Loopback-Isolation bereits ausreichen. | `04-credentials-systemd-creds` |
| `A-11` | mDNS behalten für Zero-Conf | Caddy serviert .local nicht; Avahi ist zusätzlicher Daemon mit Angriffsfläche; Blocky ist bereits im Stack und löst das gleiche Problem zentraler. | `05-mdns-vs-blocky` |
| `A-12` | .local in Caddy durch .lan ersetzen | Falsche Annahme: .lan ist bereits in Caddy gerendert. .local war nie in Caddy. Es gibt nichts zu ersetzen, nur zu entfernen. | `05-mdns-vs-blocky` |
| `A-13` | Bind auf LAN beschränken als Ersatz für DNS-Eintrag | Bind (Caddy lauscht nur auf LAN-IP) und DNS-Auflösung sind zwei getrennte Schichten. Bind verhindert Zugriff von außen, nicht die Namensauflösung. Beides wird gebraucht. | `05-mdns-vs-blocky` |
| `A-14` | TR-064 SOAP-Schnittstelle beim Speedport Smart 4 erzwingen | Speedport Smart 4 implementiert TR-064 nicht vollständig; führt zu fehlschlagenden SOAP-Requests. | `06-dns-wan-ip-provider` |
| `A-15` | Feste Router-IP 192.168.2.1 im NixOS-Modul hardcodieren | Verletzt das Portabilitäts- und SSoT-Prinzip; bricht sofort bei geändertem Subnetz. | `06-dns-wan-ip-provider` |
| `A-16` | RFC1918-IPs standardmäßig in öffentliche Cloudflare-DNS-Zone schreiben (publishLanRecord = true) | Leakt interne Netzwerk-Topologie öffentlich im Internet (Recon-Gold); interner Traffic gehört ins Split-DNS. | `06-dns-wan-ip-provider` |
| `A-17` | Agenix mit klassischen Ed25519-Schlüsseln auf GitHub nutzen | Anfällig für Harvest-Now-Decrypt-Later; Angreifer können Ciphertexte heute speichern und mit Quantencomputern in Zukunft brechen. | `07-pqc-hndl` |
| `A-18` | Warten auf reine PQC-Kryptografie vor dem Deployment | Reine PQC-Tools sind produktiv noch nicht verfügbar; hybride Verfahren und Hardware-Bindung (TPM2) bieten heute den maximal möglichen Schutz. | `07-pqc-hndl` |
| `A-19` | Imperative `iptables -A INPUT ...` Befehle zur schnellen Portöffnung nutzen | Widerspricht der deklarativen Reproduzierbarkeit von NixOS und wird in ADR-5210 explizit als Anti-Pattern verboten. | `08-firewall-nftables` |
| `A-20` | Permanentes REJECT statt DROP für unberechtigte Verbindungen | Verrät Scannern aktive Hosts und Port-Filterung; im Normalbetrieb ist stummes DROP die sicherere Wahl. | `08-firewall-nftables` |
| `A-21` | Eigene Kernel-Patches schreiben und Kernel selbst kompilieren | Zu hoher Wartungsaufwand, Verlust von Binärcaches, fragile Homelab-Wartung. | `09-kernel-hardening` |
| `A-22` | LKRG (Linux Kernel Runtime Guard) als Pflichtmodul erzwingen | Kann mit künftigen Kernel-Updates brechen und zu Boot-Hangs führen; für Consumer-Homelab zu instabil. | `09-kernel-hardening` |
| `A-23` | TLP und auto-cpufreq gleichzeitig aktivieren | Schließen sich gegenseitig aus; konkurrierende Daemons erzeugen Frequenz-Flackern und Instabilitäten. | `10-power-management` |
| `A-24` | i915.enable_psr und i915.enable_fbc manuell forcieren | Wird ab Intel Gen 8 automatisch vom Kernel geregelt; manuelles Erzwingen führt zu Instabilitäten. | `10-power-management` |
| `A-25` | Neuen Dezimalslot wie 513b oder Sub-Nummern für WAN-Provider einführen | Verletzt die strikte 3-stellige Ganzzahl-Konvention des Dezimalrahmens (ADR-0000). | `11-51-tree-struktur` |
| `A-26` | Credentials unverschlüsselt oder uneinheitlich über beliebige Unterordner verstreuen | Erhöht das Leak-Risiko drastisch und bricht die Nachvollziehbarkeit im Härtungsaudit. | `12-adr-dezimalrahmen` |
| `A-27` | Blindes Auto-Importieren aller beliebigen .nix-Dateien aus dem gesamten Repo-Baum | Führt zu Evaluationsfehlern, da pure Functions, Datensätze und Tests keine NixOS-Modul-Signatur haben. | `13-lib-vs-50-core` |
| `A-28` | Vollständiges Verschieben aller Bibliotheksfunktionen in NixOS-Optionswerte | Erzeugt signifikanten Overhead bei der Flake-Evaluation und birgt das Risiko zirkulärer Modul-Abhängigkeiten. | `13-lib-vs-50-core` |
| `A-29` | Monolithischen Chat-Dump in einem einzigen Schritt ohne Zwischenblöcke verarbeiten | Führt zu Token-Überlauf, Halluzinationen und Verlust kritischer Architektur-Details. | `14-config-review-51-ingress` |
| `A-30` | Interne TLS-Zertifikate über eigene CA anstatt ACME DNS-01 verteilen | Erfordert manuelle Installation von Root-Zertifikaten auf allen Mobilgeräten und Smart-TVs; Nutzer lehnte dies explizit ab. | `14-config-review-51-ingress` |

## Detaillierte Begründungen

### `A-01`: Arch Linux als Basis für mediNix-core nutzen
- **Quelle:** `01-arch-vs-nixos`
- **Begründung:** Rolling Release ohne systemimmanente Rollbacks und imperative Konfiguration verletzen das Clean-Slate- und Reproduzierbarkeits-Prinzip von mediNix.
- **Quell-Nachrichten:** `[0, 1, 8, 9]`

### `A-02`: Ansible für mediNix-Host-Konfiguration einsetzen
- **Quelle:** `01-arch-vs-nixos`
- **Begründung:** Redundant und widerspricht der deklarativen NixOS-Architektur.
- **Quell-Nachrichten:** `[4, 5]`

### `A-03`: HTTP-Statuscode 666 ('get off my lawn') für Scanner ausgeben
- **Quelle:** `02-caddy-catch-all`
- **Begründung:** Nicht RFC-9110-konform; bricht HTTP-Parser und Middleboxes und liefert ein unnötiges Signal.
- **Quell-Nachrichten:** `[16, 17]`

### `A-04`: HTTP-Statuscode 403 (Forbidden) für unbekannte Subdomains nutzen
- **Quelle:** `02-caddy-catch-all`
- **Begründung:** Verrät dem Angreifer, dass der Host existiert und die Ressource geschützt ist; lädt zu weiterem Scanning ein.
- **Quell-Nachrichten:** `[18, 19, 20, 21]`

### `A-05`: tls internal (Caddy lokale Root-CA) für LAN-Subdomains
- **Quelle:** `02-caddy-catch-all`
- **Begründung:** Erfordert manuelle Installation und Wartung von Root-Zertifikaten auf allen Heimnetz-Geräten (TVs, Handys), was vom Nutzer explizit abgelehnt wurde.
- **Quell-Nachrichten:** `[82, 83, 84, 85, 86]`

### `A-06`: App-Layer-Bouncer in Caddy (Caddy CrowdSec Bouncer Modul) statt nftables-Bouncer
- **Quelle:** `03-crowdsec-scan-ban`
- **Begründung:** Ein App-Layer-Bouncer bindet Caddy-Ressourcen für jeden Request; der nftables-Bouncer verwirft Pakete kernel-nah auf allen Ports (INPUT-Chain) ohne TCP-Handshake.
- **Quell-Nachrichten:** `[13, 21, 23]`

### `A-07`: HTTP-Tarpit (endlessh-ähnlich) für scannende Web-Clients
- **Quelle:** `03-crowdsec-scan-ban`
- **Begründung:** Bindet offene Sockets und Dateideskriptoren im Webserver; CrowdSec sieht dabei keine Statuscodes für adaptive Bans.
- **Quell-Nachrichten:** `[20, 21]`

### `A-08`: sops-nix für Secret-Management in mediNix-core nutzen
- **Quelle:** `04-credentials-systemd-creds`
- **Begründung:** Zu komplex, undurchsichtig, externe Abhängigkeit; systemd-creds ist schlanker, nativer und systemd-integriert (in ADR-521 strikt verboten).
- **Quell-Nachrichten:** `[52, 53]`

### `A-09`: Eine gemeinsame Passwörter-Sammeldatei (`all-secrets.cred`) für alle Dienste nutzen
- **Quelle:** `04-credentials-systemd-creds`
- **Begründung:** Verletzt das Prinzip der geringsten Rechte (Least Privilege); ein kompromittierter Einzel-Dienst könnte alle Secrets lesen.
- **Quell-Nachrichten:** `[64, 65]`

### `A-10`: socat-UDS-Bridge vor Pocket ID schalten, um Unix Domain Sockets zu erzwingen
- **Quelle:** `04-credentials-systemd-creds`
- **Begründung:** Over-Engineering; erzeugt zusätzliche Prozesse pro Service, während systemd-Hardening und Loopback-Isolation bereits ausreichen.
- **Quell-Nachrichten:** `[35, 37]`

### `A-11`: mDNS behalten für Zero-Conf
- **Quelle:** `05-mdns-vs-blocky`
- **Begründung:** Caddy serviert .local nicht; Avahi ist zusätzlicher Daemon mit Angriffsfläche; Blocky ist bereits im Stack und löst das gleiche Problem zentraler.
- **Quell-Nachrichten:** `[73, 74]`

### `A-12`: .local in Caddy durch .lan ersetzen
- **Quelle:** `05-mdns-vs-blocky`
- **Begründung:** Falsche Annahme: .lan ist bereits in Caddy gerendert. .local war nie in Caddy. Es gibt nichts zu ersetzen, nur zu entfernen.
- **Quell-Nachrichten:** `[77, 78]`

### `A-13`: Bind auf LAN beschränken als Ersatz für DNS-Eintrag
- **Quelle:** `05-mdns-vs-blocky`
- **Begründung:** Bind (Caddy lauscht nur auf LAN-IP) und DNS-Auflösung sind zwei getrennte Schichten. Bind verhindert Zugriff von außen, nicht die Namensauflösung. Beides wird gebraucht.
- **Quell-Nachrichten:** `[79, 80]`

### `A-14`: TR-064 SOAP-Schnittstelle beim Speedport Smart 4 erzwingen
- **Quelle:** `06-dns-wan-ip-provider`
- **Begründung:** Speedport Smart 4 implementiert TR-064 nicht vollständig; führt zu fehlschlagenden SOAP-Requests.
- **Quell-Nachrichten:** `[46, 47]`

### `A-15`: Feste Router-IP 192.168.2.1 im NixOS-Modul hardcodieren
- **Quelle:** `06-dns-wan-ip-provider`
- **Begründung:** Verletzt das Portabilitäts- und SSoT-Prinzip; bricht sofort bei geändertem Subnetz.
- **Quell-Nachrichten:** `[48, 49]`

### `A-16`: RFC1918-IPs standardmäßig in öffentliche Cloudflare-DNS-Zone schreiben (publishLanRecord = true)
- **Quelle:** `06-dns-wan-ip-provider`
- **Begründung:** Leakt interne Netzwerk-Topologie öffentlich im Internet (Recon-Gold); interner Traffic gehört ins Split-DNS.
- **Quell-Nachrichten:** `[26, 27]`

### `A-17`: Agenix mit klassischen Ed25519-Schlüsseln auf GitHub nutzen
- **Quelle:** `07-pqc-hndl`
- **Begründung:** Anfällig für Harvest-Now-Decrypt-Later; Angreifer können Ciphertexte heute speichern und mit Quantencomputern in Zukunft brechen.
- **Quell-Nachrichten:** `[59, 60, 61]`

### `A-18`: Warten auf reine PQC-Kryptografie vor dem Deployment
- **Quelle:** `07-pqc-hndl`
- **Begründung:** Reine PQC-Tools sind produktiv noch nicht verfügbar; hybride Verfahren und Hardware-Bindung (TPM2) bieten heute den maximal möglichen Schutz.
- **Quell-Nachrichten:** `[69]`

### `A-19`: Imperative `iptables -A INPUT ...` Befehle zur schnellen Portöffnung nutzen
- **Quelle:** `08-firewall-nftables`
- **Begründung:** Widerspricht der deklarativen Reproduzierbarkeit von NixOS und wird in ADR-5210 explizit als Anti-Pattern verboten.
- **Quell-Nachrichten:** `[95]`

### `A-20`: Permanentes REJECT statt DROP für unberechtigte Verbindungen
- **Quelle:** `08-firewall-nftables`
- **Begründung:** Verrät Scannern aktive Hosts und Port-Filterung; im Normalbetrieb ist stummes DROP die sicherere Wahl.
- **Quell-Nachrichten:** `[91, 92, 93]`

### `A-21`: Eigene Kernel-Patches schreiben und Kernel selbst kompilieren
- **Quelle:** `09-kernel-hardening`
- **Begründung:** Zu hoher Wartungsaufwand, Verlust von Binärcaches, fragile Homelab-Wartung.
- **Quell-Nachrichten:** `[100, 101]`

### `A-22`: LKRG (Linux Kernel Runtime Guard) als Pflichtmodul erzwingen
- **Quelle:** `09-kernel-hardening`
- **Begründung:** Kann mit künftigen Kernel-Updates brechen und zu Boot-Hangs führen; für Consumer-Homelab zu instabil.
- **Quell-Nachrichten:** `[99, 100, 101]`

### `A-23`: TLP und auto-cpufreq gleichzeitig aktivieren
- **Quelle:** `10-power-management`
- **Begründung:** Schließen sich gegenseitig aus; konkurrierende Daemons erzeugen Frequenz-Flackern und Instabilitäten.
- **Quell-Nachrichten:** `[103, 105]`

### `A-24`: i915.enable_psr und i915.enable_fbc manuell forcieren
- **Quelle:** `10-power-management`
- **Begründung:** Wird ab Intel Gen 8 automatisch vom Kernel geregelt; manuelles Erzwingen führt zu Instabilitäten.
- **Quell-Nachrichten:** `[105]`

### `A-25`: Neuen Dezimalslot wie 513b oder Sub-Nummern für WAN-Provider einführen
- **Quelle:** `11-51-tree-struktur`
- **Begründung:** Verletzt die strikte 3-stellige Ganzzahl-Konvention des Dezimalrahmens (ADR-0000).
- **Quell-Nachrichten:** `[111]`

### `A-26`: Credentials unverschlüsselt oder uneinheitlich über beliebige Unterordner verstreuen
- **Quelle:** `12-adr-dezimalrahmen`
- **Begründung:** Erhöht das Leak-Risiko drastisch und bricht die Nachvollziehbarkeit im Härtungsaudit.
- **Quell-Nachrichten:** `[120, 121]`

### `A-27`: Blindes Auto-Importieren aller beliebigen .nix-Dateien aus dem gesamten Repo-Baum
- **Quelle:** `13-lib-vs-50-core`
- **Begründung:** Führt zu Evaluationsfehlern, da pure Functions, Datensätze und Tests keine NixOS-Modul-Signatur haben.
- **Quell-Nachrichten:** `[116, 117]`

### `A-28`: Vollständiges Verschieben aller Bibliotheksfunktionen in NixOS-Optionswerte
- **Quelle:** `13-lib-vs-50-core`
- **Begründung:** Erzeugt signifikanten Overhead bei der Flake-Evaluation und birgt das Risiko zirkulärer Modul-Abhängigkeiten.
- **Quell-Nachrichten:** `[115]`

### `A-29`: Monolithischen Chat-Dump in einem einzigen Schritt ohne Zwischenblöcke verarbeiten
- **Quelle:** `14-config-review-51-ingress`
- **Begründung:** Führt zu Token-Überlauf, Halluzinationen und Verlust kritischer Architektur-Details.
- **Quell-Nachrichten:** `[124, 125]`

### `A-30`: Interne TLS-Zertifikate über eigene CA anstatt ACME DNS-01 verteilen
- **Quelle:** `14-config-review-51-ingress`
- **Begründung:** Erfordert manuelle Installation von Root-Zertifikaten auf allen Mobilgeräten und Smart-TVs; Nutzer lehnte dies explizit ab.
- **Quell-Nachrichten:** `[28, 29, 71]`

