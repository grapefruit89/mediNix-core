---
id: "0010"
title: "ADR-0010 — Demarkationslinie: Boot-Seeds (Dateisystem) vs. Fachlogik (REST-API)"
domain: 00
status: Accepted
complexity: 2
last_reviewed: 2026-10-12
tags:
  - architecture
  - provisioning
  - bootstrapping
  - filesystem
  - rest-api
links:
  adr: ADR-0000
---

# ADR-0010 — Demarkationslinie: Boot-Seeds (Dateisystem) vs. Fachlogik (REST-API)

## Status
**Accepted**

---

## 1. Kontext: Das Bootstrap-Paradoxon

In containerisierten Cloud-Umgebungen (z. B. Kubernetes-Operatoren, Terraform-Provider wie Jellarr) herrscht oft das Dogma: *„Niemals interne Dateien auf dem Dateisystem manipulieren, ausschließlich die REST-API verwenden.“*

Für ein autonomes, bare-metal-basiertes NixOS-Homelab (mediNix) scheitert dieser reine API-Ansatz an der harten Realität des **Bootstrap-Paradoxons**:
* Ein Dienst kann seine REST-API erst öffnen, wenn der Daemon vollständig hochgefahren ist (`active (running)`).
* Daemons wie **Jellyfin** verharren beim ersten Start jedoch in einem interaktiven Setup-Wizard (`IsStartupWizardCompleted = false`), der jegliche API-Nutzung blockiert, solange er nicht manuell durchgeklickt oder via Dateisystem vorkonfiguriert wurde.
* Ähnlich verlangen Dienste Ports, Bind-Adressen, SQLite-WAL-Pragmas oder TPM2-verschlüsselte Admin-Passwörter (`LoadCredentialEncrypted`), **bevor** der HTTP-Listener überhaupt an den Socket binden kann.

Wird das Dateisystem komplett verweigert, stirbt die vollautomatische First-Boot-Fähigkeit („Zero-Click Deployment“). Wird andererseits zu viel auf dem Dateisystem manipuliert, drohen Datenbank-Korruption und State Drift.

---

## 2. Entscheidung

Wir etablieren eine normative **Demarkationslinie** zwischen Dateisystem-Initialisierung und API-gestützter Fachdaten-Provisionierung:

### 2.1 Dateisystem / Seeds (Erlaubt & Pflicht für Boot-Infrastruktur)
Direkte Datei-Injektionen über NixOS (`StateDirectory`, `environment.etc`, XML/TOML-Templates, systemd-Credentials) sind **ausschließlich** für statische Boot-Infrastruktur gestattet:
* **Bootstrap & Wizard-Bypass:** Statische XML-Seeds (`jellyfin-system.xml`, `jellyfin-network.xml`) zur Freischaltung des Erstbetriebs ohne Browser-Interaktion.
* **Netzwerk & Ports:** Deklaratives Binden an `127.0.0.1` und den deterministischen Dezimalrahmen-Port (`num * 10`).
* **Sicherheits-Credentials:** Einspielen verschlüsselter systemd-Credentials via `LoadCredentialEncrypted` (z. B. `jellyfin-admin-pw`, API-Key-Files).
* **Storage & Verzeichnisse:** Bereitstellung von `StateDirectory`, `CacheDirectory` und Berechtigungen (`UMask = "0002"`, `media:media`).

### 2.2 REST-API (Verbindlich für alle Fachdomänen)
Sämtliche fachlichen Entitäten und Anwendungszustände werden **ausnahmslos über die offizielle REST-API** der laufenden Dienste provisioniert (z. B. via Python-Provisioner in `lib/arr-provision/`):
* Medienbibliotheken und Scan-Pfade (Jellyfin Libraries)
* Root-Folders (Sonarr, Radarr, Readarr, Lidarr)
* Quality-Profiles und Release-Profile
* Indexer-Kopplungen (Prowlarr-Sync)
* Download-Client-Konfigurationen (SABnzbd-Anbindung)
* Benutzerkonten, Berechtigungen und Playback-Limits

### 2.3 Striktes Verbot (Keine direkten SQL-Schreiboperationen)
* **Keine direkten SQL-Schreiboperationen (`INSERT`, `UPDATE`, `DELETE`) auf SQLite-Datenbanken** bei laufenden Daemons!
* *Begründung:* SQLite-Schreibzugriffe von außen führen bei aktiven .NET- oder Python-Daemons unweigerlich zu WAL-Lock-Konflikten (`database is locked`), Korruption oder Cache-Desynchronisation, da die Anwendungsdienste Entitäten oft im Arbeitsspeicher puffern und externe DB-Mutations ignorieren.

---

## 3. Konsequenzen

1. **Zero-Click First-Boot:** Ein neu deployter mediNix-Server bootet deterministisch in unter 5 Sekunden durch, ohne an blockierten First-Run-Wizards hängenzubleiben.
2. **Kein State Drift:** Da Fachdaten ausschließlich per API mit idempotenter *GET-vor-POST/PUT*-Prüfung provisioniert werden, entsteht kein Drift gegenüber manuellen Web-UI-Änderungen.
3. **Klare Agenten-Leitlinie:** LLM-Agenten und Administratoren haben eine unmissverständliche Richtlinie: *„Infrastruktur auf die Platte, Fachlogik über den Port.“*
