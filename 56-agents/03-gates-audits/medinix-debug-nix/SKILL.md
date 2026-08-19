---
name: medinix-debug-nix
description: "Use when nix flake check / rebuild fails on 50-mediNix."
version: 1.0.0
author: Hermes
license: MIT
---

# mediNix Debug Nix — Build / Rebuild Failures

## Trigger
Use when `nix flake check`, `nixos-rebuild dry-run`, or `switch` fails on
`/opt/data/50-mediNix/`. For module creation use `medinix-module-author`; for the
pre-commit gate use `medinix-pre-commit`.

## 1. Deployment routine (always dry-run first)
1. `nixos-rebuild dry-run --flake .#check` — ALWAYS first. On `assertion failed`
   → STOP, fix the assertion, do not force.
2. `nixos-rebuild switch --flake .#check`
3. Verify: SSH :22 + :2222 up, `curl http://{svc}.local`.

## 2. Assertion debugging (fail-closed guardrails)
Build-aborting asserts live in `59-guardrails/`:
- `591-assertions.nix` — forward-auth/VPN/TLS/DDNS conflicts, .NET-EOL warning.
- `596-security-assertions.nix` — aborts if SSH off, nftables active without
  port 22 in `allowedTCPPorts`, or `PasswordAuthentication` allowed.
Read the assertion message — it names the invariant (ADR-0000) and the fix.

## 3. Known self-inflicted Hermes bugs (read `references/nixos-module-bugs.md`)
- **mkMerge isolation trap**: `containerIsolation` must be a LIST
  `[ isolation ]` inside `lib.mkMerge`, else it silently does not apply.
- **IPAddressDeny loopback trap**: `IPAddressDeny = [ "any" ]` blocks
  127.0.0.1 inter-service talk (Sonarr→Jellyfin). Use
  `RestrictNetworkInterfaces = [ "lo" ]` instead.
- **avahi userServices**: mDNS `.local` only works with `userServices=true`.
- **Jellyfin GPU**: needs `PrivateDevices=false` or `/dev/dri` is invisible
  (no VA-API HW transcode).
- **JIT**: .NET & Node need `MemoryDenyWriteExecute=false` or they crash.
- **script profile**: needs `PrivateNetwork` override to curl localhost.
- **LoadCredentialEncrypted + ProtectSystem=strict**: compatibility gotcha.
- **Infinite recursion via config read**: reading `cfg.services.X.enable`
  inside the module that defines it recurses — use the option's own value, not
  a re-read.
- **Build-time embedding pattern**: embed `registryJson` from `lib/registry.nix`
  at build time, don't re-evaluate the module graph.

## 4. Anti-lockout order (mandatory)
Configure `594-no-password-auth.nix` (PasswordAuthentication=false,
UsePAM=false) BEFORE touching nftables / sshd_config. 595-backup-ssh (port
2222, keys only, read-only rsync) must be present so you never lose SSH.

## 5. .nix language
Errors reference English module names/options. Keep the chat German, the code
English.

## References
- `../nixos-medinix-authoring/references/nixos-module-bugs.md` (3 bugs + embedding pattern)
- `../nixos-medinix-authoring/references/hardening-profiles.md` (GOTCHAS)
- `../nixos-medinix-authoring/references/boilerplate-gotchas.md`
