# ---
# id: "50-mediNix-default"
# title: "mediNix Master Boilerplate (SSoT, auto-imports all decades)"
# domain: 50
# folder: 50-media
# status: active
# complexity: 5
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5043
# provides: ["options.grapefruitMedia"]
# requires: ["lib/registry", "lib/service-factory"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# 50-mediNix Master Boilerplate (SSoT)
#
# Auto-import: every XX-domain/NNN-*.nix module is imported automatically.
# No hardcoded import list — adding a module file is enough. This is the
# "flat auto-import" pattern (ADR-0000 §9, avoids nested folder breakage).
{ lib, pkgs, config, ... }:

let
  cfg = config.grapefruitMedia;

  # Discover all domain directories (XX-*) and import their NNN-*.nix modules.
  domainDirs = lib.filterAttrs (n: t: t == "directory" && builtins.match "[0-9]{2}-.*" n != null)
    (builtins.readDir ./.);

  importModules = dir:
    let
      files = builtins.readDir (./. + "/${dir}");
      moduleFiles = lib.filterAttrs (n: t: t == "regular" && builtins.match "[0-9]{3}-.*\\.nix" n != null)
        files;
    in
      map (n: ./${dir}/${n}) (lib.attrNames moduleFiles);

  allModules = lib.flatten (map importModules (lib.attrNames domainDirs));
in
{
  imports = allModules;

  options.grapefruitMedia = {
    enable = lib.mkEnableOption "mediNix Media Stack";
    storage.mediaRoot = lib.mkOption {
      type = lib.types.str;
      default = "/data/media";
    };
    ports = lib.mkOption {
      type = lib.types.attrs;
      # SSoT: every port is derived from the registry (ADR-5043: Number × 10).
      default = builtins.mapAttrs (_: svc: svc.port)
        (import ./lib/registry.nix { inherit lib; });
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.media = { gid = 5000; };
  };
}
