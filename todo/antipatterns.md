# Anti-Pattern-Register (mediNix-core)

> Aggregiert alle verworfenen Ideen und Anti-Patterns aus allen 27 Analyse-Blöcken.
> Dient als verbindlicher Warnkatalog für Entwickler und Coding-Agenten, um bekannte Sackgassen zu vermeiden.

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
| `A-32` | Nixmap als vollständigen Ersatz für NixOS-Modulhandbuch und Flake-Dokumentation betrachten | Nixmap deckt primär elementare Sprachregeln und AST-Muster ab; Modulspezifika wie mkOption-Typen, submodule-Merge und Flake-Outputs müssen separat geprüft werden. | `15-nixmap-ast-audit` |
| `A-33` | Schwere Nix-Builds und QEMU-VM-Tests interaktiv im Vordergrund mit hohem Timeout blockierend ausführen | Blockiert Agenten-Sessions für 10–20 Minuten pro Lauf und führt zu Timeout-Abbrüchen; Hintergrund-Tasks oder no-build Checks sind vorzuziehen. | `16-agent-error-taxonomy` |
| `A-34` | Vollständigen QEMU-VM-Boot bei jedem interaktiven Edit-Schritt erzwingen | Blockiert die Agenten-Ausführung für bis zu 20 Minuten und verbraucht massiv CPU/Token ohne Mehrwert bei reinen Doku- oder Optionsänderungen. | `18-flake-architecture-ci` |
| `A-35` | Nixarr-Muster mit sops-nix und Network Namespaces für mediNix übernehmen | Verletzt die Kerninvariante Zero-Container und Banned Technologies (sops-nix verboten, Namespaces stören UDS). | `19-community-flakes-benchmark` |
| `A-36` | Agenten-Wissen rein aus dem Modellgedächtnis ohne statische Optionen-Validierung nutzen | Führt bei sich schnell ändernden nixpkgs-Optionen zwangsläufig zu Halluzinationen und Fehlbuilds. | `20-machine-readable-systemd-nixos` |
| `A-37` | Gatus-Monitoring-Endpunkte manuell und hardcodiert in 582-gatus.nix pflegen | Führt zu sofortiger Dokumentations- und Monitoring-Drift, wenn Dienste umbenannt oder deaktiviert werden. | `21-observability-automation` |
| `A-38` | 509-guardrails.nix als zusätzliche Assertion-Datei anlegen | Redundant zu 591-cross-domain.nix; fragmentiert die Guardrail-Logik. | `26-guardrail-591` |
| `A-39` | caddy-tarpit für Web-Scans einsetzen ('Wer scannt, fliegt raus') | Tarpit bindet Kernel-Sockets und Webserver-Ressourcen für bösartige Scans; Angreifer werden stattdessen sofort via CrowdSec + nftables kernel-nah auf Blocklist gesetzt. | `27-caddy-plugin-replacements` |
| `A-40` | caddy-defender für verzögerte Bot-Responses nutzen | Verzögerte Responses binden Ressourcen. Klare 404-Codes triggern CrowdSec schneller und deterministischer. | `27-caddy-plugin-replacements` |
| `A-41` | cerberus Caddy-Plugin zur Ratenbegrenzung kompilieren | Caddy-Plugin cerberus ist veraltet/unmaintained; nftables und CrowdSec auf Kernel-Ebene bieten robusteren Schutz ohne Caddy-Custom-Build-Risiken. | `27-caddy-plugin-replacements` |

## Detaillierte Begründungen

## A-01: Arch Linux als Basis für mediNix-core nutzen
- **Warum verworfen:** Rolling Release ohne systemimmanente Rollbacks und imperative Konfiguration verletzen das Clean-Slate- und Reproduzierbarkeits-Prinzip von mediNix.
- **Quelle:** `01-arch-vs-nixos`

## A-02: Ansible für mediNix-Host-Konfiguration einsetzen
- **Warum verworfen:** Redundant und widerspricht der deklarativen NixOS-Architektur.
- **Quelle:** `01-arch-vs-nixos`

