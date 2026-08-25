---
name: nixos-flake-ci
description: "Use when adding ratsche or linting gates to a NixOS flake."
version: 1.0.0
author: Hermes
license: MIT
---

# NixOS Flake CI — Shift-Left Quality Gates

## Trigger
Use when building/extending a NixOS flake's `checks` / `devShell` / `formatter`,
adding a **ratsche** (eval gate that fails `nix flake check` on any error), a
decimal-framework enforcer, linting (`statix` / `deadnix` / `nixfmt`), or
converting inline `script = ''...''` systemd scripts to
`pkgs.writeShellApplication`. Also when the user says "shift-left", "ratsche",
or "catch bugs at build, not deploy".

Source pattern: `grapefruit89/devNIX` flake.nix (ADR-8000). Adapted for
mediNIX-core (project digit 5) and generalized here.

## Why
A bare `nixosModules.default = import ./default.nix` with no `checks` means
typos, missing attributes, and wrong option paths sail through to the deploy
host and fail there (or worse — start services without credentials). A ratsche
catches all of it locally at `nix flake check`. This is the single highest-ROI
change for a NixOS module repo.

## Core Patterns

### 1. The Ratsche (eval gate)
```nix
nixosConfigurations.check = lib.nixosSystem {
  inherit system;
  modules = [
    self.nixosModules.default
    {
      medinix.enable = true;          # the module's enable flag
      boot.loader.grub.enable = false;         # no bootloader in eval
      fileSystems."/" = { device = "none"; fsType = "tmpfs"; };  # no real root
      system.stateVersion = "24.11";
    }
  ];
};
checks.${system}.eval = nixosConfigurations.check.config.system.build.toplevel;
```
The stub must disable the bootloader and use a tmpfs root so it evaluates
without hardware. `eval = ...config.system.build.toplevel` forces a full
module evaluation — any `attribute 'X' missing` or type error breaks the check.

### 2. Decimal-framework Enforcer (ADR-0000 style)
Use **Nix-native** readDir + regex, NOT bash grep. Bash glob
`[0-9][0-9]-*` only matches 2-digit prefixes and silently misses 3-digit
folder names like `51-ingress`.
```nix
let
  entries    = builtins.readDir ./.;
  isModule   = n: t: t == "directory" && builtins.match "^[0-9]{3}-.*" n != null;
  folders    = builtins.attrNames (lib.filterAttrs isModule entries);
  number     = n: lib.toInt (builtins.head (builtins.match "^([0-9]{3})-.*" n));
  violations = lib.filter (v: v != null) (map (n:
    let project = (number n) / 100; in
    if project != PROJECT_DIGIT then "${n}: leading digit ${toString project} != ${toString PROJECT_DIGIT}" else null
  ) folders);
in
if violations == [] then pkgs.runCommand "decimal-ok" {} "touch $out"
else throw ("ADR-0000 violated:\n  " + lib.concatStringsSep "\n  " violations);
```
Set `PROJECT_DIGIT` per repo (mediNIX = 5, devNIX = 8). Keep the
`dreistellig` (3-digit) folder regex even if folders currently look 2-digit —
the file-level `NNN-service.nix` rule is 3-digit and the enforcer should match
the deeper invariant.

### 3. mkCheck helper (CI goes red, never the tree)
```nix
mkCheck = name: deps: script:
  nixpkgs.lib.mapAttrs' (_: system:
    let pkgs = nixpkgs.legacyPackages.${system}; in
    pkgs.runCommand "check-${name}" { nativeBuildInputs = deps pkgs; } ''
      cd ${self}; ${script}; touch $out '') ;
```
Then per check (note the `.${system}` projection — `eachDefaultSystem`
requires per-system attrs):
```nix
checks.nixfmt-check = (mkCheck "nixfmt" (pkgs: [ pkgs.nixfmt-rfc-style ]) ''
  nixfmt --check $(find . -name '*.nix' -not -path './.git/*') \
    || { echo "Nicht formatiert. Beheben: nix fmt"; exit 1; }
'') .${system};
checks.statix-check = (mkCheck "statix" (pkgs: [ pkgs.statix ]) ''
  statix check . || { echo "Beheben: statix fix ."; exit 1; } '') .${system};
checks.deadnix-check = (mkCheck "deadnix" (pkgs: [ pkgs.deadnix ]) ''
  deadnix --fail . || { echo "Beheben: deadnix --edit ."; exit 1; } '') .${system};
```
`nixfmt-rfc-style` is the current nixos-unstable package name (plain
`pkgs.nixfmt` is deprecated/renamed).

