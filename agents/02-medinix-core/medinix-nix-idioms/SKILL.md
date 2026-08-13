---
name: medinix-nix-idioms
description: "mediNIX Nix footguns + Factory unit rule."
version: 1.0.0
author: Hermes
license: MIT
---

# medinix-nix-idioms — Nix Footguns & mediNIX Architecture Rules

Load this whenever editing any `.nix` file in `grapefruit89/mediNix-core` (or `50-mediNix`
boilerplate). These are concrete bugs that slipped past two independent AI reviews and cost
real debugging time. Encode them so the next session starts knowing.

## TRIGGER
- Editing/creating a `.nix` file under `50-mediNix/` or `mediNix-core`
- Reviewing a diff that touches `flake.nix`, `lib/service-factory.nix`, `default.nix`, or any
  `systemd.services.*` / `after =` block
- A user pastes a review from another AI about mediNIX Nix code — VERIFY against these rules,
  do NOT trust the review blindly (see Pitfall #6)

## ARCHITECTURE RULE 1 — Factory Unit Names are PLAIN, not Port-Suffixed
**This is the #1 repeated bug.** mediNIX uses `lib/service-factory.nix`:
```nix
# lib/service-factory.nix line 47:
systemd.services."${name}" = { ... };   # name = "sonarr" → Unit = sonarr.service
```
- `name` is the **kebab-case service name** ("sonarr", "sabnzbd", "prowlarr")
- **Unit name = `sonarr.service`, NOT `sonarr-5320.service`**
- **`StateDirectory` HAS the port**: `/var/lib/sonarr-5320` (from `stateDir` arg)
- **`listenStreams` (socket) HAS the port**: `127.0.0.1:5320`
- **NEVER mix these up.** If you see `after = [ "sonarr-5320.service" ]` → WRONG. Must be
  `after = [ "sonarr.service" ]`.
- SABnzbd (541) is native nixpkgs (`services.sabnzbd.enable = true` → `sabnzbd.service`), same
  plain name rule.
- **Verification:** grep the repo for `systemd.services."${name}"` in service-factory.nix — that
  is the SSoT. Do NOT infer unit names from `StateDirectory` paths.

## FOOTGUN 2 — `inherit (nixpkgs.lib) lib` is WRONG in flake.nix
```nix
# WRONG:
registryJson = builtins.toJSON (import ./lib/registry.nix { inherit (nixpkgs.lib) lib; }).services;
# → lib.lib does NOT exist → build breaks
# RIGHT:
registryJson = builtins.toJSON (import ./lib/registry.nix { lib = nixpkgs.lib; }).services;
```

## FOOTGUN 3 — `eachDefaultSystem` double-nesting
Inside `eachDefaultSystem` the iterator is `system`. Do NOT write `formatter.${system}` or
`devShells.${system}.default` — that produces `formatter.x86_64-linux.x86_64-linux` (invalid).
```nix
# WRONG (inside eachDefaultSystem):
formatter.${system} = pkgs.nixfmt-rfc-style;
devShells.${system}.default = pkgs.mkShell { ... };
# RIGHT:
formatter = pkgs.nixfmt-rfc-style;
devShells.default = pkgs.mkShell { ... };
```

## FOOTGUN 4 — `types.path` leaks Secrets into the Nix Store
`types.path` COPIES the file into the Nix store (world-readable). For secret paths
(apiKeyFile, passwordFile, credentials) use `types.str` — the path stays a string, no copy.
```nix
# WRONG (secret path):
navidromeOidcFile = lib.mkOption { type = lib.types.path; default = "..."; };
# RIGHT:
navidromeOidcFile = lib.mkOption { type = lib.types.str; default = "..."; };
```
Exception: non-secret storage paths (mediaRoot, metadataDir) MAY use `types.path` — but mediNIX
convention is `types.str` for portability. When in doubt: `types.str`.

## FOOTGUN 5 — `writeShellApplication` for ShellCheck-at-Build
Any bash script in a `.nix` module should be `pkgs.writeShellApplication` (not inline `script =
''...''`). ShellCheck runs at build time and catches unquoted vars / pipefail issues BEFORE
deploy. This caught real bugs in Round 1. Use `runtimeInputs` for all binaries the script calls.

## RULE 6 — Cross-Validation: Verify, Don't Trust
When a user pastes a review from another AI claiming a bug in mediNIX code, **read the actual
source** (service-factory.nix, the module in question) before agreeing. In this session another
AI claimed `sonarr-5320.service` was correct and `sonarr.service` was wrong — it was backwards.
Both AIs had conflated `StateDirectory` (port-suffixed) with unit name (plain). The Factory is
the SSoT. Verify every claim against the file, never against the reviewer's narrative.

## RULE 7 — Decimal Prefix for Auto-Import
New maintenance/guardrail modules MUST be named `NNN-*.nix` (3-digit, e.g. `578-orphan-cleanup.nix`)
so the loader in `default.nix` picks them up. A file like `prowlarr.nix` (no prefix) is INERT.
Legacy files without the prefix are dead code — delete them (Hygiene Gate Tor 6).

## References
- `references/factory-unit-names.md` — worked example + the exact service-factory.nix line
- `references/nix-footguns.md` — full snippet diffs for footguns 2-5
