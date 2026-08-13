---
name: nixos-flake-patterns
description: "flake.nix scope bugs + Shift-Left CI + env-var conversion."
version: 1.0.0
author: Hermes
license: MIT
---

# NixOS Flake Patterns (Scope Bugs + Shift-Left + Recursive Env-Vars)

## Trigger
- Writing or reviewing a `flake.nix` (especially `outputs`, `eachDefaultSystem`, `checks`, `mkCheck`).
- Building a "Ratsche" / CI check / decimal-framework enforcer.
- Converting a nested Nix attrset into `{APP}__{SECTION}__{KEY}` environment variables (.NET / ASP.NET config).
- Any `nix flake check` failure that points at `flake.nix` evaluation (not a module).

## 1. flake.nix Scope Bugs (BREAK nix flake check silently until eval)

### Bug A — `inherit (x) lib` wrong scope
```nix
# WRONG: lib = nixpkgs.lib.lib  (does not exist → eval error)
registryJson = builtins.toJSON (import ./lib/registry.nix { inherit (nixpkgs.lib) lib; }).services;
# RIGHT: pass the whole lib
registryJson = builtins.toJSON (import ./lib/registry.nix { lib = nixpkgs.lib; }).services;
```
Rule: when a file does `import ./x.nix { lib = ... }`, pass `lib = nixpkgs.lib` (the attrset), NOT `inherit (nixpkgs.lib) lib` (which expands to `lib = nixpkgs.lib.lib`).

### Bug B — `formatter.${system}` / `devShells.${system}` double-nesting inside `eachDefaultSystem`
```nix
# WRONG inside eachDefaultSystem (system is ALREADY the iterator):
outputs = { nixpkgs, flake-utils, ... }:
  flake-utils.lib.eachDefaultSystem (system:
    let pkgs = nixpkgs.legacyPackages.${system}; in {
      formatter.${system} = pkgs.nixfmt-rfc-style;   # → formatter.x86_64-linux.x86_64-linux  (illegal)
      devShells.${system}.default = pkgs.mkShell { ... };
    });
# RIGHT: bare attribute, eachDefaultSystem wraps it:
      formatter = pkgs.nixfmt-rfc-style;
      devShells.default = pkgs.mkShell { ... };
```
Rule: inside `eachDefaultSystem (system: ...)`, every output attr is ALREADY per-system. Write `formatter =`, `devShells.default =`, `checks.<name> =`. NEVER add `.${system}`.

### Bug C — `mkCheck` must wrap per-system
```nix
# devNIX pattern: mkCheck returns an attrset keyed by system (mapAttrs'), so call with .${system}
mkCheck = name: deps: script: nixpkgs.lib.mapAttrs' (_: system: ...) (...);
checks.nixfmt-check = (mkCheck "nixfmt" (pkgs: [ pkgs.nixfmt-rfc-style ]) ''...'') .${system};
```

## 2. Shift-Left CI (devNIX harvest — adopted pattern)

A "Ratsche" = a `checks.<name>` that forces full evaluation so every attribute-missing / type error fails the build instead of the deploy.

### Ratsche (eval the whole module set)
```nix
nixosConfigurations.check = lib.nixosSystem {
  inherit system;
  modules = [ self.nixosModules.default { grapefruitMedia.enable = true; boot.loader.grub.enable = false;
    fileSystems."/" = { device = "none"; fsType = "tmpfs"; }; system.stateVersion = "24.11"; } ];
};
checks.nixos-check = nixosConfigurations.check.config.system.build.toplevel;
```
Note: `nixosConfigurations` must be defined even if the repo is a module-flake (consumer builds it). The Ratsche builds a throwaway config from the module.

