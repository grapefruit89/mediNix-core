# Project Structure (Session 2026-06-04)

Root: `/opt/data/NixOS`
- `Nix Files/flake.nix` — `nixosConfigurations` nutzt `./hosts/<hostname>/...`
- `Nix Files/hosts/<hostname>/configuration.nix`
- `Nix Files/hosts/<hostname>/hardware-nixos.nix`
- `Nix Files/modules/00-core.nix` ... `90-policy`
- `ADR/`, `Guides/`, `GEMINI.md`
- Repo-Pfad enthält Leerzeichen: `/opt/data/NixOS/Nix Files`. Pfade always quoted.
