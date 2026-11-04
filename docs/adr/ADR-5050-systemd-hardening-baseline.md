---
id: "ADR-5050"
title: "ADR 5050 systemd hardening baseline"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-11-04
tags:
  - hardening
  - security
links:
  adr: ADR-5000
  repo-harvest: ""
---
# ADR-5050: systemd Service Hardening Baseline (50-core)

## Status: active
## Date: 2026-08-11
## Source: Grok raw pivots (systemd_opt patterns) + ADR-5200
## Reviewed: 2026-11-04 — neu gefasst gegen den Ist-Code (`50-core/hardening-profiles.nix`)

## Context
Multiple pivots confirm the same systemd hardening options recur across all mediNix
services. These must be a baseline, not per-service ad-hoc.

## Decision — profilbasierte Baseline, nicht eine Liste für alle

Die Baseline ist ein **Profil**, kein Satz loser Optionen. `50-core/hardening-profiles.nix`
ist die einzige Quelle:

- **`base`** — die gemeinsame Härtung: `NoNewPrivileges`, `ProtectSystem = "strict"`,
  `ProtectHome`, `PrivateTmp`, `PrivateUsers`, `ProtectKernel{Tunables,Modules,Logs}`,
  `ProtectProc = "invisible"`, `ProcSubset = "pid"`, `RestrictNamespaces`,
  `RestrictSUIDSGID`, `RestrictRealtime`, `LockPersonality`,
  `SystemCallFilter = [ "@system-service" ]`, `CapabilityBoundingSet = [ "" ]`.
- **`networkPolicy.{loopback,internet,proxy}`** — die Netzwerk-Achse
  (`IPAddressDeny`/`IPAddressAllow`, `SocketBindDeny`/`SocketBindAllow`). `loopback` erlaubt
  nur `127.0.0.1`/`::1`; `internet` erlaubt ausgehende Verbindungen, bindet aber weiter nur
  lokal; `proxy` hebt `SocketBindAllow` auf (nur Ingress-Pfad).
- **Sprach-/Rollenprofile** (`dotnet`, `python`, `nodejs`/`node`, `network`, `client`,
  `script`) komponieren `base` mit genau einer `networkPolicy.*`-Variante.

`AF_NETLINK` bleibt in `RestrictAddressFamilies`: nftables, `systemd-resolved` und WireGuard
brauchen es. Historisch war hier `RestrictNetworkInterfaces` als Baseline geplant — das ist
es nicht (siehe unten).

### Anwendung: Factory ODER direkte Komposition

Es gibt **keinen** Zwang zur Factory. Beides ist konform:

- **Factory** — `50-core/service-factory.nix` (ADR-5000 `mkService`), die Regel für neue
  Standard-Dienste.
- **Direkte Komposition** — 14 Module importieren `50-core/hardening-profiles.nix` selbst
  (u. a. `541-sabnzbd`, `543-mover`, `551-jellyfin`, `552-audiobookshelf`, `553-navidrome`,
  `561-seerr`, `571-sqlite-wal`, `576-backup`, `583-runtime-guard`, `584-post-boot-watchdog`,
  `585-exporters`, `588-update-notifier`). Beispiel `541`:
  `serviceConfig = lib.mkMerge [ profiles.python memoryPolicy.sabnzbd { … } ]`.

### Was NICHT Baseline ist

`RestrictNetworkInterfaces` ist **keine** Baseline-Option. Sie steht ausschließlich in
`54-processing/541-sabnzbd.nix` und greift nur bei `medinix.usenet-confinement.enable`:

```nix
RestrictNetworkInterfaces = [ "lo" vpnIf ];
```

Das ist eine **Confined-Regel für einen Dienst** (VPN-Confinement, ADR-526), keine
allgemeine Härtung. 541 nutzt dafür das Profil `profiles.python-confined` (ohne
`IPAddress*`-Filter); die Grenze zieht der cgroup-BPF-Socketfilter im Kernel.

## Consequences
- ✅ Profilbasiert — eine Quelle (`hardening-profiles.nix`), zwei zulässige Anwendungspfade
- ✅ Kein Dienst bleibt „weich": Factory und Direktkomposition ziehen dasselbe `base`
- ✅ Fits PrivEsc audit (ADR-5200)
- ⚠️ Zwei Anwendungspfade statt einem — die Zusammenführung auf einen einzigen Pfad
  (Single-Source `hardeningProfile`) steht im Backlog

## Gold-Standard (from Grok)
> "ProtectSystem, PrivateTmp, NoNewPrivileges" appear in all 5 pivots → baseline.
> → Umgesetzt als `base`-Profil in `50-core/hardening-profiles.nix`.
