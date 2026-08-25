# Shift-Left Flake Patterns (adapted from grapefruit89/devNIX → mediNIX-core)

## Source
devNIX `flake.nix` (main) — ADR-8000 pattern. mediNIX-core adapted it with these corrections.

## What mediNIX-core flake.nix gained
1. **Ratsche (eval check):** `nixosConfigurations.check` evaluates the module with
   `medinix.enable = true` + dummy tmpfs root. `checks.nixos-check =
   nixosConfigurations.check.config.system.build.toplevel` catches EVERY attribute-missing
   / type error at `nix flake check` time — before deploy. This is what would have caught
   the `pocketId` registry-key bug and the `cfg.services.*.apiKeyFile` secrets-path bug.
2. **Decimal-enforcer (`checks.decimal-framework`):** Nix-native (readDir + regex
   `^[0-9]{3}-.*`, project digit = 5), not bash-grep. Rejects wrong leading digit and
   duplicate folder numbers. NOTE: original devNIX used project digit 8 and 3-digit
   module folders; mediNIX uses 5.
3. **Linting (`mkCheck` helper):** per-SYSTEM wrapper around `pkgs.runCommand`, runs
   `nixfmt-rfc-style --check`, `statix check .`, `deadnix --fail .`. `--check/--fail`
   never modifies the tree, only turns CI red.
4. **formatter + devShell:** `formatter.${system} = pkgs.nixfmt-rfc-style`;
   `devShells.${system}.default` with nixfmt-rfc-style, statix, deadnix, nix-tree, jq.

## Corrections made vs. naive copy
- `pkgs.nixfmt` (devNIX) → `pkgs.nixfmt-rfc-style` (current nixos-unstable name).
- `mkCheck` must be wrapped in `lib.mapAttrs' (_: system: ...)` so checks become
  per-system attrsets (flake-utils requirement); call with `.${system}`.
- Don't hardcode `network-online.target` in the service factory if `network.target`
  is intended — verify against the deploy host's network model.
- The ratsche ALREADY existed in mediNIX as `checks.nixos-check`; promote
  `nixosConfigurations.check` to top-level so it's reusable, don't duplicate it.

## Verification gap (honest)
`nix flake check` could NOT be run in the agent container (no nix binary, q958 off).
Syntax is plausible but the eval test is pending until a host with nix builds it.
