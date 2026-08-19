---
id: 53-acquisition
title: Acquisition Domain (*arr Suite)
description: Manages media acquisition services using the *arr stack.
aliases: [Acquisition, arr-suite]
tags: [architecture, medinix, acquisition, arr]
---

# 53-acquisition: Media Acquisition

The **Acquisition Domain** (Domain 53) is the "brain" of media procurement in mediNix-core. It is responsible for searching for, monitoring, and delegating the download of new media (series, movies, music, books) to the appropriate download clients (which live in another domain, like `54-download`).

This folder encapsulates the entire **\*arr suite** (Sonarr, Radarr, etc.) in strictly isolated Systemd services.

## 🎯 Core Responsibilities

1. **Monitoring:** Watching configured lists (e.g., Trakt, IMDB) or manual requests for new releases.
2. **Indexing:** Searching for matching releases on Usenet indexers or torrent trackers. This is managed centrally by Prowlarr.
3. **Download Delegation:** Sending the found `.nzb` or `.torrent` files to the appropriate download client (e.g., SABnzbd).
4. **Post-Processing (Organization):** Once the download client finishes, the *arr services take over renaming, moving, and organizing the files into the final media library (Tier C Storage).

## 🧩 Services in the Dezimalrahmen

Each service is strictly configured according to the mediNix Dezimalrahmen convention and runs under its own isomorphic UID/Port combination:

| ID  | Service | UID / Port | Responsibility |
| :--- | :--- | :--- | :--- |
| **532** | [Sonarr](532-sonarr.nix) <br> [[ADR-5320]] | `5320` | Management and automation of **series** (TV Shows). |
| **533** | [Radarr](533-radarr.nix) <br> [[ADR-5320]] | `5330` | Management and automation of **movies**. |
| **534** | [Readarr](534-readarr.nix) <br> [[ADR-5320]] | `5340` | Management and automation of **books** and audiobooks. |
| **535** | [Lidarr](535-lidarr.nix) <br> [[ADR-5320]] | `5350` | Management and automation of **music**. |
| **536** | [Prowlarr](536-prowlarr.nix) <br> [[ADR-5320]] | `5360` | **Central Indexer Manager**. It proxies search engines (indexers) to the other *arr services. |

## 🛡️ Security Architecture & Hardening

The services in this domain process external data (APIs, feeds) and interact with download clients. Therefore, they are heavily secured:

- **Factory-based Hardening:** All services are built using the central `service-factory.nix` and utilize the `dotnet` profile.
- **Network Isolation:** Via `RestrictNetworkInterfaces = [ "lo" ]` (Loopback-Only), it is ensured that the services do not communicate with the WAN uncontrollably and are not reachable locally, except through defined routes (Caddy Ingress).
- **Filesystem Protection:** `ProtectSystem = "strict"` and `PrivateTmp = true`. The services only have read/write access to their own `stateDir` (e.g., `/var/lib/sonarr-5320`) and the designated `mediaRoot`.
- **Shared GID 5000 (`media`):** Since the *arr services (Domain 53), the download clients (Domain 54), and the media servers (Domain 55) all need access to the same files, they share the `media` group (GID 5000). The `UMask = "002"` ensures that newly created files can be read and written by the entire group.

## ⚙️ Declarative Configuration (`arr-settings.nix`)

Instead of configuring the *arr services on startup via fragile `curl` scripts, mediNix-core utilizes native `.NET` configuration injection via environment variables.
The `lib/arr-settings.nix` file injects settings like ports, authentication methods (OIDC/Forms), and UI themes directly into the Systemd service upon startup. Service updates (`update.mechanism = "BuiltIn"`) are managed by NixOS, which is why the apps' internal updaters are disabled in the settings.
