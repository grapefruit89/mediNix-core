---
id: ADR-512
title: Pocket ID OIDC process
domain: 51
status: active
last_reviewed: 2026-09-02
module: 51-ingress/512-pocket-id.nix
---

# ADR-512: Pocket ID (service 512)

**Why.** Need an IdP on the box without Authelia/Keycloak. Pocket ID is small and systemd-native.

**How.** `512-pocket-id.nix` starts `services.pocket-id` on `127.0.0.1:5120` (UID 5120). It does not write Caddy, ACME, or DNS. 511 is the only publisher.

**Enable.** `medinix.pocketId.enable = true`. Forward-auth does **not** auto-start this unit (that broke 511 when an external proxy was used).

**Exposure.** `pocketId.exposure`: `idp` (browser login, no forward_auth, no CIDR abort), `internal` (trustedCidrs only), `none` (loopback only; 511 can still forward_auth to `:5120`).

**Auth wiring lives in 511.** Empty `forwardAuthUpstream` + this unit on → `127.0.0.1:5120`. External proxy → `authProxyPresent` + explicit upstream, this unit stays off.

**Rejected.** Authelia. Three older ADRs (`lightweight-identity`, `oidc-auth-pocketid-authelia`, `pocket-id-oidc-module`) said the same thing twice and kept Authelia as a ghost option.