### 4. writeShellApplication (ShellCheck at build)
Replace inline `script = ''...''` in systemd services with a built derivation:
```nix
walScript = pkgs.writeShellApplication {
  name         = "sqlite-wal-tune";
  runtimeInputs = [ pkgs.sqlite ];
  text = ''...'';
};
# in serviceConfig: ExecStart = lib.getExe walScript;
```
`lib.getExe` is verified-correct (Context7: warns if `meta.mainProgram`
missing, but `writeShellApplication` sets it). ShellCheck runs at
`nix flake check`, so unquoted vars / pipefail issues are caught before deploy.

### 5. lib.pipe for auto-import
```nix
moduleFiles = lib.pipe (builtins.readDir ./. ) [
  (lib.filterAttrs (n: t: t == "directory" && builtins.match "^[0-9]{2}-.*" n != null))
  builtins.attrNames
  (map (d:
    let
      files = builtins.readDir (./. + "/${d}");
    in
    map (n: ./. + "/${d}/${n}")
      (builtins.attrNames (lib.filterAttrs
        (n: t: t == "regular" && builtins.match "^[0-9]{3}-.*\\.nix$" n != null)
        files))
  ))
  lib.flatten
];
imports = moduleFiles;
```
Idiomatic; any Nix dev reads it instantly. Keep the 2-digit folder regex here
(folders are `51-ingress`) and the 3-digit file regex inside the per-dir
filter (`^[0-9]{3}-.*\\.nix$`).
**NOTE:** the earlier version of this skill used
`(map (d: import (./. + "/${d}")))` — that imports the DIRECTORY as a module,
but the real mediNIX pattern imports the individual `NNN-service.nix` FILES
inside each directory. Use the file-walking version above.

## Pitfalls (flake.nix syntax — tested bugs this session)
- **`inherit (nixpkgs.lib) lib` is WRONG.** It produces `lib = nixpkgs.lib.lib`
  which does not exist → eval error. Correct form:
  `registryJson = builtins.toJSON (import ./lib/registry.nix { lib = nixpkgs.lib; }).services;`
- **`formatter.${system}` / `devShells.${system}.default` inside
  `eachDefaultSystem` is WRONG (double-nesting).** `eachDefaultSystem` already
  iterates `system`, so the attrset it returns is per-system. Write
  `formatter = pkgs.nixfmt-rfc-style;` and `devShells.default = pkgs.mkShell { ... };`
  (no `${system}`). The resulting flake output is `formatter.x86_64-linux`,
  not `formatter.x86_64-linux.x86_64-linux`.
- **GitHub push fails with default SSH**: `git push` to
  `grapefruit89/mediNIX-core` dies with "Permission denied (publickey)"
  because the deploy key is not the default agent key. MUST use:
  `GIT_SSH_COMMAND="ssh -i /opt/data/.ssh/mediNIX_core_deploy -o IdentitiesOnly=yes" git push`
- **Never hardcode the Tower IP (192.168.2.250) inside a NixOS module that
  runs on the deploy host (q958)**. That host reaches ntfy via `127.0.0.1`.
  The Tower IP is only valid from the Hermes-container context. Confusing the
  two caused a portability regression this session — the file was reverted.
- **`types.path` for secret files leaks them world-readable into the Nix
  store** (Nix copies the file in). Use `types.str` for secret paths. Do NOT
  change storage paths (those are legitimately paths).
- **`network-online.target` in `after`/`requires` adds 10-15s boot delay**.
  `network.target` is fine when `Restart=on-failure` is present.

## Context7 verification
Before committing `writeShellApplication` / `lib.getExe` usage, query
`/websites/nixos_manual_nixos_unstable` for `pkgs.writeShellApplication`
to confirm `lib.getExe` syntax (it is correct, but the gate is cheap).

## Relationship to other skills
Overlaps conceptually with `medinix-build-gate` (curator-managed). This skill
focuses on the *flake-level* shift-left tooling (ratsche, linters,
writeShellApplication); `medinix-build-gate` owns the pre-commit assertion
sequence. Keep them complementary — do not duplicate the decimal-audit here
(that lives in `medinix-audit-suite`).
