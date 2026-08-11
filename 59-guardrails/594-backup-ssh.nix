# ---
# id: "594-backup-ssh"
# title: "Backup SSH Daemon (Port 2222, key-only)"
# domain: 50
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-23-dropbear-rescue
# provides: []
# requires: []
# ports: [2222]
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: "systemd.services.sshd-backup"
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# ---
# 59-guardrails/594-backup-ssh.nix — Backup SSH on Port 2222
{ config, lib, pkgs, ... }:

{
  systemd.services.sshd-backup = {
    description = "Backup SSH Service (Port 2222)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.openssh}/bin/sshd -D -f ${pkgs.writeText "sshd-backup" ''
        Port 2222
        ListenAddress 0.0.0.0
        PasswordAuthentication no
        PermitRootLogin no
        AllowUsers jarvis
        PidFile /run/sshd-backup.pid
      ''}";
      Restart = "always";
    };
  };

  networking.firewall.allowedTCPPorts = [ 2222 ];
}