## A-03: HTTP-Statuscode 666 ('get off my lawn') für Scanner ausgeben
- **Warum verworfen:** Nicht RFC-9110-konform; bricht HTTP-Parser und Middleboxes und liefert ein unnötiges Signal.
- **Quelle:** `02-caddy-catch-all`

## A-04: HTTP-Statuscode 403 (Forbidden) für unbekannte Subdomains nutzen
- **Warum verworfen:** Verrät dem Angreifer, dass der Host existiert und die Ressource geschützt ist; lädt zu weiterem Scanning ein.
- **Quelle:** `02-caddy-catch-all`

## A-05: tls internal (Caddy lokale Root-CA) für LAN-Subdomains
- **Warum verworfen:** Erfordert manuelle Installation und Wartung von Root-Zertifikaten auf allen Heimnetz-Geräten (TVs, Handys), was vom Nutzer explizit abgelehnt wurde.
- **Quelle:** `02-caddy-catch-all`

## A-06: App-Layer-Bouncer in Caddy (Caddy CrowdSec Bouncer Modul) statt nftables-Bouncer
- **Warum verworfen:** Ein App-Layer-Bouncer bindet Caddy-Ressourcen für jeden Request; der nftables-Bouncer verwirft Pakete kernel-nah auf allen Ports (INPUT-Chain) ohne TCP-Handshake.
- **Quelle:** `03-crowdsec-scan-ban`

## A-07: HTTP-Tarpit (endlessh-ähnlich) für scannende Web-Clients
- **Warum verworfen:** Bindet offene Sockets und Dateideskriptoren im Webserver; CrowdSec sieht dabei keine Statuscodes für adaptive Bans.
- **Quelle:** `03-crowdsec-scan-ban`

## A-08: sops-nix für Secret-Management in mediNix-core nutzen
- **Warum verworfen:** Zu komplex, undurchsichtig, externe Abhängigkeit; systemd-creds ist schlanker, nativer und systemd-integriert (in ADR-521 strikt verboten).
- **Quelle:** `04-credentials-systemd-creds`

## A-09: Eine gemeinsame Passwörter-Sammeldatei (`all-secrets.cred`) für alle Dienste nutzen
- **Warum verworfen:** Verletzt das Prinzip der geringsten Rechte (Least Privilege); ein kompromittierter Einzel-Dienst könnte alle Secrets lesen.
- **Quelle:** `04-credentials-systemd-creds`

## A-10: socat-UDS-Bridge vor Pocket ID schalten, um Unix Domain Sockets zu erzwingen
- **Warum verworfen:** Over-Engineering; erzeugt zusätzliche Prozesse pro Service, während systemd-Hardening und Loopback-Isolation bereits ausreichen.
- **Quelle:** `04-credentials-systemd-creds`

## A-11: mDNS behalten für Zero-Conf
- **Warum verworfen:** Caddy serviert .local nicht; Avahi ist zusätzlicher Daemon mit Angriffsfläche; Blocky ist bereits im Stack und löst das gleiche Problem zentraler.
- **Quelle:** `05-mdns-vs-blocky`

## A-12: .local in Caddy durch .lan ersetzen
- **Warum verworfen:** Falsche Annahme: .lan ist bereits in Caddy gerendert. .local war nie in Caddy. Es gibt nichts zu ersetzen, nur zu entfernen.
- **Quelle:** `05-mdns-vs-blocky`

## A-13: Bind auf LAN beschränken als Ersatz für DNS-Eintrag
- **Warum verworfen:** Bind (Caddy lauscht nur auf LAN-IP) und DNS-Auflösung sind zwei getrennte Schichten. Bind verhindert Zugriff von außen, nicht die Namensauflösung. Beides wird gebraucht.
- **Quelle:** `05-mdns-vs-blocky`

## A-14: TR-064 SOAP-Schnittstelle beim Speedport Smart 4 erzwingen
- **Warum verworfen:** Speedport Smart 4 implementiert TR-064 nicht vollständig; führt zu fehlschlagenden SOAP-Requests.
- **Quelle:** `06-dns-wan-ip-provider`

## A-15: Feste Router-IP 192.168.2.1 im NixOS-Modul hardcodieren
- **Warum verworfen:** Verletzt das Portabilitäts- und SSoT-Prinzip; bricht sofort bei geändertem Subnetz.
- **Quelle:** `06-dns-wan-ip-provider`

