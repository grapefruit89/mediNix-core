---
id: "ARCH-50-mcp-integrations"
title: "ARCH 5000 mcp integrations"
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
# MCP Integrations: Home Assistant & Unraid

## 1. User Layer (KISS)
Dieses Dokument beschreibt, wie Claude Desktop direkt mit deinem Smarthome (Home Assistant) und deinem Server-Management (Unraid) kommuniziert. Anstatt nur über diese Systeme zu sprechen, kann Claude durch MCP (Model Context Protocol) aktiv Geräte schalten, Automationen erstellen oder den Gesundheitszustand deiner Festplatten prüfen. Wir nutzen dabei bevorzugt die offiziellen, in die Software integrierten Schnittstellen.

## 2. Technical Layer (Aviation-Grade)

### Home Assistant MCP (Native)
Seit Version **2025.2** verfügt Home Assistant über einen eingebauten MCP-Server.
*   **Voraussetzung:** Home Assistant v2025.2+, Long-Lived Access Token (erstellt in HA unter Benutzerprofil -> Ganz unten).
*   **Aktivierung:** Einstellungen -> Geräte & Dienste -> Integration hinzufügen -> "MCP Server".
*   **Claude Desktop Config (Windows):**
```json
{
  "mcpServers": {
    "home-assistant": {
      "command": "uvx",
      "args": ["ha-mcp@latest"],
      "env": {
        "HOMEASSISTANT_URL": "http://192.168.2.73:8123",
        "HOMEASSISTANT_TOKEN": "DEIN_TOKEN"
      }
    }
  }
}
```
*   **Capabilities:** Entitäten steuern, Zustände abfragen, Automationen lesen/schreiben.

### Unraid MCP Integration
Ermöglicht das Management des Unraid-Hosts (falls vorhanden oder als Teil der Infrastruktur).
*   **Voraussetzung:** Installation der "unraid-api" via Community Applications.
*   **Funktionen:**
    *   **Docker/VM:** Start, Stopp, Konfiguration.
    *   **Array:** Status, Paritätsprüfung, Festplatten-Temperaturen.
    *   **Logs:** System-Fehleranalyse in Echtzeit.
*   **Anbindung:** Erfolgt über den spezialisierten `unraid-mcp` Server (bereits in der Tool-Umgebung aktiv).

## 3. Reasoning Layer (History)

### Warum native Integration?
*   **Sicherheit [ADR]:** Frühere Ansätze über generische Shell-MCPs (`mcp-shell`) wurden als unsicher eingestuft (`[SUPERSEDED]`), da sie der KI vollen Root-Zugriff gewähren. Native APIs begrenzen den Handlungsspielraum auf definierte Funktionen (z.B. Licht schalten, nicht System löschen).
*   **Effizienz:** Die Nutzung von `uvx ha-mcp` stellt sicher, dass immer die aktuellste Version der Schnittstelle genutzt wird, ohne manuelle Python-Umgebungen auf dem Client-PC pflegen zu müssen.
*   **Context-Awareness:** Durch die direkte Anbindung an Home Assistant "sieht" Claude die Struktur deiner Räume und Geräte, was die Generierung von Automationen massiv verbessert (kein Raten von Entitäts-IDs).

---
*Quelle: Knowledge-Transfer aus Claude-Chat (März 2026)*
