---
id: "INDEX"
title: "INDEX"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - general
links:
  adr: ""
  repo-harvest: ""
---
# ADR Index — mediNix-core

Alle Architecture Decision Records. Sortiert nach Domain.

## Foundation (00–09)
- [ADR-0000](ADR-0000-dezimalrahmen-verfassung.md) — Dezimalrahmen Verfassung (SSoT für Port/UID/GID)
- [ADR-0001](ADR-0001-source-repository-registry.md) — Source Repository Registry (alle 9 nix-Repos)

## Security Baseline (20–29)
- [ADR-21](ADR-21-ssh-port-policy.md) — SSH Port Policy (Port 22, kein 53844)

## Knowledge Pipeline (50–55)
- [ADR-5000](ADR-5000-secret-management.md) — Secret Management (LoadCredentialEncrypted)
- [ADR-5010](ADR-5010-nixgrok-architecture-review.md) — NixGrok Architecture Review
- [ADR-5020](ADR-5020-knowledge-extraction-pipeline.md) — Knowledge Extraction Pipeline
- [ADR-5030](ADR-5030-flake-module-patterns.md) — Flake Module Patterns
- [ADR-5040](ADR-5040-dezimalrahmen-port-ableitung.md) — Dezimalrahmen Port-Ableitung
- [ADR-5043](ADR-5043-assertion-quality.md) — Assertion Quality (fail-closed)
- [ADR-5050](ADR-5050-systemd-hardening-baseline.md) — systemd Hardening Baseline

## Ingress (51)
- [ADR-5110](ADR-5110-caddy-reverse-proxy.md) — Caddy Reverse Proxy (caddyClass schema)
- [ADR-5115](ADR-5115-split-dns-note.md) — Split-DNS Note (host-side, status: note)
- [ADR-5120](ADR-5120-pocket-id-oidc-module.md) — Pocket-ID OIDC Module
- [ADR-5130](ADR-5130-cloudflare-dns-no-proxy.md) — Cloudflare DNS (no proxy)
- [ADR-5140](ADR-5140-oidc-auth-pocketid-authelia.md) — OIDC Auth (Pocket-ID/Authelia)

## Security Modules (52–59)
- [ADR-5200](ADR-5200-privesc-audit-hardening.md) — PrivEsc Audit Hardening
- [ADR-5210](ADR-5210-nftables-firewall-baseline.md) — nftables Firewall Baseline

## Acquisition (53)
- [ADR-5320](ADR-5320-sonarr-series-management.md) — Sonarr Series Management

## Transfer (54)
- [ADR-5410](ADR-5410-sabnzbd-vpn-confinement.md) — SABnzbd VPN Confinement

## Playback (55)
- [ADR-5510](ADR-5510-jellyfin-media-playback.md) — Jellyfin Media Playback
- [ADR-5520](ADR-5520-audiobookshelf-port-framework.md) — Audiobookshelf Port Framework
- [ADR-5530](ADR-5530-navidrome-music-streaming.md) — Navidrome Music Streaming

## Requests (56)
- [ADR-5610](ADR-5610-jellyseerr-request-management.md) — Jellyseerr Request Management

## Maintenance (57)
- [ADR-5700](ADR-5700-sqlite-wal-tuning.md) — SQLite WAL Tuning
- [ADR-5710](ADR-5710-sqlite-mcp-server.md) — SQLite MCP Server (draft)
- [ADR-5720](ADR-5720-backup-strategy.md) — Backup Strategy (draft)

## Total: 28 ADRs (0000–5720 inkl. 21, 5115)
- [ADR-5410](ADR-5410-usenet-confinement.md) - Usenet Confinement (VPN Kill-Switch)