### Decimal-Enforcer (Nix-native, NOT bash-grep)
```nix
# WRONG: bash grep on folder names — only catches 2-digit prefixes, misses file numbers
for d in [0-9][0-9]-*/; do num=$(echo "$d" | grep -oE '^[0-9]+'; ...
# RIGHT: readDir + regex on the full path, project digit enforces domain
decimalFrameworkCheck =
  let entries = builtins.readDir ./.;
      isModuleDir = n: t: t == "directory" && builtins.match "^[0-9]{3}-.*" n != null;
      folders = builtins.attrNames (lib.filterAttrs isModuleDir entries);
      number = n: lib.toInt (builtins.head (builtins.match "^([0-9]{3})-.*" n));
      violations = lib.filter (n: (number n) / 100 != 5) folders;  # project digit = 5
  in if violations == [] then pkgs.runCommand "ok" {} "echo ok > $out"
     else throw ("ADR-0000 violated: " + lib.concatStringsSep ", " violations);
checks.decimal-framework = decimalFrameworkCheck;
```

### mkCheck helper (per-system CI gate)
```nix
mkCheck = name: deps: script:
  nixpkgs.lib.mapAttrs' (_: system:
    let pkgs = nixpkgs.legacyPackages.${system}; in
    pkgs.runCommand "check-${name}" { nativeBuildInputs = deps pkgs; } ''
      cd ${self}; ${script}; touch $out '') (nixpkgs.lib.genAttrs [ system ] (s: s));
```
Use for `nixfmt-check` (fail if `nixfmt --check` finds unformatted), `statix-check`, `deadnix-check`.

### Formatter package name
`pkgs.nixfmt` is deprecated/renamed → use `pkgs.nixfmt-rfc-style` in nixos-unstable.

## 3. Recursive attrset → .NET env vars (mkArrEnv)

### Bug — double prefix via mapAttrs'
```nix
# WRONG: flatten builds the full suffix key (SERVER__PORT), then mapAttrs' prefixes again
mkArrEnv = prefix: settings:
  let flatten = path: val: if isAttrs val then concatMapAttrs (k: v: flatten (path++[k]) v) val
                           else { "${prefix}__${concatStringsSep "__" (map toUpper path)}" = toString val; };
  in lib.mapAttrs' (k: v: nameValuePair "${prefix}__${k}" v) (flatten [] settings);
  # → SONARR__SERVER__PORT  (prefix + suffix, WRONG)

# RIGHT: flatten builds the FULL key including prefix, return 1:1
mkArrEnv = prefix: settings:
  let go = path: val:
        if lib.isAttrs val
        then lib.concatMapAttrs (k: v: go (path ++ [k]) v) val
        else { "${prefix}__${lib.concatStringsSep "__" (map lib.toUpper path)}" = toString val; };
  in go [] settings;
# mkSonarr { server.port = 5320; auth.method = "External"; }
# → { SONARR__SERVER__PORT = "5320"; SONARR__AUTH__METHOD = "External"; }
```
Rule: when building env-var keys from nested attrs, let the recursion build the COMPLETE key (prefix + path), and return it directly. Do NOT post-process with another `mapAttrs'` that re-prefixes.

## 4. Verification
- `nix flake check` is the only real proof — no nix binary in CI container means eval is UNTESTED until a Nix host runs it.
- Bracket balance: `for f in flake.nix; do o=$(grep -o "{" $f|wc -l); c=$(grep -o "}" $f|wc -l); echo "$f $o $c"; done` (must match).

## Pitfalls
- `eachDefaultSystem` iterator IS the system — never re-append `.${system}` to outputs.
- `inherit (x) y` expands to `y = x.y`; if you mean "pass the whole thing", write `y = x`.
- Decimal-enforcer via bash `grep` is weaker than `readDir` + `builtins.match` — use Nix-native.
- `.NET env vars`: ASP.NET config schema is `{APP}__{SECTION}__{KEY}` (double underscore separates levels).

## Project-specific notes
- `references/mediNix-project-context.md` — mediNIX-core unit-naming duality (Factory vs native
  nixpkgs), legacy residue in 57-maintenance/, fakeHash placeholder status, Shift-Left adoption.
  These belong in the protected `nixos-medinix-authoring` hub — recommend `hermes curator adopt`
  to merge them there.
