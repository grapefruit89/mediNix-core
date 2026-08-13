# Context7 Library Routing für mediNix-core

Gelöst 2026-08-11: nicht alle NixOS-Optionen sind im Core-Manual.

## Library-IDs (resolved via resolve_library_id)
- `/websites/nixos_manual_nixos_unstable` — NixOS manual (2672 snippets, current)
  → für: `networking.nftables.*`, `boot.kernel.sysctl.*`, `services.openssh.*`,
    `security.acme.*`, `systemd.services.<name>.serviceConfig.*`
- `/nixos/nixpkgs` — package attrs (7982 snippets)
  → für: `services.sonarr` / `services.radarr` / `services.prowlarr` (community
    module option names), `pkgs.sonarr` / `pkgs.prowlarr` (package attrs)
- `/websites/wiki_nixos_wiki` — wiki (15969 snippets)
  → fallback für Patterns die im Manual fehlen

## Wichtiger Pitfall (Arr-Dienste)
`services.sonarr` ist NICHT im Manual. Query `/websites/nixos_manual_nixos_unstable`
mit "services.sonarr configuration" → "No documentation matched".
Richtig: native Dienste bauen wir mit `systemd.services.<name>` (nicht `services.X`),
und die systemd.serviceConfig-* Optionen kommen aus dem Manual (ProtectSystem,
StateDirectory, ReadWritePaths, BindPaths, LoadCredential[Encrypted]).
Für Package-Attr + Servarr-spezifische Config (AUTH__METHOD, -data= Pfad) nutze
`/nixos/nixpkgs` + Repo-Harvester (distribution/debian/*.service).

## Parameter-Syntax (Context7 MCP)
- `mcp__context7__query_docs(libraryId="/websites/nixos_manual_nixos_unstable", query="...")`
  → NICHT `libraryName`, das wird als Fehler "missing required argument libraryId" rejected.
- `mcp__context7__resolve_library_id(libraryName="NixOS")` → liefert die IDs.
