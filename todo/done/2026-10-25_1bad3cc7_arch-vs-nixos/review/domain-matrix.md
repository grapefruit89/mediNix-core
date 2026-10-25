# Domänen-Matrix (Chat 1 → Abgleich)

## Priorität

| Rang | Domäne | Todos | Anti-Patterns | Total | Grund |
|---|---|---|---|---|---|
| 1 | flake.nix | 3 | 0 | 3 | 3 kritische Dependency-CVEs (Caddy CVE-2026-0354, CrowdSec NIXPKGS-2026-2196, Seerr CVE-2026-73291) |
| 2 | 51-ingress | 14 | 14 | 28 | 14 offene Todos + 14 Anti-Patterns (Caddy, CrowdSec, DNS, DDNS) |
| 3 | 52-security | 3 | 7 | 10 | 3 offene Todos + 7 Anti-Patterns (Secret-Management, PQC, Firewall) |
| 4 | 50-core | 0 | 7 | 7 | 7 Anti-Patterns (Arch, Kernel-Hardening, Power-Mgmt, Banned Technologies) |
| 5 | docs | 5 | 1 | 6 | 5 offene Todos (ADRs) + 1 Anti-Pattern |
| 6 | lib | 2 | 2 | 4 | 2 offene Todos + 2 Anti-Patterns (Ingress-Access, Registry-Bereinigung) |
| 7 | 57-maintenance | 1 | 0 | 1 | 1 offenes Todo (Backup-Methode Restic) |
| 8 | pkgs | 1 | 0 | 1 | 1 offenes Todo (speedport-api Paketierung) |
| 9 | 58-observability | 0 | 0 | 0 | 0 offene Todos + 0 Anti-Patterns (Observability-Baseline intakt) |

## flake.nix

**Dateien:** flake.nix

**Todos (3):**
- T-22 (dependency-update): Caddy auf 2.11.4 updaten (CVE-2026-0354)
- T-23 (dependency-update): CrowdSec auf 1.7.8 updaten (NIXPKGS-2026-2196)
- T-24 (dependency-update): Seerr auf 3.4.0 updaten (CVE-2026-73291)

**Anti-Patterns (0):**
- keine

## 51-ingress

**Dateien:** 511-caddy.nix, 512-pocket-id.nix, 513-cloudflare-dns.nix, 514-acme.nix, 515-mdns.nix, 516-crowdsec.nix, 517-oauth2-proxy.nix, 518-landingpage.nix, 519-ingress-guardrails.nix

