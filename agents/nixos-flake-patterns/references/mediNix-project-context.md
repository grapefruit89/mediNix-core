# mediNIX-core Project Context (from 2026-08-12 session)

These are project-specific learnings that belong in the protected
`nixos-medinix-authoring` hub but could not be written there (user-owned).
Recommend `hermes curator adopt nixos-medinix-authoring` so they can be merged.

## Unit-Naming Dualität (CRITICAL — avoid the trap)
mediNIX has TWO unit-name worlds; mixing them breaks systemd ordering:
- **Factory modules** (53-acquisition/532-sonarr.nix, 541-sabnzbd, 551-554): the
  unit is `systemd.services."<name>-<NUM>"` → e.g. `sonarr-5320.service`,
  `sabnzbd-5410.service`. Port = Num×10 (Dezimalrahmen). These are the ACTIVE modules.
- **Native nixpkgs modules** (Caddy, Pocket-ID, SABnzbd OPTION `config.services.sabnzbd.enable`):
  the unit is `services.<name>` → e.g. `sabnzbd.service` (IF the native option is enabled).
- **WRONG fix**: "change `sabnzbd-5410.service` → `sabnzbd.service` in 574-provisioning.nix".
  The provisioning module uses Factory units (`sabnzbd-5410.service` etc.) which is CORRECT.
  Changing to `sabnzbd.service` breaks the After= ordering because no such Factory unit exists.

## Legacy residue in 57-maintenance/ (inert but Hygiene-Gate violation)
Files `prowlarr.nix`, `jellyfin.nix`, `profiles.nix`, `settings.nix`, `seerr.nix` reference
`sonarr.service` / `prowlarr.service` (old naming, pre-Factory). They are NOT auto-imported
(the loader only picks `NNN-*.nix` in `XX-domain/` folders; these have no 3-digit prefix)
so they are inert. But they violate Hygiene Gate (Tor 6: dead code). Action: delete them,
or if any logic is still needed, migrate into the Factory modules. Confirm by grepping the
auto-import regex before deleting.

## flake.nix status (this project)
- `lib.fakeHash` at 511-caddy.nix:105 is a DELIBERATE placeholder. It only enters the build
  path when `observability.crowdsec.enable = true` (default false). Before first deploy on q958,
  run `nix build` to get the real caddy+crowdsec-bouncer hash and substitute it. This is a
  real P0 blocker ONLY if CrowdSec is enabled.
- `nix flake check` is UNTESTED (no nix binary in Hermes container, q958 is OFF). All module
  changes are syntactically plausible + Context7-verified but not eval-proven until a Nix host runs.

## Shift-Left adoption (devNIX harvest, in flake.nix)
- `checks.nixos-check` = Ratsche (evals whole module set via throwaway `nixosConfigurations.check`).
- `checks.decimal-framework` = Nix-native readDir + builtins.match (NOT bash grep).
- `mkCheck` per-system wrapper + `formatter`/`devShells` bare (no `.${system}`) inside eachDefaultSystem.
- `nixfmt` → `nixfmt-rfc-style` (package renamed in nixos-unstable).
