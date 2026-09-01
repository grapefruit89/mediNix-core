---
id: "ARCH-57-golden-handbook"
title: "ARCH 5000 golden handbook"
domain: 57
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - storage
links:
  adr: ""
  repo-harvest: ""
---
# 👑 Das Goldene Handbuch

1. [Status Dashboard](./00_STATUS_DASHBOARD.md)
2. [Dendritische Architektur](../adr/den-framework-foundation.md)
3. [Sovereign Identity](../adr/sovereign-identity-v4.md)
4. [Ingress Standard](./guides/GUIDE-Caddy-M1-Abrams.md)
5. [Enterprise Nix](./guides/GUIDE-Enterprise-Nix-Standards.md)

12. [**ABC Storage Tiering**](./guides/GUIDE-ABC-Storage-Tiering.md) - MergerFS Pooling und ZFS Performance.

13. [**Intel QuickSync & iGPU**](./guides/GUIDE-Intel-QuickSync-NixOS.md) - Natives Hardware-Transcoding.
14. [**Secret Management Audit (ADR-006)**](./adr/ADR-006-Secret-Management-Audit.md) - Warum sops-nix git-crypt überlegen ist.

15. [**DNS & Naming Standard (ADR-007)**](./adr/ADR-007-DNS-Naming-Standard.md) - Tailscale SplitDNS Logik.

16. [**SSH & ProxyJump Standard (ADR-008)**](./adr/ADR-008-SSH-ProxyJump-Standard.md) - Gehärteter Admin-Zugang.

17. [**Windows SSH Integration**](./guides/GUIDE-Windows-to-Nix-SSH.md) - Nahtloser Zugriff von Windows auf den Tower.

18. [**Paperless-ngx Master-Config**](./guides/GUIDE-Paperless-Master-Config.md) - Totale deklarative Kontrolle.

19. [**Paperless-ngx Master-Variable-List**](./guides/MASTER-CONFIG-PAPERLESS-NGX.md) - Die vollständige Referenz.

20. [**Seerr Master-Variable-List**](./guides/MASTER-CONFIG-SEERR.md) - Media Request Manager.

21. [**Radarr Master-Variable-List**](./guides/MASTER-CONFIG-RADARR.md) - Movie Manager.

22. [**Fail2ban Master-Reference**](./guides/MASTER-CONFIG-FAIL2BAN.md) - Security Hardening.

23. [**Tailscale Master-Variable-List**](./guides/MASTER-CONFIG-TAILSCALE.md) - Networking Mastery.

24. [**ARR-Stack Master-Reference**](./guides/MASTER-CONFIG-ARR-STACK.md) - Media Management.

17. [**Media Stack Consolidation (ADR-009)**](./adr/ADR-009-Media-Stack-Consolidation.md) - Gemeinsame Datenbank und Bündelung.

25. [**Audiobookshelf Master-Variable-List**](./guides/MASTER-CONFIG-AUDIOBOOKSHELF.md) - Audiobook Management.

26. [**SABnzbd Master-Variable-List**](./guides/MASTER-CONFIG-SABNZBD.md) - Usenet Downloader.

27. [**Homepage Master-Variable-List**](./guides/MASTER-CONFIG-HOMEPAGE.md) - Dashboard Config.

28. [**Blank Snapshot Persistence**](./guides/GUIDE-Blank-Snapshot-Persistence.md) - Radikale System-Hygiene nach Misterio77.

20. [**Fail2ban Master-Endpoint-List**](./guides/MASTER-CONFIG-FAIL2BAN-ENDPOINTS.md) - Alle Filter und Aktionen.

28. [**n8n Master-Variable-List**](./guides/MASTER-CONFIG-N8N.md) - Workflow Automation.

29. [**Vaultwarden Master-Config**](./guides/MASTER-CONFIG-VAULTWARDEN.md) - Password Vault Security.

20. [**Conduit Master-Config**](./guides/GUIDE-Conduit-Master-Config.md) - Hocheffizienter Matrix-Server.

22. [**Pattern Mining from Nixpkgs**](./guides/GUIDE-Pattern-Mining-Nixpkgs.md) - Lernen von den Core-Maintainern.

22. [**Advanced Hidden Gems**](./guides/GUIDE-Advanced-Hidden-Gems.md) - SearXNG, Attic und Aria2.

23. [**Home Assistant Master-Interface-List**](./guides/MASTER-HA-INTERFACES.md) - API und Orchestrierung.

23. [**Under-the-Radar Services**](./guides/GUIDE-Radar-Services-Master-Config.md) - nftables, MQTT und Zigbee.

24. [**Monitoring Hub (Gatus)**](./guides/GUIDE-Monitoring-Hub-Gatus.md) - Service-Watchtower.

25. [**Caddy Operations Master**](./guides/GUIDE-Caddy-Operations-Master.md) - CLI, API und Caddyfile Konzepte.

