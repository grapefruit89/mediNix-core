---
id: 59-guardrails
title: Guardrails
description: Cross-domain evaluation-time assertions. No runtime units.
domain: 59
status: active
last_reviewed: 2026-09-02
---

# 59-guardrails

Eval-time invariants across domains. **No systemd units. No runtime enforcement.**

Invalid architecture must fail at `nixos-rebuild`, not on the running host.

| ID | Module | Role |
| --- | --- | --- |
| **591** | [`591-cross-domain.nix`](591-cross-domain.nix) | Cross-domain fail-closed assertions |

There is no `592-environment.nix`. Do not recreate it.

## What 591 checks

- Usenet confinement → SAB (and Prowlarr if on) in the 526 killswitch.
- Registry ports not in `networking.firewall.allowedTCPPorts`. Publish through 511.
- Declared systemd *environment* must not contain `0.0.0.0` / `::` / `*`. Best-effort at eval. Real sockets: 583.
- External Caddy mode → `services.caddy.enable`.
- VPN/Usenet + external nftables → host nftables on.
- External hot/cold backends → matching `fileSystems`.
- VPN → `networking.firewall.checkReversePath != true` (policy routing would otherwise drop asymmetric VPN paths).
- Docker/Podman off.

## Eval vs runtime

```
591  eval-time config
        ↓
valid NixOS config
        ↓
583  runtime sockets / nft / iface
584  post-boot failed units
```

591 is not a second 583. Do not delete an assertion to make a host evaluate.

## Agent notes

- Keep this domain assertion-only.
- Do not add daemons here.
- Do not weaken VPN/ingress invariants.
- Update this README if the module set changes.
