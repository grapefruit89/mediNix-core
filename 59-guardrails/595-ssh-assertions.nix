# ---
# id: "595-ssh-assertions"
# title: "Build Assertions: fail if SSH would lock out"
# domain: 50
# folder: 59-guardrails
# status: active
# complexity: 3
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-5043
#   adr: ADR-21-security-hardening
# provides: []
# requires: ["593-no-password-auth", "594-backup-ssh", "525-ssh-antilockout"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: "assertions"
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# 59-guardrails/595-ssh-assertions.nix — Build fails on SSH danger
{ config, lib, pkgs, ... }:

{
  # Build-time guardrails for SSH. Every assertion fails the deployment with a
  # message that tells you WHAT broke, WHY, and HOW to fix it.
  assertions = [
    {
      assertion = config.services.openssh.enable;
      message = ''
        [595] SSH service is DISABLED.
        A mediNix host without SSH is unreachable after reboot.
        Fix: set grapefruitMedia.ssh.enable = true (or services.openssh.enable = true).
      '';
    }
    {
      assertion = !config.networking.nftables.enable
        || builtins.elem 22 config.networking.firewall.allowedTCPPorts;
      message = ''
        [595] nftables is active but port 22 (canonical SSH) is NOT in
        allowedTCPPorts. The build would lock you out of the host.
        Fix: add 22 to networking.firewall.allowedTCPPorts in
        523-nftables-hardening.nix (keep it consistent with 525-ssh-antilockout).
      '';
    }
    {
      assertion = config.services.openssh.settings.PasswordAuthentication == false;
      message = ''
        [595] SSH PasswordAuthentication is ENABLED.
        Key-only auth is mandatory (ADR-21). Passwords on a LAN-exposed SSH are
        a brute-force target.
        Fix: set services.openssh.settings.PasswordAuthentication = false.
      '';
    }
    {
      assertion = config.systemd.services.sshd-backup.enable or false;
      message = ''
        [595] Backup SSH daemon (port 2222, 594-backup-ssh.nix) is NOT running.
        If the primary SSH fails to start you have no out-of-band rescue path.
        Fix: enable 594-backup-ssh (dropbear/stage-2 rescue) before deploying.
      '';
    }
  ];

  # Soft warning, not a blocker: reminds without failing the build.
  warnings = lib.optional config.networking.nftables.enable
    "[595] nftables active — confirm port 22 is allowed in 523-nftables-hardening.nix.";
}
