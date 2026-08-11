# ---
# id: "50-mediNix-default"
# title: "mediNix Master Boilerplate (SSoT, imports all decades)"
# domain: 50
# folder: 50-media
# status: active
# complexity: 5
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-5043
# provides: ["options.grapefruitMedia"]
# requires: ["lib/registry", "lib/service-factory"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: "https://github.com/grapefruit89/mediNix"
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# 50-mediNix Master Boilerplate (SSoT)
{ lib, pkgs, config, ... }:

let
  cfg = config.grapefruitMedia;
in
{
  imports = [
    ./51-ingress/512-three-way-ingress.nix
    ./52-security/522-service-slimming.nix
    ./52-security/523-nftables-hardening.nix
    ./52-security/524-kernel-hardening.nix
    ./53-acquisition/default.nix
    ./54-transfer/541-mover.nix
    ./55-playback/551-jellyfin.nix
    ./56-requests/561-feishin.nix
    ./57-maintenance/571-sqlite-optimize.nix
    ./59-guardrails/591-rollout-stages.nix
    ./59-guardrails/593-no-password-auth.nix
    ./59-guardrails/594-backup-ssh.nix
    ./59-guardrails/595-ssh-assertions.nix
  ];

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
