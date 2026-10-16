---
id: "GUIDE-52-media-hardening"
title: "GUIDE 52 — Media-Stack: VPN-Confinement & QuickSync"
domain: 52
status: active
complexity: 2
last_reviewed: 2026-10-17
tags:
  - hardening
  - media
  - security
links:
  adr: ""
  repo-harvest: ""
---
# 🎬 Media-Stack: VPN-Confinement & QuickSync

## 🛡️ VPN-Confinement (kein netns)
SABnzbd (`54-transfer/541-sabnzbd.nix`, UID 5410) ist doppelt gebunden:

- **nftables Policy-Routing** über `52-security/526-vpn-killswitch.nix`:
  `meta skuid`-Markierung → Routing-Tabelle → hard drop; fehlt die VPN-Route,
  greift `unreachable`.
- **Kernel-Level** `RestrictNetworkInterfaces = [ "lo" vpnIf ]` (cgroup-eBPF).

Kein Network-Namespace — die frühere netns/„Maroka-chan"-Lösung ist ersetzt.
Downloads laufen über ein **tmpfs** (`/run/sabnzbd-tmp`), damit Reparieren/Entpacken
die SSD schont.

## ⚡ Hardware-Transcoding (Intel QuickSync)
Jellyfin (`55-playback/551-jellyfin.nix`) nutzt das Härtungsprofil `dotnet-gpu`:
gezielte `DeviceAllow`-Freigabe für `/dev/dri`, ohne `PrivateDevices=false`
systemweit aufzuweichen. Das Transcode-Verzeichnis liegt auf einem
`TemporaryFileSystem` (tmpfs).

## 📂 Daten-Sicherheit
Medien werden **read-only** gemountet (`BindReadOnlyPaths`) — die Player können die
Bibliothek lesen, aber nie ändern oder löschen.

Quellen: `54-transfer/README.md`, `55-playback/README.md`, Root-`README.md`,
`docs/concepts/vpn-killswitch.md`.