**Todos (14):**
- T-01 (code-change, offen): Caddy Catch-All: abort durch respond 404 ersetzen
- T-02 (code-change, offen): CrowdSec: Hub-Collections um crowdsecurity/http-probing erweitern
- T-03 (code-change, offen): CrowdSec: Ban-Dauer von 4h auf 168h verlängern
- T-05 (test-later, unklar): Pocket-ID UDS evaluieren (Gin-Bug #1249)
- T-06 (code-change, offen): oauth2-proxy: Auf Unix Domain Socket umstellen
- T-07 (code-change, offen): mDNS-Ausmusterung: 515-mdns.nix entfernen / deaktivieren
- T-08 (test-later, unklar): WAN-IP: Speedport-Adapter via Default-Gateway
- T-09 (code-change, offen): Keine festen Router-IPs: Default-Gateway dynamisch ableiten
- T-10 (code-change, offen): Modularer Provider-Dispatch für DDNS via types.enum
- T-16 (code-change, offen): 51-Baum: Slot 515 für 515-blocky.nix nachnutzen
- T-17 (code-change, offen): 51-Baum: Vollständige Ausmusterung von 515-mdns.nix
- T-18 (code-change, offen): 51-Baum: LAN-Publishing aus 513 entfernen & Provider-Lib auslagern
- T-26 (code-change, unklar): 513-cloudflare-dns.nix: Provider speedport integrieren
- T-27 (doc-change, unklar): 513-cloudflare-dns.nix: Rate-Limit- und Laufzeitdokumentation

**Anti-Patterns (14):**
- A-03: HTTP-Statuscode 666 ('get off my lawn') für Scanner ausgeben
- A-04: HTTP-Statuscode 403 (Forbidden) für unbekannte Subdomains nutzen
- A-05: tls internal (Caddy lokale Root-CA) für LAN-Subdomains
- A-06: App-Layer-Bouncer in Caddy (Caddy CrowdSec Bouncer Modul) statt nftables-Bouncer
- A-07: HTTP-Tarpit (endlessh-ähnlich) für scannende Web-Clients
- A-11: mDNS behalten für Zero-Conf
- A-12: .local in Caddy durch .lan ersetzen
- A-13: Bind auf LAN beschränken als Ersatz für DNS-Eintrag
- A-14: TR-064 SOAP-Schnittstelle beim Speedport Smart 4 erzwingen
- A-15: Feste Router-IP 192.168.2.1 im NixOS-Modul hardcodieren
- A-16: RFC1918-IPs standardmäßig in öffentliche Cloudflare-DNS-Zone schreiben (publishLanRecord = true)
- A-25: Neuen Dezimalslot wie 513b oder Sub-Nummern für WAN-Provider einführen
- A-29: Monolithischen Chat-Dump in einem einzigen Schritt ohne Zwischenblöcke verarbeiten
- A-30: Interne TLS-Zertifikate über eigene CA anstatt ACME DNS-01 verteilen

## 52-security

**Dateien:** 520-core-security.nix, 521-creds.nix, 525-vpn-interface.nix, 526-vpn-killswitch.nix

**Todos (3):**
- T-04 (code-change, offen): Secret-Management: *.cred und *.encrypted in .gitignore aufnehmen
- T-12 (code-change, offen): Firewall: Deklarativer Debug-Reject-Modus mit Logging
- T-13 (test-later, unklar): Kernel-Hardening: Modul-Blacklist & lockKernelModules evaluieren

**Anti-Patterns (7):**
- A-08: sops-nix für Secret-Management in mediNix-core nutzen
- A-09: Eine gemeinsame Passwörter-Sammeldatei (`all-secrets.cred`) für alle Dienste nutzen
- A-10: socat-UDS-Bridge vor Pocket ID schalten, um Unix Domain Sockets zu erzwingen
- A-17: Agenix mit klassischen Ed25519-Schlüsseln auf GitHub nutzen
- A-18: Warten auf reine PQC-Kryptografie vor dem Deployment
- A-19: Imperative `iptables -A INPUT ...` Befehle zur schnellen Portöffnung nutzen
- A-20: Permanentes REJECT statt DROP für unberechtigte Verbindungen

## 50-core

**Dateien:** 500-host-baseline.nix, 501-decimal-engine.nix, 502-host-settings.nix, 503-host-integration.nix

**Todos (0):**
- keine

**Anti-Patterns (7):**
- A-01: Arch Linux als Basis für mediNix-core nutzen
- A-02: Ansible für mediNix-Host-Konfiguration einsetzen
- A-21: Eigene Kernel-Patches schreiben und Kernel selbst kompilieren
- A-22: LKRG (Linux Kernel Runtime Guard) als Pflichtmodul erzwingen
- A-23: TLP und auto-cpufreq gleichzeitig aktivieren
- A-24: i915.enable_psr und i915.enable_fbc manuell forcieren
- A-31: Feishin

## docs

**Dateien:** agents/07-patterns-misc/nixos-dotnet-env-config/templates/arr-settings.nix, audit/2026-10-16/repo-cleanup/lib/_helpers.nix, audit/2026-10-16/repo-cleanup/lib/abc-tiering.nix, audit/2026-10-16/repo-cleanup/lib/mk-secure-curl.nix, audit/2026-10-16/repo-cleanup/lib/wait-for-api.nix, examples/5xx-service.example.nix, examples/mergerfs-tiering.nix, examples/simple.nix, examples/vpn-confinement.nix

**Todos (5):**
- T-11 (doc-change, offen): PQC-Hardening: Hybriden Schlüsselaustausch für SSH dokumentieren
- T-14 (doc-change, offen): Power-Management: schedutil und auto-cpufreq im Manifest verankern
- T-15 (doc-change, offen): GPU-Transcoding: Intel GuC/HuC Kernel-Parameter in Jellyfin-ADR
- T-19 (doc-change, offen): Dezimalrahmen: Fraktales Dateisystem-Ordnungsprinzip in ADR-0000 verankern
- T-20 (doc-change, offen): Dezimalrahmen: Secret-Pfade und Credentials-Speicherort in ADR-0000 ergänzen

**Anti-Patterns (1):**
- A-26: Credentials unverschlüsselt oder uneinheitlich über beliebige Unterordner verstreuen

## lib

**Dateien:** arr-settings.nix, cli.nix, creds.nix, decimal-framework.nix, derive.nix, hardening-profiles.nix, ingress-access.nix, memory-policy.nix, registry.nix, service-contract.nix, service-factory.nix, smoke-test.nix

**Todos (2):**
- T-21 (conflict, konflikt): Ingress: Semantische CIDR-Validierung
- T-30 (code-change): Feishin entfernt (554-feishin.nix, registry, memory-policy, flake.nix)

**Anti-Patterns (2):**
- A-27: Blindes Auto-Importieren aller beliebigen .nix-Dateien aus dem gesamten Repo-Baum
- A-28: Vollständiges Verschieben aller Bibliotheksfunktionen in NixOS-Optionswerte

## 57-maintenance

**Dateien:** 570-storage.nix, 571-sqlite-wal.nix, 572-recyclarr.nix, 574-provisioning.nix, 575-update-notifier.nix, 576-backup.nix, 577-drift-detection.nix, 578-orphan-cleanup.nix, 579-backup-ssh.nix

**Todos (1):**
- T-28 (code-change): backup.method in programs.json auf 'restic' setzen (576-backup.nix nutzt Restic)

**Anti-Patterns (0):**
- keine

## pkgs

**Dateien:** speedport-api/default.nix

**Todos (1):**
- T-25 (dependency-update, unklar): speedport-api paketieren

**Anti-Patterns (0):**
- keine

## 58-observability

**Dateien:** 581-ntfy.nix, 582-gatus.nix, 583-runtime-guard.nix, 584-post-boot-watchdog.nix, 585-exporters.nix, 587-disk-health.nix

**Todos (0):**
- keine

**Anti-Patterns (0):**
- keine
