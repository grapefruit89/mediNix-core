---
id: "ARCH-50-architecture-blueprint"
title: "ARCH 5000 architecture blueprint"
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
# NixOS Architecture Master Blueprint (Host: q958)

## 1. User Layer (KISS)
Dieser Master-Blueprint dient als zentrale Wissensbasis für den Aufbau und Betrieb des Fujitsu Q958 Homeservers. Die Architektur folgt dem Prinzip **"Infrastructure as Code" (IaC)** unter Nutzung von **NixOS Flakes**. Das System ist so konzipiert, dass es vollständig reproduzierbar ist und alle Dienste (Medien, Infrastruktur, Hausautomatisierung) in logischen Schichten (Tiers) organisiert sind. Der Fokus liegt auf maximaler Sicherheit (SSO/mTLS) bei gleichzeitig hoher Effizienz (HDD Spindown/QuickSync).

## 2. Technical Layer (Aviation-Grade)

### Hardware-Plattform
*   **Maschine:** Fujitsu Q958 (i3-9100, 16GB RAM).
*   **Grafik:** Intel UHD 630 (QuickSync Support für H.264/H.265/HEVC).
*   **Storage-Layout:**
    *   **OS/Appdata:** Micron/Crucial SATA SSD (~512 GB).
    *   **Download-Cache:** Apacer NVMe (~250 GB) für `/downloads`.
    *   **Media-Pool:** Direkte Mounts von Seagate (300GB), Hitachi (500GB) und WD (500GB) HDDs unter `/storage/`.

### Storage-Logik & Spindown-Optimierung
*   **Dateisystem:** Konsequente Nutzung von **ext4** (einfach, stabil, kein unnötiges Aufwecken).
*   **Spindown:** Einsatz von `hd-idle` (Timeout: 600s).
*   **Atomic Move:** Um HDD-Spindown zu schützen, liegen Downloads auf der NVMe. Nach Fertigstellung erfolgt der Transfer via Hardlinks/Atomic-Moves ausschließlich innerhalb von `.staging`-Ordnern auf der jeweiligen Ziel-HDD.

### Netzwerk & Sicherheit
*   **Reverse Proxy:** Traefik mit Let's Encrypt (DNS-Challenge via Cloudflare).
*   **SSO/Identity:** **Pocket ID** (OIDC-Provider für Passkeys) + Traefik ForwardAuth.
*   **VPN:** WireGuard (Tailscale für Management, VPN-Confinement via Maroka-chan für Downloads).
*   **Secrets:** `sops-nix` mit Age-Keys, verschlüsselt im Git-Repository.

### Modulare Flake-Struktur
```text
mynixos/
├── hosts/
│   ├── q958/                  # Host-spezifische Config (hardware-configuration.nix, default.nix)
│   └── common/core/           # Basis-Konfiguration (Users, SSH, Firewall)
└── modules/
    ├── 00-system/             # Nix-Settings, Storage/Mounts
    ├── 10-infrastructure/     # Traefik, Tailscale, Pocket ID, AdGuard
    ├── 20-backend-media/      # ARR-Stack (Sonarr, Radarr, Prowlarr, SABnzbd, Recyclarr)
    ├── 30-frontend-media/     # Jellyfin, Audiobookshelf, Jellyseerr
    └── 40-services/           # Vaultwarden, Home Assistant, Paperless, n8n, etc.
```

### Spezifische Service-Implementierungen
*   **Jellyfin:** Native NixOS-Implementierung mit `intel-media-driver` und `intel-compute-runtime` für QuickSync.
*   **SABnzbd:** VPN-Isolierung mittels Network Namespaces (Maroka-chan).
*   **Vaultwarden:** Bewusste Isolation vom SSO-System zur Erhöhung der Sicherheit.
*   **Valkey:** Ersatz für Redis (aufgrund von Lizenzänderungen).

## 3. Reasoning Layer (History)

### Strategische Entscheidungen vs. Alternativen
*   **Abgrenzung zu mergerfs/ZFS:** mergerfs wurde abgelehnt, da es beim Einlesen von Verzeichnissen alle HDDs gleichzeitig weckt. ZFS wurde aufgrund des Overkills für die geringe Speicherkapazität (1.3TB) und des komplexeren Managements verworfen.
*   **NixOS native vs. Docker:** Über 20 Services werden nativ als NixOS-Module betrieben, um die volle deklarative Kontrolle über Dependencies und Updates zu behalten.
*   **Pocket ID vs. Authelia:** Pocket ID wurde aufgrund seines geringen Footprints (~20MB RAM) und der modernen Passkey-Unterstützung gegenüber dem funktional schwereren Authelia bevorzugt.
*   **Maroka-chan VPN:** Die Wahl fiel auf Maroka-chan, da es eine saubere Trennung des Netzwerk-Stacks auf Kernel-Ebene ermöglicht, ohne den gesamten Host-Traffic zu tunneln.

---
*Quellen: NIXOS_BRIEFING.md, NIXOS_MASTER_BRIEFING.md (Februar 2026)*