## A-16: RFC1918-IPs standardmäßig in öffentliche Cloudflare-DNS-Zone schreiben (publishLanRecord = true)
- **Warum verworfen:** Leakt interne Netzwerk-Topologie öffentlich im Internet (Recon-Gold); interner Traffic gehört ins Split-DNS.
- **Quelle:** `06-dns-wan-ip-provider`

## A-17: Agenix mit klassischen Ed25519-Schlüsseln auf GitHub nutzen
- **Warum verworfen:** Anfällig für Harvest-Now-Decrypt-Later; Angreifer können Ciphertexte heute speichern und mit Quantencomputern in Zukunft brechen.
- **Quelle:** `07-pqc-hndl`

## A-18: Warten auf reine PQC-Kryptografie vor dem Deployment
- **Warum verworfen:** Reine PQC-Tools sind produktiv noch nicht verfügbar; hybride Verfahren und Hardware-Bindung (TPM2) bieten heute den maximal möglichen Schutz.
- **Quelle:** `07-pqc-hndl`

## A-19: Imperative `iptables -A INPUT ...` Befehle zur schnellen Portöffnung nutzen
- **Warum verworfen:** Widerspricht der deklarativen Reproduzierbarkeit von NixOS und wird in ADR-5210 explizit als Anti-Pattern verboten.
- **Quelle:** `08-firewall-nftables`

## A-20: Permanentes REJECT statt DROP für unberechtigte Verbindungen
- **Warum verworfen:** Verrät Scannern aktive Hosts und Port-Filterung; im Normalbetrieb ist stummes DROP die sicherere Wahl.
- **Quelle:** `08-firewall-nftables`

## A-21: Eigene Kernel-Patches schreiben und Kernel selbst kompilieren
- **Warum verworfen:** Zu hoher Wartungsaufwand, Verlust von Binärcaches, fragile Homelab-Wartung.
- **Quelle:** `09-kernel-hardening`

## A-22: LKRG (Linux Kernel Runtime Guard) als Pflichtmodul erzwingen
- **Warum verworfen:** Kann mit künftigen Kernel-Updates brechen und zu Boot-Hangs führen; für Consumer-Homelab zu instabil.
- **Quelle:** `09-kernel-hardening`

## A-23: TLP und auto-cpufreq gleichzeitig aktivieren
- **Warum verworfen:** Schließen sich gegenseitig aus; konkurrierende Daemons erzeugen Frequenz-Flackern und Instabilitäten.
- **Quelle:** `10-power-management`

## A-24: i915.enable_psr und i915.enable_fbc manuell forcieren
- **Warum verworfen:** Wird ab Intel Gen 8 automatisch vom Kernel geregelt; manuelles Erzwingen führt zu Instabilitäten.
- **Quelle:** `10-power-management`

## A-25: Neuen Dezimalslot wie 513b oder Sub-Nummern für WAN-Provider einführen
- **Warum verworfen:** Verletzt die strikte 3-stellige Ganzzahl-Konvention des Dezimalrahmens (ADR-0000).
- **Quelle:** `11-51-tree-struktur`

## A-26: Credentials unverschlüsselt oder uneinheitlich über beliebige Unterordner verstreuen
- **Warum verworfen:** Erhöht das Leak-Risiko drastisch und bricht die Nachvollziehbarkeit im Härtungsaudit.
- **Quelle:** `12-adr-dezimalrahmen`

## A-27: Blindes Auto-Importieren aller beliebigen .nix-Dateien aus dem gesamten Repo-Baum
- **Warum verworfen:** Führt zu Evaluationsfehlern, da pure Functions, Datensätze und Tests keine NixOS-Modul-Signatur haben.
- **Quelle:** `13-lib-vs-50-core`

## A-28: Vollständiges Verschieben aller Bibliotheksfunktionen in NixOS-Optionswerte
- **Warum verworfen:** Erzeugt signifikanten Overhead bei der Flake-Evaluation und birgt das Risiko zirkulärer Modul-Abhängigkeiten.
- **Quelle:** `13-lib-vs-50-core`

