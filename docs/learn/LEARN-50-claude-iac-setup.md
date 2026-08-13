---
id: "LEARN-50-claude-iac-setup"
title: "LEARN 5000 claude iac setup"
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
# NixOS Server Infrastructure as Code Setup (Fujitsu Q958)

## 1. User Layer (KISS)
Dieses Dokument beschreibt den Masterplan für den Aufbau eines hochverfügbaren und sicheren Heimservers auf Basis von **NixOS**. Das Ziel ist ein "Infrastructure as Code" (IaC) Ansatz, bei dem die gesamte Serverkonfiguration in Textdateien (Nix Flakes) gespeichert wird. Dies ermöglicht eine exakte Wiederherstellung und einfache Wartung. Der Server (ein Fujitsu Q958) dient als Zentrale für Medien (Jellyfin), Hausautomatisierung (Home Assistant) und Passwortverwaltung (Vaultwarden), wobei der Zugriff streng nach Sicherheitsstufen (Tiers) unterteilt ist.

## 2. Technical Layer (Aviation-Grade)

### Hardware-Spezifikation & Optimierung
*   **Host:** Fujitsu Q958.
*   **Storage-Strategie:** 
    *   **OS/Appdata:** NVMe SSD (Samsung/Micron).
    *   **Download-Cache:** Separate NVMe (Apacer) zur Entlastung der HDDs.
    *   **Media-Storage:** Direkte HDD-Mounts mit Fokus auf Spindown-Optimierung (`hd-idle`).
*   **GPU:** Nutzung von Intel QuickSync für Hardware-Transcoding in Jellyfin.

### Sicherheits-Architektur (Tier-System)
Der Zugriff wird über Traefik als Reverse Proxy mit mTLS und SSO (Pocket ID) gesteuert:
*   **Tier 0 (Intern):** mTLS + SSO + VPN (Tailscale). Dienste: Sonarr, Radarr, SABnzbd, AdGuard, Semaphore.
*   **Tier 1 (Inhouse/KI):** mTLS + SSO. Dienste: Home Assistant, n8n, OpenVSCode.
*   **Tier 2 (Freunde):** SSO via Pocket ID. Dienste: Jellyfin, Audiobookshelf, Jellyseerr.
*   **Tier 3 (Maximum Security):** Vaultwarden (Ausschluss aus SSO, direkter Login).

### Software-Stack & IaC-Komponenten
*   **Core:** NixOS Unstable, Flakes, `sops-nix` (Secret Management), `disko` (Partitionierung).
*   **Infrastruktur:** Traefik, Tailscale, Step-CA (lokale PKI), Pocket ID (Identity Provider).
*   **Media-Stack:** ARR-Stack (Sonarr, Radarr, Prowlarr), Recyclarr (automatisierte TRaSH-Guides), PostgreSQL als Backend für ARR-Dienste.

### Verzeichnisstruktur (Vorbild: ironicbadger)
```text
nix-config/
├── flake.nix                  # Zentrale Definition
├── hosts/
│   └── q958/                  # Host-spezifisch
├── common/                    # Gemeinsame Module (User, SSH, Firewall)
└── modules/
    ├── 00-system/             # Storage, Nix-Settings
    ├── 10-infrastructure/     # Traefik, Tailscale, Pocket ID
    ├── 20-backend-media/      # ARR-Stack
    └── 30-frontend-media/     # Jellyfin, Audiobookshelf
```

### Spezielle Logik: "Atomic Move"
Um die HDDs im Spindown zu halten, werden Downloads auf der NVMe gepuffert und erst nach Abschluss via Hardlinks/Atomic-Moves (innerhalb von `.staging`-Ordnern auf der Ziel-HDD) verschoben.

## 3. Reasoning Layer (History)

### Architektonische Herleitung
Die Entscheidung für diese Struktur basiert auf einem detaillierten Vergleich bestehender Frameworks:
*   **nixarr vs. nixflix:** `nixarr` bietet ein stabiles Fundament für den ARR-Stack, während `nixflix` innovative Ideen für die API-basierte Konfiguration liefert. Es wurde entschieden, kein "Komplettpaket" zu nutzen, sondern die Stabilität von `nixarr`-Konzepten mit der Flexibilität einer eigenen Struktur (basierend auf `ironicbadger/nix-config`) zu kombinieren.
*   **KI-gestützte Konfiguration:** Statt rein deklarativer Nix-Module für die interne ARR-Vernetzung wird ein idempotentes Python-Skript (generiert via KI/Context7) genutzt, um die REST-APIs der Dienste direkt anzusprechen. Dies umgeht die Komplexität der rein deklarativen API-Einrichtung in Nix.
*   **SSO-Entscheidung:** Die Trennung von Vaultwarden aus dem SSO-Verbund ist eine bewusste Sicherheitsentscheidung, um zu verhindern, dass eine Kompromittierung des Identity Providers (Pocket ID) sofortigen Zugriff auf alle Passwörter ermöglicht.

---
*Quelle: Dokument "Claude-01 NixOS Server mit Infrastructure as Code aufsetzen.md" (Rohdaten)*
