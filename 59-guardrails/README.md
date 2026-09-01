---
id: 59-guardrails
title: Guardrails
description: Eval-time assertions. No units.
last_reviewed: 2026-09-02
---

# 59-guardrails

One organ: [`591-cross-domain.nix`](591-cross-domain.nix). 592 was folded in.

Checks at eval, not at runtime:

- `usenet-confinement.enable` → killswitch instances `sabnzbd` / `prowlarr`
- app ports not in `allowedTCPPorts`
- `reverseProxy = external` only demands `services.caddy.enable` when `ingress.mode != standalone`
- nftables only when VPN or usenet confinement is on
- external hot/cold storage → those paths exist in `fileSystems`
- VPN → `checkReversePath != true`
- no Docker/Podman