## A-29: Monolithischen Chat-Dump in einem einzigen Schritt ohne Zwischenblöcke verarbeiten
- **Warum verworfen:** Führt zu Token-Überlauf, Halluzinationen und Verlust kritischer Architektur-Details.
- **Quelle:** `14-config-review-51-ingress`

## A-30: Interne TLS-Zertifikate über eigene CA anstatt ACME DNS-01 verteilen
- **Warum verworfen:** Erfordert manuelle Installation von Root-Zertifikaten auf allen Mobilgeräten und Smart-TVs; Nutzer lehnte dies explizit ab.
- **Quelle:** `14-config-review-51-ingress`

## A-32: Nixmap als vollständigen Ersatz für NixOS-Modulhandbuch und Flake-Dokumentation betrachten
- **Warum verworfen:** Nixmap deckt primär elementare Sprachregeln und AST-Muster ab; Modulspezifika wie mkOption-Typen, submodule-Merge und Flake-Outputs müssen separat geprüft werden.
- **Quelle:** `15-nixmap-ast-audit`

## A-33: Schwere Nix-Builds und QEMU-VM-Tests interaktiv im Vordergrund mit hohem Timeout blockierend ausführen
- **Warum verworfen:** Blockiert Agenten-Sessions für 10–20 Minuten pro Lauf und führt zu Timeout-Abbrüchen; Hintergrund-Tasks oder no-build Checks sind vorzuziehen.
- **Quelle:** `16-agent-error-taxonomy`

## A-34: Vollständigen QEMU-VM-Boot bei jedem interaktiven Edit-Schritt erzwingen
- **Warum verworfen:** Blockiert die Agenten-Ausführung für bis zu 20 Minuten und verbraucht massiv CPU/Token ohne Mehrwert bei reinen Doku- oder Optionsänderungen.
- **Quelle:** `18-flake-architecture-ci`

## A-35: Nixarr-Muster mit sops-nix und Network Namespaces für mediNix übernehmen
- **Warum verworfen:** Verletzt die Kerninvariante Zero-Container und Banned Technologies (sops-nix verboten, Namespaces stören UDS).
- **Quelle:** `19-community-flakes-benchmark`

## A-36: Agenten-Wissen rein aus dem Modellgedächtnis ohne statische Optionen-Validierung nutzen
- **Warum verworfen:** Führt bei sich schnell ändernden nixpkgs-Optionen zwangsläufig zu Halluzinationen und Fehlbuilds.
- **Quelle:** `20-machine-readable-systemd-nixos`

## A-37: Gatus-Monitoring-Endpunkte manuell und hardcodiert in 582-gatus.nix pflegen
- **Warum verworfen:** Führt zu sofortiger Dokumentations- und Monitoring-Drift, wenn Dienste umbenannt oder deaktiviert werden.
- **Quelle:** `21-observability-automation`

## A-38: 509-guardrails.nix als zusätzliche Assertion-Datei anlegen
- **Warum verworfen:** Redundant zu 591-cross-domain.nix; fragmentiert die Guardrail-Logik.
- **Quelle:** `26-guardrail-591`

## A-39: caddy-tarpit für Web-Scans einsetzen ('Wer scannt, fliegt raus')
- **Warum verworfen:** Tarpit bindet Kernel-Sockets und Webserver-Ressourcen für bösartige Scans; Angreifer werden stattdessen sofort via CrowdSec + nftables kernel-nah auf Blocklist gesetzt.
- **Quelle:** `27-caddy-plugin-replacements`

## A-40: caddy-defender für verzögerte Bot-Responses nutzen
- **Warum verworfen:** Verzögerte Responses binden Ressourcen. Klare 404-Codes triggern CrowdSec schneller und deterministischer.
- **Quelle:** `27-caddy-plugin-replacements`

## A-41: cerberus Caddy-Plugin zur Ratenbegrenzung kompilieren
- **Warum verworfen:** Caddy-Plugin cerberus ist veraltet/unmaintained; nftables und CrowdSec auf Kernel-Ebene bieten robusteren Schutz ohne Caddy-Custom-Build-Risiken.
- **Quelle:** `27-caddy-plugin-replacements`

