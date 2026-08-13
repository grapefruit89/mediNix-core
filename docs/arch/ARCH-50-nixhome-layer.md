---
id: "ARCH-50-nixhome-layer"
title: "ARCH 5000 nixhome layer"
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
# Architecture: NIXHOME Layer-Structure & Meta-Standard

## 1. User Layer (KISS)
Dieses Dokument definiert, wie wir Ordnung in deine über 90 Nix-Konfigurationsdateien bringen. Jede Datei hat einen festen Platz in einem von sieben Schichten (Layern) und trägt einen "Ausweis" (Meta-Header) am Anfang. Dieser Header verrät uns (und der KI) sofort, was das Modul tut, welche Ports es nutzt und wovon es abhängig ist. So bleibt dein System auch bei massivem Wachstum übersichtlich und durchsuchbar.

## 2. Technical Layer (Aviation-Grade)

### Die 7-Layer Architektur
Jedes Modul wird anhand einer Kernfrage einem Layer zugeordnet:
*   **00-core:** Ohne dies ist das OS unsicher oder startet nicht. (SSH, Firewall, Boot).
*   **20-server:** Ohne dies ist der Server nicht erreichbar. (Caddy, Tailscale, DNS, DBs).
*   **30-services:** Dienste, die du täglich nutzt. (Vaultwarden, Home Assistant, n8n).
*   **40-media:** Alles rund um Audio/Video. (Jellyfin, ARR-Stack).
*   **50-knowledge:** Persönliches Wissen & Dokumente. (Paperless, Monica, RSS).
*   **80-monitoring:** Passive Beobachtung des Systems. (Netdata, Uptime Kuma).
*   **90-policy:** Regeln und Enforcement. (Assertions, Struktur-Checks).

### Der NMS-Meta-Header Standard
Jede `.nix`-Datei muss mit folgendem Block beginnen (Obsidian & AI kompatibel):
```nix
/**
 * ---
 * nms_version: "2.3"
 * id: "NIXH-40-MED-001"           # Format: NIXH-{Layer}-{ABB}-{NNN}
 * title: "Jellyfin Media Server"
 * description: "Hardware-accelerated media server"
 * layer: 40
 * resources:
 *   port: 20096                  # Zentral registriert in ports.nix
 *   state_path: "/data/state/jellyfin"
 * audit:
 *   last_reviewed: "2026-03-08"
 *   complexity: 3
 * ---
 */
```

### Modul-Prioritäten & SSoT
1.  **configs.nix (00-core):** Master-Konfiguration (Hardware-IDs, IPs).
2.  **ports.nix (00-core):** Zentrales Port-Register (Bereich 49152+).
3.  **defaults.nix (00-core):** Standard-Einstellungen für alle Module.

## 3. Reasoning Layer (History)

### [ADR-010] NMS-Meta-Header für Knowledge-Integration
*   **Status:** Entschieden (März 2026).
*   **Kontext:** Mit steigender Anzahl an Modulen wird es für LLMs und den Nutzer schwierig, Abhängigkeiten und Ressourcen (Ports) ohne vollständiges Parsen des Codes zu verstehen.
*   **Entscheidung:** Einführung eines YAML-kompatiblen Kommentar-Blocks am Dateianfang.
*   **Vorteile:** Direkte Nutzung in **Obsidian** (Dataview-Queries), schnelle Extraktion durch **Claude/Gemini**, strikte Port-Kontrolle.

### [ADR-011] Transparente flake.nix (Option B)
*   **Status:** Entschieden (März 2026).
*   **Kontext:** Import-Hubs (`_imports.nix`) verstecken die tatsächliche Struktur des Systems vor der `flake.nix`.
*   **Entscheidung:** Wir listen alle Module explizit in der `flake.nix` auf.
*   **Vorteil:** Maximale Transparenz. Man sieht beim ersten Blick in die `flake.nix`, welche Dienste aktiv sind und in welcher Reihenfolge sie geladen werden.

---
**Sources:**
*   `/home/Knowledge-Pipeline/raw/_duplikate/NIXHOME_META_AND_FLAKES.md`
*   `/home/Knowledge-Pipeline/raw/_duplikate/NIXHOME_ARCHITECTURE.md`
*   `/home/Knowledge-Pipeline/raw/_duplikate/geminiverbesserung.txt`
