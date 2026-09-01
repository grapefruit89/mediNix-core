---
name: nixos-dotnet-env-config
title: Declarative .NET service config via ASP.NET environment variables in NixOS
category: devops
description: Configure .NET NixOS services via env vars.
---

# Declarative .NET Service Config via Env Vars

## When to use
Any .NET-based NixOS service (Arr stack, Seerr, Autobrr, etc.) whose settings
you would otherwise push via `curl POST` to its API. ASP.NET Core reads
hierarchical configuration from environment variables using this convention:

    {APP}__{SECTION}__{KEY}=value

- Double underscore `__` separates hierarchy levels.
- All path segments are upper-cased.
- App name prefix is the app's ASP.NET name (SONARR, RADARR, PROWLARR, LIDARR,
  READARR, SEERR — NOT JELLYFIN; Seerr is its own app).

Example (Sonarr):
    SONARR__SERVER__PORT=5320
    SONARR__SERVER__BINDADDRESS=127.0.0.1
    SONARR__AUTH__METHOD=External        # if SSO/proxy present, else "Forms"
    SONARR__AUTH__REQUIRED=Enabled
    SONARR__APP__THEME=dark
    SONARR__LOG__LEVEL=info
    SONARR__UPDATE__MECHANISM=BuiltIn     # Nix manages updates, not the app

This is idempotent, race-free, and replaces API-provisioning calls. Set via
`systemd.services.<name>.environment` (merge with `lib.mkMerge`).

## The helper (mkArrEnv)
Convert a nested Nix attrset into the env-var set. See templates/arr-settings.nix
for the full, correct file. Usage:

    let arrSettings = import ../lib/arr-settings.nix { inherit lib; };
    in environment = arrSettings.mkSonarr {
      server = { port = 5320; bindAddress = "127.0.0.1"; urlBase = ""; };
      auth   = { method = "External"; required = "Enabled"; };
      log.level = "info";
      update.mechanism = "BuiltIn";
    };

Result: `{ SONARR__SERVER__PORT = "5320"; SONARR__AUTH__METHOD = "External"; ... }`

## CRITICAL BUG — double prefix (verify before applying any snippet)
A naive impl that builds the leaf key `"SERVER__PORT"` inside `flatten` AND then
does `mapAttrs' (k: v: nameValuePair "${prefix}__${k}" v)` produces
`SONARR__SERVER__PORT` — the prefix applied TWICE. Fix: build the FULL key
including the prefix inside the recursion, return it 1:1 (no second prefixing).
See templates/arr-settings.nix — the leaf builds `"${prefix}__${...}"`.

## What CANNOT be env-var'd
Quality profiles, root folders, download clients, indexer apps are DB entities
created via API (`POST /api/v3/...`). Keep those curl calls. Only AppSettings
(port, bind, auth method, theme, log level, update mechanism) are env-var
configurable. Do NOT delete API-provisioning for those.

## Verification
    grep -rn "SONARR__SERVER__BINDADDRESS" 5*-*/
    # → one hit per enabled Arr service (INV-BIND-01 satisfied declaratively)

## Pitfalls
- `server.bindAddress = "127.0.0.1"` MUST be set or the app binds 0.0.0.0 (INV-BIND-01).
- `server.port` MUST be set or it falls back to the app default (port conflict).
- `update.mechanism = "BuiltIn"` — never let the app self-update; Nix owns versions.
- Seerr prefix is `SEERR` (not JELLYFIN).
- If the module defines `port = 5320;` locally (no `cfg.ports.*`), use that local
  `port` var, not a non-existent `cfg.ports.sonarr`.
- **Mass-patching the same env block into 6 Arr modules: COPY-PASTE TRAP.**
  When applying `arrSettings.mkX { ... }` to each module, the wrapper name must
  match the app: `mkSonarr`/`mkRadarr`/`mkReadarr`/`mkLidarr`/`mkProwlarr`/
  `mkSeerr`. A copy of the Sonarr block into Lidarr.nix with
  `arrSettings.mkSeerr` (instead of `mkLidarr`) silently produces
  `SEERR__*` env vars for the Lidarr service — builds, but wrong config.
  Always set the wrapper to the module's own app. This bit us this session;
  caught by reading the diff, not by the build.
