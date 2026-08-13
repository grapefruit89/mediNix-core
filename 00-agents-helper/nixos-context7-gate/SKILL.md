---
name: nixos-context7-gate
description: Gate - verify NixOS options via Context7 before .nix commits
---

# nixos-context7-gate

**MANDATORY pre-commit gate for all mediNix-core `.nix` work (Aufgaben 5–12).**

## Rule
Before writing or committing ANY `.nix` file, for EVERY NixOS option you use, run a Context7 query:
```
query_docs(library="/websites/nixos_manual_nixos_unstable", query="<option.name>")
```
Show the query + the first returned snippet as proof. **No commit without this evidence.**

## Required especially for (but not limited to):
- `networking.nftables.*`
- `systemd.services.<name>.serviceConfig.*`
- `services.avahi.*`
- `security.acme.*`
- `boot.kernel.sysctl.*`
- `services.caddy.*`
- Any option whose existence/signature you are not 100% certain about.

## Workflow
1. Plan the `.nix` module → list all NixOS options it will use.
2. For each option: `query_docs` against `/websites/nixos_manual_nixos_unstable` (or `/nixos/nixpkgs` for package attrpaths).
3. Paste the query string + top snippet into your commit message / response.
4. Only then write + commit.

## Why
Hermes can reach Context7 but only does so when reminded. This skill makes it a hard gate — no option from training memory alone. Catches removed/renamed options before the build on q958 fails.

## Note
Context7 library IDs (resolved 2026-08-11):
- `/websites/nixos_manual_nixos_unstable` — NixOS manual (2672 snippets, current)
- `/nixos/nixpkgs` — package attrs (7982 snippets)
- `/websites/wiki_nixos_wiki` — wiki (15969 snippets)
