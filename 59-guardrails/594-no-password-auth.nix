# ---
# id: "594-no-password-auth"
# title: "SSH Keys-only, no PasswordAuthentication"
# domain: 50
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-21-security-hardening
# provides: []
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: "services.openssh"
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# 59-guardrails/594-no-password-auth.nix — No passwords, SSH keys only
{ config, lib, pkgs, ... }:

{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      ChallengeResponseAuthentication = false;
      PermitRootLogin = "prohibit-password";
      UsePAM = false;
    };
  };

  security.sudo.extraConfig = ''
    # media-admin + backup users get restricted sudo via 593-emergency-user / 594-backup-ssh
    # NO global NOPASSWD:ALL — portables Modul darf keinen hardcoded User mit vollen Rechten
  '';
}
