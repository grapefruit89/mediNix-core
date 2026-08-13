---
id: "ARCH-50-architecture-principles"
title: "ARCH 5000 architecture principles"
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
# NixHome Architecture: Principles and NIXH-ID System

## 1. User Layer (KISS)
Dieses Dokument definiert die "ehernen Gesetze" und das Ordnungssystem für das NixHome-Homelab. Es basiert auf dem Grundsatz der Einfachheit und Reproduzierbarkeit. Wir verzichten bewusst auf Container (Docker/Podman) und Kompilationen, um ein schlankes, rein binärbasiertes System zu erhalten. Jedes Modul erhält eine eindeutige ID (NIXH-ID), um die Verwaltung und Automatisierung (via NixHome-Forge) zu perfektionieren.

## 2. Technical Layer (Aviation-Grade)

### Absolute Prinzipien (Mandatory)
1.  **Binary-only:** `nix.settings.max-jobs = 0`. Keine lokalen Kompiliervorgänge. Alles wird über offizielle Binär-Caches bezogen.
2.  **No Container:** Striktes Verbot von Docker, Podman oder OCI-Containern. Alle Dienste laufen nativ als NixOS-Module. Validierung durch Policy-Assertions in `90-policy/`.
3.  **Paket-Priorität:** 
    *   Priorität 1: Natives NixOS-Modul (`services.X.enable`).
    *   Priorität 2: Paket aus Nixpkgs (`pkgs.X`).
    *   Priorität 3: Externer Flake-Input.
4.  **Security-Level:** "Only as secure as necessary, not as secure as possible." Fokus auf pragmatische Sicherheit ohne unnötigen Overhead.

### Layer-Struktur (/etc/nixos)
Das System ist in 10 Schichten unterteilt:
*   **00-core:** Basis-System (SSH, User, Boot, Firewall).
*   **10-server:** Infrastruktur-Dienste (Caddy, Tailscale, AdGuard, Pocket-ID).
*   **20-shared:** Gemeinsam genutzte Backends (PostgreSQL, Valkey/Redis).
*   *...weitere Layer bis 90-policy (System-Assertions).*

### NIXH-ID System
Jedes Modul wird nach dem Schema `NIXH-{Layer}-{ABB}-{NNN}` identifiziert:
*   **Layer:** Zweistellige Nummer (00-90).
*   **ABB:** Drei-Buchstaben-Abkürzung (z.B. COR, SRV, MED).
*   **NNN:** Fortlaufende dreistellige Nummer.
*   *Beispiel:* `NIXH-40-MED-001` für die erste Medien-Komponente.

### MCP-Tooling: NixHome-Forge
Ein spezialisierter MCP-Server (`nixhome-forge`) unterstützt den Workflow:
1.  `research()`: Pakete und Optionen in Nixpkgs finden.
2.  `generate()`: Module basierend auf dem Layer-Konzept erzeugen.
3.  `validate()`: Code-Qualität und IDs prüfen.

## 3. Reasoning Layer (History)

### Philosophische Herleitung
*   **Anti-Container-Entscheidung:** In einer rein deklarativen Umgebung wie NixOS bieten Container oft nur eine zusätzliche Abstraktionsschicht ohne echten Mehrwert bei der Reproduzierbarkeit, erhöhen aber den Ressourcenverbrauch und die Komplexität des Netzwerk-Stackings.
*   **Binary-only Mandat:** Schont die Hardware (i3-9100) und sorgt für deterministische Deployment-Zeiten. Da der Fujitsu Q958 keine Compile-Farm ist, wird die Rechenleistung für Dienste reserviert.
*   **ID-System:** Die NIXH-ID ist notwendig, um in einer wachsenden Konfiguration mit über 40 Diensten die Übersicht zu behalten und Port-Kollisionen (Bereich 49152+) automatisiert zu verhindern.

---
*Quelle: Claude-Software-Konzepte für NixHome MetaBibliothek (März 2026)*