## 🛠️ Caddy Encyclopedia (Deep-Dive)
- [**Caddyfile Mastery**](./guides/caddy/01-Caddyfile-Mastery.md) - Syntax & Directives.
- [**Architecture & API**](./guides/caddy/02-Architecture-API.md) - Programmability.
- [**Operations & Logging**](./guides/caddy/03-Operations-Logging.md) - Monitoring & Maintenance.

## 🏢 Determinate Encyclopedia (Enterprise)
- [**Enterprise Installer**](./guides/determinate/01-Enterprise-Installer.md) - Security & Stabilität.
- [**FlakeHub & Vetting**](./guides/determinate/02-FlakeHub-Vetting.md) - Sichere Abhängigkeiten.
- [**Performance & Caching**](./guides/determinate/03-CI-Caching-Performance.md) - Speed-Optimierung.
- [**Advanced Security Audit**](./guides/determinate/04-Advanced-Security-Audit.md) - Flake-Checker & Supply Chain.
- [**Enterprise Governance & SBOM**](./guides/determinate/05-Enterprise-Governance-SBOM.md) - CVE-Fixes und Nachweisbarkeit.

26. [**Cloud Storage with OCIS**](./guides/GUIDE-Cloud-Storage-OCIS.md) - ownCloud Infinite Scale in Go.

27. [**ownCloud OCIS Master-Reference**](./guides/MASTER-CONFIG-OCIS.md) - Variablen und API-Endpunkte.

27. [**Knowledge Mastery with Readeck**](./guides/GUIDE-Knowledge-Mastery-Readeck.md) - Bookmarks und Archivierung.

28. [**Audio Mastery with Navidrome**](./guides/GUIDE-Audio-Mastery-Navidrome.md) - Musik-Streaming der Extraklasse.

29. [**AdGuardHome DNS Shield**](./guides/GUIDE-DNS-Shield-AdGuardHome.md) - Netzwerkweiter Werbeblocker.

30. [**Fujitsu Hardware Mastery**](./guides/GUIDE-Fujitsu-Hardware-Mastery.md) - Optimierung für den Q958 Tower.

31. [**Storage Cluster Strategy (ADR-006)**](./adr/ADR-006-Storage-Cluster-Strategy.md) - Der Weg zum unendlichen Speicher.

32. [**Blocky Performance DNS**](./guides/GUIDE-Blocky-Performance-DNS.md) - Hocheffizienter DNS-Proxy in Go.

33. [**Sync & Backup Master-Config**](./guides/GUIDE-Sync-Backup-Master-Config.md) - Syncthing und Restic Strategien.

34. [**Restic Master-Variable-List**](./guides/MASTER-CONFIG-RESTIC.md) - Backup-Steuerung.

35. [**Rclone Master-Variable-List**](./guides/MASTER-CONFIG-RCLONE.md) - Cloud-Sync-Optionen.

36. [**Pro-Backup Strategies**](./guides/GUIDE-Pro-Backup-Strategies.md) - Ransomware-Schutz und Cloud-Mounts.

18. [**Headless Server Law (ADR-010)**](./adr/ADR-010-Headless-Server-Law.md) - Das strikte Verbot von GUI-Komponenten.

24. [**Nixpkgs Engine Mastery**](./guides/GUIDE-Nixpkgs-Engine-Mastery.md) - Kernel und Paket-Strukturen.

31. [**Jellyfin Media Mastery**](./guides/GUIDE-Media-Mastery-Jellyfin.md) - High-Performance Streaming.

32. [**Audiobookshelf Mastery**](./guides/GUIDE-Audiobookshelf-Mastery.md) - Hörbücher und Podcasts.

19. [**On-Demand Services (ADR-011)**](./adr/ADR-011-On-Demand-Services.md) - Socket-Activation für maximale Effizienz.

20. [**Socket-Activation Selection (ADR-012)**](./adr/ADR-012-Socket-Activation-Selection.md) - Pragmatische Ressourcen-Ersparnis.

21. [**Media Performance Priority (ADR-013)**](./adr/ADR-013-Media-Performance-Priority.md) - Schutz vor Rucklern beim Streaming.

37. [**Hardware Acceleration Deep-Dive**](./guides/GUIDE-Hardware-Acceleration-DeepDive.md) - Ruckelfreies 4K-Streaming via QuickSync.

38. [**Nixpkgs Packaging Standard**](./guides/GUIDE-Nixpkgs-Packaging-Standard.md) - Qualitäts-Tore für eigene Pakete.

22. [**Systemic Governance (ADR-014)**](./adr/ADR-014-Systemic-Governance.md) - Regeln für langfristige Stabilität.

39. [**S3 Object Vault (Garage)**](./guides/GUIDE-S3-Object-Vault-Garage.md) - Privater S3-Speicher in Rust.

40. [**SSH Infrastructure Mastery**](./guides/GUIDE-SSH-Infrastructure-Mastery.md) - Remote-Unlock und Binary-Serving.

