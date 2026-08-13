---
id: "ADR-52-systemd-hardening-baseline"
title: "ADR 5050 systemd hardening baseline"
domain: 52
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - hardening
  - security
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5050: systemd Service Hardening Baseline (50-core)

## Status: active
## Date: 2026-08-11
## Source: Grok raw pivots (systemd_opt patterns) + ADR-5200

## Context
Multiple pivots confirm the same systemd hardening options recur across all mediNix
services. These must be a baseline, not per-service ad-hoc.

## Decision — mandatory `serviceConfig` for ALL mediNix services (via mkService factory)
```
ProtectSystem = "strict";
PrivateTmp = true;
NoNewPrivileges = true;
RestrictNetworkInterfaces = [ "lo" ];   # + VPN if needed (ADR-5410)
ReadWritePaths = [ stateDir ];          # minimal, Tier B
# LoadCredential for secrets (ADR-5000), never inline
```

## Consequences
- ✅ Uniform hardening (no service left soft)
- ✅ Factory-enforced (ADR-5000 mkService)
- ✅ Fits PrivEsc audit (ADR-5200)

## Gold-Standard (from Grok)
> "ProtectSystem, PrivateTmp, NoNewPrivileges" appear in all 5 pivots → baseline.
> → Already in mkService factory, now documented as ADR.
