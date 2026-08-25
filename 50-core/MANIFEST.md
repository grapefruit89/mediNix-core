# mediNix-core: Architecture Manifesto (v2.0)

This document defines the core principles and strict boundaries of `mediNix-core`. Every future module and every agent output must be evaluated against this manifesto. It dictates not only what we build, but what we strictly avoid.

## 1. The Boundary (Tri-State Host Integration)
The core must never assume it owns the bare-metal host. We integrate politely.
* **DO:** Configure media services, service-specific Caddy vhosts, and container-less isolation 100% internally within the flake.
* **DO:** Expose host-wide singletons (like kernel `sysctl` for `rp_filter` or global `nftables` baselines) via `medinix.recommended.*` (**Publish-Don't-Apply**).
* **DO:** Use the `hostIntegration` tri-state (`managed`, `external`, `off`) to dictate if the core applies these recommendations additively, or if they are handed off to the host admin via `ADMIN-HANDOFF.md`.
* **DON'T:** Never blindly override host components (`networking.nftables.enable = true` unconditionally is forbidden). 

## 2. Priority Discipline & Additive Configuration
* **DO:** Use standard Nix list additions (e.g. `[ "@system-service" ]` instead of strings) so that `systemd` configurations can merge elegantly with upstream or host configurations.
* **DON'T:** **`mkForce` is strictly forbidden.** If you have to use `mkForce`, the architecture is wrong and needs to be refactored.
* **DON'T:** Do not override `User`, `Group`, or `StateDirectory` in `serviceConfig` if an upstream `nixpkgs` module already manages them natively (e.g. SABnzbd).

## 3. Fail-Closed Security & Decentralized Guardrails
Security mechanisms must crash the system rather than leaving it exposed.
* **DO:** Design systems to **"Fail-Closed"**. If the VPN DNS is missing, or a storage mountpoint is offline (Mover), the build or the service must crash gracefully (`exit 1` or Nix `throw`).
* **DO:** Write inline assertions with localized, plain-English error messages right where the failure happens. Include an `[AI/Admin Context]` explaining *why* the rule exists.
* **DON'T:** No **"Fail-Open"**. Never fall back to unencrypted host DNS if the VPN Killswitch is misconfigured.
* **DON'T:** No central assertion registries (no `INV-01` obfuscation). Errors must be human- and AI-readable at the source.

## 4. Nix-Native & Zero-Container
* **DO:** Isolate services purely using native `systemd` hardening (RootDirectory, BindPaths, DynamicUser) and strict policy routing (fwmark/nftables).
* **DO:** Handle secrets exclusively via TPM-sealed credentials (`LoadCredentialEncrypted`). No secrets in the Nix store.
* **DON'T:** Docker, Podman, Compose, and any OCI runtimes are strictly forbidden. 

## 5. Dendritic Modularity & SSoT (Drop & Forget)
* **DO:** Keep every service self-contained (`NNN-service.nix`). If a file is deleted, the service and its firewall/proxy configurations must vanish completely without leaving dead configuration.
* **DO:** Derive all Ports, UIDs, GIDs, and profiles from `lib/registry.nix` (Isomorphism: `Port = UID = Service-Number * 10`).
* **DON'T:** Never hardcode UIDs, GIDs, or ports in the domain modules. The registry is the absolute and only truth.
