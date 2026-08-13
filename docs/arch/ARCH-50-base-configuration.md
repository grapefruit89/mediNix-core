---
id: "ARCH-50-base-configuration"
title: "ARCH 5000 base configuration"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - core
links:
  adr: ""
  repo-harvest: ""
---
# NixOS Basis-Konfiguration (Host: q958)

## 1. User Layer (KISS)
Diese Datei dokumentiert die fundamentale Betriebssystem-Konfiguration des Fujitsu Q958. Sie beinhaltet die Grundeinstellungen für den Bootvorgang, das Netzwerk, die Systemsprache (Deutsch) und den primären Benutzer "moritz". Um den Einstieg zu erleichtern, wurde initial eine grafische Oberfläche (XFCE) installiert, die jedoch später durch ein rein terminalbasiertes System ersetzt wird. Der Fernzugriff via SSH ist bereits vorkonfiguriert, sodass der Server bequem von anderen Geräten im Netzwerk verwaltet werden kann.

## 2. Technical Layer (Aviation-Grade)

### System-Fundament
*   **Hostname:** `q958`
*   **Bootloader:** `systemd-boot` mit EFI-Unterstützung.
*   **Zustands-Version:** `system.stateVersion = "25.11"` (Fixpunkt für Kompatibilität).
*   **Dateisystem:** Import der `hardware-configuration.nix` (Auto-generiert).

### Lokalisierung & Desktop (Temporär)
*   **Zeitzone:** `Europe/Berlin`
*   **Sprache:** `de_DE.UTF-8`
*   **Tastaturlayout:** Deutsch (`de`).
*   **Desktop:** XFCE mit LightDM (Vorbereitung für Headless-Betrieb).
*   **Audio:** Pipewire als moderner Sound-Server.

### Benutzerverwaltung & Rechte
*   **Hauptbenutzer:** `moritz` (Baumeister).
*   **Gruppenzugehörigkeiten:** 
    *   `wheel`: sudo-Berechtigungen.
    *   `networkmanager`: Netzwerkverwaltung.
    *   `video` & `render`: Direkter Zugriff auf Hardware-Beschleunigung (Intel QuickSync).

### Nix-Systemeinstellungen
*   **Experimental Features:** Aktivierung von `nix-command` und `flakes`.
*   **Optimierung:** `auto-optimise-store = true` zur Reduzierung von Duplikaten im Nix-Store.
*   **Garbage Collection:** Wöchentliche automatische Reinigung von Generationen, die älter als 7 Tage sind.

### Netzwerk & Sicherheit
*   **SSH:** OpenSSH aktiviert.
    *   `PermitRootLogin = no` (Sicherheits-Best-Practice).
    *   `PasswordAuthentication = true` (Temporär für initiale Einrichtung).
*   **Firewall:** Port 22 (TCP) explizit für SSH-Verbindungen geöffnet.

### Vorinstallierte Software-Pakete
*   **Editoren:** `vscodium` (Telemetrie-frei), `git`.
*   **Tools:** `htop` (Monitoring), `nix-output-monitor` (Befehl `nom`), `tree`, `unzip`.

## 3. Reasoning Layer (History)

### Architektonische Entscheidungen
*   **XFCE-Wahl:** Die Entscheidung für XFCE als initialen Desktop fiel aufgrund seiner Leichtgewichtigkeit. Ziel ist es, eine vertraute Umgebung für die erste Partitionierung und Repo-Erstellung zu haben, bevor das System auf ein minimales Headless-Setup umgestellt wird.
*   **Frühe GPU-Berechtigungen:** Die Gruppen `video` und `render` wurden bereits jetzt dem Benutzer zugewiesen, um spätere Berechtigungsprobleme bei der Einrichtung von Jellyfin und Hardware-Transcoding (QuickSync) zu vermeiden.
*   **SSH-Übergangsphase:** Password-Authentication ist momentan aktiv, um den ersten "Remote-Sprung" zu ermöglichen. In der nächsten Phase des Masterplans wird dies zwingend auf SSH-Keys umgestellt.

---
*Quelle: Dokument "configuration.nix" (Rohdaten)*
