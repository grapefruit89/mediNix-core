# ---
# id: "591-rollout-stages"
# title: "Rollout Stages (0=Emergency .. 3=Full)"
# domain: 50
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-5043
# provides: ["options.grapefruitMedia.rollout.stage"]
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# 59-guardrails/591-rollout-stages.nix — Rollout Stages (from Nix-Grok)
{ lib, pkgs, config, ... }:

{
  options.grapefruitMedia.rollout = {
    stage = lib.mkOption {
      type = lib.types.enum [ 0 1 2 3 ];
      default = 0;
      description = "Rollout stage: 0=Emergency, 1=Core, 2=Media, 3=Full";
    };
  };

  config = {
    # Stage 0: Emergency (SSH only, no media)
    assertions = lib.optional (config.grapefruitMedia.rollout.stage >= 0) [
      { assertion = config.services.openssh.enable; message = "SSH required for stage 0+"; }
    ];

    # Stage 1: Core services (Caddy, mDNS)
    assertions = lib.optional (config.grapefruitMedia.rollout.stage >= 1) [
      { assertion = config.services.caddy.enable; message = "Caddy required for stage 1+"; }
    ];

    # Stage 2: Media services (Jellyfin, *arr)
    # (Services enabled based on stage in their respective modules)
  };
}
