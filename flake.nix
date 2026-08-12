{
  description = "mediNix-core — Portable NixOS Media Stack Module";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url  = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      overlay = _: _: { };  # Zukünftige Pakete hier
      # Registry als JSON für Build-Zeit-Embedding (CLI-Tool)
      registryJson = builtins.toJSON (import ./lib/registry.nix { inherit (nixpkgs.lib) lib; }).services;
    in
    {
      # Das Hauptprodukt: importierbar als nixosModules.default
      nixosModules.default = import ./default.nix;
      nixosModules.mediNix = import ./default.nix;  # Alias für Abwärtskompatibilität

      overlays.default = overlay;
    }
    // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = nixpkgs.lib;
      in {
        # mediNix Health CLI (Build-Zeit aus Registry generiert)
        packages.medinix = pkgs.callPackage ./packages/mediNix-cli {
          inherit lib registryJson;
        };

        # CI-Check: dry-build ohne echte Hardware
        checks.nixos-check = (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.default
            {
              grapefruitMedia.enable = true;
              boot.loader.grub.enable = false;
              fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
              system.stateVersion = "24.11";
            }
          ];
        }).config.system.build.toplevel;

        # Smoke-Test: Navidrome Unit + Port-Isomorphie (Aufgabe 12 vervollständigt)
        checks.mediNix-smoke = (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.default
            ./tests/smoke-test.nix
            {
              grapefruitMedia.enable = true;
              boot.loader.grub.enable = false;
              fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
              system.stateVersion = "24.11";
            }
          ];
        }).config.system.build.toplevel;
      }
    );
}