41. [**Nftables Firewall Mastery**](./guides/GUIDE-Nftables-Firewall-Mastery.md) - Moderne Netzwerk-Sicherheit.

42. [**Kernel Mastery & Hardening**](./guides/GUIDE-Kernel-Mastery-Hardening.md) - System-Kern und Security.

43. [**Caddy Gateway Mastery**](./guides/GUIDE-Caddy-Gateway-Mastery.md) - Intelligentes Routing und SSL.

44. [**Automated Documentation Mastery**](./guides/GUIDE-Automated-Documentation-Mastery.md) - Diagramme und Visualisierung.

45. [**Networking Ops & Performance**](./guides/GUIDE-Networking-Performance-SRE.md) - Werkzeuge für den God-Mode.

46. [**Security Stealth SPA**](./guides/GUIDE-Security-Stealth-SPA.md) - Unsichtbare Firewall via fwknop.

47. [**Service Hardening & Sandboxing**](./guides/GUIDE-Service-Hardening-Sandboxing.md) - Prozess-Isolation und CVE-Checks.

48. [**System Monitoring & Telemetry**](./guides/GUIDE-System-Monitoring-Telemetry.md) - Echtzeit-Metriken und Recovery.

43. [**Aviation-Grade Hardening (srvos)**](./guides/GUIDE-Aviation-Grade-Hardening-srvos.md) - Deep-Sandboxing Standard.

23. [**Distance Parity Mandate (ADR-015)**](./adr/ADR-015-Distance-Parity-Mandate.md) - Distanz statt lokaler Redundanz.

44. [**Future Storage Scaling**](./guides/GUIDE-Future-Storage-Scaling.md) - Strategien für >5TB und Bcachefs.

45. [**Kernel Surgical Diet**](./guides/GUIDE-Kernel-Surgical-Diet.md) - Entfernung von Legacy- und Enterprise-Bloat.

46. [**Data Deduplication SRE**](./guides/GUIDE-Data-Deduplication-SRE.md) - Effiziente Hygiene via rclone.

47. [**Sovereign Git Mastery**](./guides/GUIDE-Sovereign-Git-Mastery.md) - Eigene Git-Server und Repo-Hygiene.

48. [**Matrix Orchestration & Alerting**](./guides/GUIDE-Matrix-Orchestration-CLI.md) - System-Benachrichtigungen via CLI.

49. [**GitHub Actions SRE Mastery**](./guides/GUIDE-GitHub-Actions-SRE-Mastery.md) - CI/CD und Automatisierung.

50. [**GitHub Security Hardening**](./guides/GUIDE-GitHub-Security-Hardening.md) - Schutz vor Leaks und Schwachstellen.

51. [**Webhook Orchestrierung**](./guides/GUIDE-Webhook-Automation-n8n.md) - n8n und GitHub Events.

52. [**GitHub Codespaces SRE**](./guides/GUIDE-GitHub-Codespaces-SRE.md) - Mobile Kommandozentrale in der Cloud.

53. [**Gatus: Next-Gen Monitoring**](./guides/GUIDE-Next-Gen-Monitoring-Gatus.md) - Hocheffizienter Watchtower in Go.

54. [**HomeDash CLI Dashboard**](./guides/GUIDE-Terminal-Dashboard-HomeDash.md) - Die Kommandozentrale im Terminal.

55. [**njq: Nix-Powered JSON Processing**](./guides/GUIDE-Advanced-CLI-Tooling-njq.md) - Daten-Analyse mit Nix-Syntax.

56. [**Gatus Master-Config-Reference**](./guides/MASTER-CONFIG-GATUS.md) - Variablen und Alerting-Schnittstellen.

57. [**InfluxDB 3 Telemetry**](./guides/GUIDE-Modern-Monitoring-Influx3.md) - Zeitreihen-Datenbank für SRE.

58. [**NVMe over TCP (NVMe-oF)**](./guides/GUIDE-Network-Storage-NVMe-oF.md) - Ultra-High-Speed Network Storage.

59. [**Stable Network Interface MAC**](./guides/GUIDE-Stable-Network-Interface-MAC.md) - Predictable Networking.

59. [**Stable Network Interface MAC**](./guides/GUIDE-Stable-Network-Interface-MAC.md) - Predictable Networking.

60. [**Nix DRY Refactoring**](./guides/GUIDE-Nix-Dry-Refactoring.md) - Eliminierung von Boilerplate.

61. [**Findings Registry**](./learnings/FINDINGS-REGISTRY.md) - Der physische Nachweis aller Quellen.

62. [**Binary Cache Optimization**](./guides/GUIDE-Binary-Cache-Optimization.md) - Radikale Speicherersparnis.

63. [**Landlock Isolation Mastery**](./guides/GUIDE-Landlock-Isolation-Mastery.md) - Modernstes Prozess-Sandboxing.
