---
id: "ARCH-50-service-manifest"
title: "ARCH 5000 service manifest"
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
# 📋 SERVICE-MANIFEST: Der mynixos Stack

Dieses Manifest ist die unveränderliche Single Source of Truth für alle Dienste, die auf dem Fujitsu Q958 (Tower) betrieben werden. Jede Änderung erfordert eine ADR.

## 1. User Layer (KISS)
Hier stehen alle Programme, die dein Server ausführen wird. Wir haben "Müll" (ineffiziente oder nicht-native Software) entfernt und durch Aviation-Grade Alternativen ersetzt. Ziel: Ein stabiles, schnelles System, das komplett deklarativ ist.

## 2. Technical Layer (Aviation-Grade)

### LAYER 00-core (System-Fundament)
| Dienst | Methode | Status |
|---|---|---|
| fail2ban | services.fail2ban | ✅ nativ |
| sops-nix | flake-input | ✅ nativ |
| nftables | services.nftables | ✅ nativ |

### LAYER 20-server (Infrastruktur)
| Dienst | Methode | Binary |
|---|---|---|
| caddy | services.caddy | ✅ Go |
| adguardhome | services.adguardhome | ✅ Go |
| tailscale | services.tailscale | ✅ Go |
| cloudflared | services.cloudflared | ✅ Go |
| pocket-id | nixpkgs-paket + systemd | 🟡 Go |
| postgresql | services.postgresql | ✅ C |
| valkey | services.valkey | ✅ C (Redis-Fork) |
| ddns-updater | nixpkgs-paket + systemd | 🟡 Go |

### LAYER 30-services (Produktivität)
| Dienst | Methode | Binary |
|---|---|---|
| vaultwarden | services.vaultwarden | ✅ Rust |
| n8n | services.n8n | ✅ Node.js |
| home-assistant | services.home-assistant | ✅ Python |
| matrix-conduit | services.matrix-conduit | ✅ Rust |
| homepage | services.homepage-dashboard | ✅ JS |
| semaphore | nixpkgs-paket + systemd | 🟡 Go |

### LAYER 40-media (Entertainment)
| Dienst | Methode | Status |
|---|---|---|
| jellyfin | services.jellyfin | ✅ nativ |
| sonarr | services.sonarr | ✅ nativ |
| radarr | services.radarr | ✅ nativ |
| lidarr | services.lidarr | ✅ nativ |
| prowlarr | services.prowlarr | ✅ nativ |
| sabnzbd | services.sabnzbd | ✅ nativ |
| audiobookshelf | nixpkgs-paket + systemd | 🟡 paket |
| seerr | services.seerr | ✅ nativ |
| recyclarr | nixpkgs-paket + systemd | 🟡 paket |

### LAYER 50-knowledge (Wissen)
| Dienst | Methode | Binary |
|---|---|---|
| paperless | services.paperless-ngx | ✅ nativ |
| miniflux | services.miniflux | ✅ Go (Ersatz für Stringer) |
| readeck | nixpkgs-paket + systemd | 🟡 Go |
| linkding | services.linkding | ✅ nativ |

### LAYER 80-monitoring (SRE)
| Dienst | Methode | Status |
|---|---|---|
| scrutiny | services.scrutiny | ✅ nativ |

## 3. Reasoning Layer (ADR Context)
- **Miniflux > Stringer:** Stringer (Ruby) wurde aufgrund des Binary-Mandats durch Miniflux (Go) ersetzt.
- **Valkey > Redis:** Valkey ist der bevorzugte, quelloffene C-Fork für Caching.
- **Lidarr-Addition:** Musik-Management wurde zur Vervollständigung des ARR-Stacks hinzugefügt.
- **Ejection Policy:** Alle Dienste auf der "Rauswurf-Liste" (Traefik, Redis, PHP-Stack) sind permanent verboten.