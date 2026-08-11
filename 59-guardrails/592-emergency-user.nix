# ---
# id: "592-emergency-user"
# title: "Break-Glass Emergency Account (dev mode only)"
# domain: 50
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-24-system-mode-switch
# provides: []
# requires: ["591-rollout-stages"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: "users.users.breakglass"
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# 59-guardrails/592-emergency-user.nix — Break-Glass Emergency Account
{ config, lib, pkgs, ... }:

let
  isDev = config.grapefruitMedia.mode == "development";
  isProd = config.grapefruitMedia.mode == "production";
in
{
  # Emergency user exists in BOTH modes
  users.users.emergency = {
    isNormalUser = true;
    description = "Break-Glass Emergency Account for mediNix";
    hashedPasswordFile = "/var/lib/secrets/emergency-password";  # Never in store!
    extraGroups = lib.mkIf isDev [ "wheel" ];
    # In Prod: no groups, only physical console access
  };

  # SSH must be enabled for emergency access
  assertions = [
    {
      assertion = config.services.openssh.enable;
      message = "SSH required for emergency access (592-emergency-user)";
    }
  ];
}
