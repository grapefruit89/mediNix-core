# Flat Structure, One-File-Per-Service, Auto-Import & GitHub Push (Session 2026-08-11)

## 1. One file per service (dendritic, flat)
- User rule: "eine Datei pro Dienst, schön dendritisch". A service = ONE .nix file.
- Anti-pattern fixed this session: `511-caddy-reverse-proxy.nix` + `511-three-way-ingress.nix`
  both configured Caddy → merged into `511-caddy.nix` (options + `services.caddy` +
  mDNS + hardening in one file).
- If two files share a Dienstnummer and both configure that service, MERGE them.
  Different services with adjacent numbers (511 Caddy, 512 Pocket ID) are fine as
  separate files — but never two files for the SAME 511.

## 2. Master auto-import (kills dead-path bugs)
Root `default.nix` must NOT hardcode an `imports = [ ... ]` list. Use:
```nix
let
  domainDirs = lib.filterAttrs (n: t: t == "directory" && builtins.match "[0-9]{2}-.*" n != null)
    (builtins.readDir ./.);
  importModules = dir:
    let files = builtins.readDir (./. + "/${dir}");
        mods = lib.filterAttrs (n: t: t == "regular" && builtins.match "[0-9]{3}-.*\\.nix" n != null) files;
    in map (n: ./${dir}/${n}) (lib.attrNames mods);
  allModules = lib.flatten (map importModules (lib.attrNames domainDirs));
in { imports = allModules; ... }
```
- Hardcoded lists rot after renames: this session's root default.nix still pointed at
  `512-three-way-ingress`, `541-mover`, `561-feishin` (all renamed) → broken build.
- Per-domain `default.nix` only kept if it holds logic (53-acquisition = *arr factory,
  57-maintenance = provisioning). Pure auto-import `default.nix` (e.g. old
  `55-playback/default.nix`) is REDUNDANT with the master → delete.

## 3. Number collision scan (run after EVERY rename/struct change)
`../../shared/scripts/scan_duplicates.py` catches: same Dienstnummer claimed by >1 file (real bug:
`541-mover.nix` collided with SABnzbd `541-sabnzbd-isolation.nix` → moved mover to
`543-mover.nix`, free slot in 54-transfer), content-identical files (sha256 dupes),
same NIXMETA `# id:` in multiple files.
False-positives (legit, ignore): `default.nix`/`flake.nix`/`lib/*.nix` (no number by
design), 57-maintenance provisioning sub-modules, SSH/Firewall ports (22/443/2222 are
NOT service ports).

## 4. GitHub push via deploy key + GitHub MCP
- Generate ed25519 deploy key: `ssh-keygen -t ed25519 -N "" -C "repo-deploy" -f /opt/data/.ssh/<repo>_deploy`
- User adds PUBLIC key at repo Settings → Deploy keys → "Allow write access".
- Local: `git remote add origin git@github.com:grapefruit89/<repo>.git`; branch `master`
  (NOT `main` — avoids collision with `grapefruit89/mediNix` which enforces main-only).
- Push uses explicit SSH command (no ~/.ssh/config write permission):
  `GIT_SSH_COMMAND="ssh -i /opt/data/.ssh/<repo>_deploy -o IdentitiesOnly=yes -o StrictHostKeyChecking=no" git push -u origin master`
- For repo inventory use GitHub MCP `mcp__github__search_repositories` with
  `query: "user:grapefruit89"` (returns ALL repos, not just name-matches). Do NOT use
  raw `curl api.github.com` — it gets blocked (no user consent for external calls).
- Write a `ADR-0001-source-repository-registry.md` listing all nix-repos with roles
  (devNIX = constitution source ADR-8000, mediNix = gold configs, mynixos-v5 = advanced
  SSO/SSoT patterns). Pointer goes in MEMORY, full table in the ADR.
