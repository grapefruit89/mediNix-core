---
id: 54-processing
title: Processing & Storage Maintenance Domain
description: Manages media downloading and storage tiering (SSD to HDD).
aliases: [Processing, SABnzbd, Mover]
tags: [architecture, medinix, download, sabnzbd, tiering]
anchors: [staging-and-tiering, bulkhead, defense-in-depth, pipes-and-filters]
---

# 54-processing: Processing & Storage Maintenance

The **Processing & Storage Maintenance Domain** (Domain 54) handles the heavy lifting of moving data. It is responsible for downloading media securely via Usenet and managing the flow of data across different storage tiers (from high-speed SSD staging to high-capacity HDD cold storage).

## ⚓ Semantic Anchors

- **`Staging & Tiering`:** Temporary high-speed buffer on SSD decoupled from spinning cold storage.
- **`Bulkhead Pattern` / `Defense in Depth`:** Downloader runs strictly in the VPN network namespace with automated leak-prevention.
- **`Pipes and Filters Pattern`:** Discrete processing stages for ingest, validation, extraction, and relocation.

## 🎯 Core Responsibilities

1. **Usenet Downloading:** Running SABnzbd to fetch files requested by the Acquisition domain (Domain 53).
2. **Storage Tiering (The Mover):** An event-driven script that monitors the SSD staging area (Tier-B). If it gets too full, the Mover automatically transfers large media files to the spinning HDD archive (Tier-C) to free up space, preventing the SSD from filling up completely.

## 🧩 Services in the Dezimalrahmen

Each module is configured according to the mediNix Dezimalrahmen convention:

| ID  | Module / Service | Port/UID | Status | Responsibility |
| :--- | :--- | :--- | :--- | :--- |
| **541** | [sabnzbd](541-sabnzbd.nix) <br> [ADR-526](../docs/adr/ADR-526-vpn-killswitch.md) | `5410` | active | **SABnzbd** — The primary Usenet downloader. Writes strictly to the SSD staging directory. |

*(Hinweis: Der Tier-B → Tier-C Mover wurde im Rahmen der Storage-Konsolidierung in [`570-storage.nix`](../57-maintenance/570-storage.nix) überführt).*

## 🔗 Dependencies & Architecture Graph

Die Module in diesem Ordner greifen auf folgende zentrale System-Bibliotheken zurück:

- `50-core/hardening-profiles` (Python- und Skript-Hardening)
- `50-core/registry` (SSoT für Port 5410, UID 5410, StateDir)

```mermaid
graph TD
  541_sabnzbd["541-sabnzbd"] --> hardening_profiles["50-core/hardening-profiles"]
  541_sabnzbd["541-sabnzbd"] --> registry["50-core/registry"]
```

## 🛡️ Key Architecture Decisions

- **Storage-Zentrum & Mover:** Der Mover läuft kanonisch über [`570-storage.nix`](../57-maintenance/570-storage.nix) ([ADR-570](../docs/adr/ADR-570-storage-tiering-mergerfs.md)). Er wacht nur auf, wenn Daten auf der SSD liegen und verschiebt erst bei Bedarf auf die HDDs, um Spindown zu maximieren.
- **Mover Safety Safeguards:** Active-handle check via `lsof -t` avoids touching files actively written by unpackers; a 5-minute age buffer (`-mmin +5`) ensures write finality; atomic publish via `.staging_mover` and `mktemp` prevents partially transferred files from being visible; destination collision checks prevent silent overwrites; concurrency protection via `flock`; source files are deleted only upon verified transfer success. Operates directly on the physical storage backends (SSD HOT → HDD COLD) while Jellyfin reads seamlessly via MergerFS.
- **RAM-Disk for Downloads:** SABnzbd (`541-sabnzbd.nix`) uses a `tmpfs` (RAM disk) mounted at `/run/sabnzbd-tmp` for its temporary download chunks. This drastically reduces write wear on the SSD during the unpacking and repairing phase of large media files.
- **TPM-Bound Provider Credentials:** Usenet provider credentials are not stored in plaintext. They are injected directly from a TPM-encrypted `systemd-credential` file at runtime (`LoadCredentialEncrypted`).
- **Defense-in-Depth Network Confinement:** SABnzbd is dual-protected when usenet-confinement is active: nftables policy routing routes Usenet traffic over the VPN interface with a hard drop rule, while systemd's cgroup-BPF `RestrictNetworkInterfaces = [ "lo" vpnIf ]` restricts network interfaces directly in the Linux kernel.
