# ---
# id: "50-mediNix-flake"
# title: "mediNix Flake (portable module entrypoint)"
# domain: 50
# folder: 50-media
# status: active
# complexity: 2
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-5043
# provides: ["flake"]
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: "https://github.com/grapefruit89/mediNix"
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
{
  description = "mediNix Media Stack (Portable NixOS Module)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        # Check configuration (dry-build without hardware)
        nixosConfigurations.check = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./default.nix
            {
              # Dummy hardware for check
              boot.loader.grub.enable = false;
              fileSystems."/" = { device = "dummy"; fsType = "tmpfs"; };
            }
          ];
        };
      }
    );
}
