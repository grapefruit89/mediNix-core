---
id: 55-playback
title: Playback & Presentation Domain
description: Manages media servers and frontends for user consumption.
aliases: [Playback, Presentation, Jellyfin]
tags: [architecture, medinix, playback, jellyfin, navidrome, audiobookshelf]
---

# 55-playback: Playback & Presentation Domain

The **Playback & Presentation Domain** (Domain 55) is the "face" of mediNix-core. It hosts the media servers that index the final Tier-C storage and present it to the end users across various devices (Smart TVs, browsers, mobile apps). 

This domain focuses heavily on performance (Hardware Transcoding), frontend routing, and strict read-only access to the media library to ensure the presentation layer can never accidentally delete or corrupt data.

## 🎯 Core Responsibilities

1. **Media Streaming:** Serving video, audio, and books to clients.
2. **Hardware Transcoding:** Utilizing GPU acceleration (VA-API/QuickSync) to convert media on-the-fly for clients that do not support the original format.
3. **Library Presentation:** Providing polished, user-friendly Web UIs and API endpoints for dedicated apps.
4. **Data Safety:** Enforcing a strict "Read-Only" policy for the main media library (`BindReadOnlyPaths`). The media servers can only read the media, never modify or delete it.

## 🧩 Services in the Dezimalrahmen

Each module is strictly configured according to the mediNix Dezimalrahmen convention:

| ID  | Service | UID / Port | Responsibility |
| :--- | :--- | :--- | :--- |
| **551** | [Jellyfin](551-jellyfin.nix) <br> [[ADR-5510]] | `5510` | The primary video and general media server. Handles heavy lifting like GPU transcoding. |
| **552** | [Audiobookshelf](552-audiobookshelf.nix) <br> [[ADR-5520]] | `5520` | Dedicated server for audiobooks and podcasts. (Note: Has limited write access to write cover art). |
| **553** | [Navidrome](553-navidrome.nix) <br> [[ADR-5530]] | `5530` | Lightweight, lightning-fast music server compatible with the Subsonic API. |
| **554** | [Feishin](554-feishin.nix) <br> [[ADR-5530]] | N/A | A modern, static Single Page Application (SPA) frontend for Navidrome or Jellyfin. Served directly via Caddy. |
| **561** | [Seerr](555-seerr.nix) <br> [[ADR-5610]] | `5610` | The central request portal for users to discover and request new media, bridging the gap to the `*arr` stack. |

## 🛡️ Key Architecture Decisions

- **Hardware Acceleration (VA-API):** Jellyfin uses the `dotnet-gpu` hardening profile. It selectively pokes holes in the sandbox (`DeviceAllow`) to access `/dev/dri`, enabling ultra-efficient Intel QuickSync transcoding without exposing the entire host hardware (`PrivateDevices=false`).
- **Transcode RAM Disk:** Jellyfin's transcode directory is mounted as a `TemporaryFileSystem` (tmpfs). This ensures that heavy, temporary transcode chunks are written to RAM instead of burning through the SSD's write endurance.
- **Strict Read-Only Mounts:** Services like Jellyfin and Navidrome mount the primary media directories via `BindReadOnlyPaths`. Any attempt by the application (or an attacker exploiting the application) to delete a movie or song will be blocked at the kernel/systemd level.
- **Static SPA Injection:** Feishin (`554-feishin.nix`) is not a running service. It is a static web app injected directly into Caddy's configuration via `try_files {path} /index.html`, eliminating the need for an unnecessary NodeJS backend process.
