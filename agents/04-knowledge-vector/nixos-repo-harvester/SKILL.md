---
name: nixos-repo-harvester
description: Harvest NixOS patterns and issues from a GitHub repo.
---

# nixos-repo-harvester

Extract NixOS-relevant knowledge from any GitHub repo before writing a mediNix module for that service.

## Trigger
- "Ernte das Repo X aus für Dienst Y"
- Before writing a module for Sonarr/Radarr/Prowlarr/SABnzbd/Jellyfin/Navidrome/Audiobookshelf
- "Gibt es bekannte NixOS-Inkompatibilitäten in Repo X?"

## Input
GitHub repo URL + target service name (e.g. "Sonarr", "Jellyfin").

## Workflow (via GitHub MCP — no git clone needed)
1. `get_file_contents` to read README, root `.nix` files, and any `nix/` or `packaging/` subdirectory.
2. `search_issues` with query `repo:owner/name is:issue label:nixos` — extract known breakage patterns.
3. Extract: declarative config options, default ports, state directories, known NixOS incompatibilities.
4. Output as structured Markdown: **Patterns** / **Known Issues** / **Recommended serviceConfig**.

## Output format
```
## <Service> — Repo Harvest (<repo-url>)
### Patterns (from README/packaging)
- ...
### Known NixOS Issues (from labeled issues)
- issue #N: <problem> → <workaround>
### Recommended serviceConfig
- ...
```

## Pitfalls
- Noogle.dev has NO working API (returns SPA HTML, not JSON) — use Context7 `/nixos/nixpkgs` for lib.* signatures instead.
- Focus on packaging/ directory and any `.nix` in root — that's where NixOS-relevant config lives.
- GitHub MCP search_issues: use `repo:owner/name label:nixos` query syntax.
