# ---
# id: "525-ssh-antilockout"
# title: "SSH Anti-Lockout Hardening (port 22, Match Address)"
# domain: 50
# folder: 52-security
# status: draft
# complexity: 3
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-21-security-hardening.md
#   modules:
#     - path: Nix Files/modules/20-security.nix
# provides: []
# requires: []
# ports: [22, 2222]
# upstream_docs: []
# forum_links: []
# upstream_github: ''
# nixpkgs_attr: 'services.openssh'
# state_dir: ''
# uds_socket: false
# systemd_hardened: true
# ---
# 52-security/525-ssh-antilockout.nix — SSH hardening, fail-closed, anti-lockout
# Source: mediNix vector store (chat history), pattern-score 0.72
# VERIFY external options via Context7 / nixos.org before deploy (AGENTS.md Regel 0)
{ lib, config, ... }:

let
  cfg = config.grapefruitMedia.ssh;
in
{
  options.grapefruitMedia.ssh = {
    enable = lib.mkEnableOption "SSH anti-lockout hardening";
    port = lib.mkOption {
      type = lib.types.port;
      default = 22;
      description = "Primary SSH port. 22 is the canonical port — keep it. Do NOT migrate to high ports (53844 etc.): that is deprecated security theatre.";
    };
    backupPort = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = "Backup SSH port for lockout recovery (Dropbear/Stage-2 rescue).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      openFirewall = false;            # firewall is mediNix-owned (523-nftables)
      ports = [ cfg.port cfg.backupPort ];
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
      # Portable LAN restriction WITHOUT hardcoded interface names.
      # Match Address covers RFC1918 + Tailscale range (100.64.x).
      extraConfig = ''
        Match Address 127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,100.64.0.0/10
          PasswordAuthentication no
      '';
    };

    # Firewall: only the two SSH ports, close everything else.
    networking.firewall.allowedTCPPorts = [ cfg.port cfg.backupPort ];

    # Assertion: block any attempt to move SSH off the canonical port 22.
    # Rationale: high-port SSH (53844) is deprecated security theatre — it does
    # not add real protection, only obscurity, and breaks the documented ADR-21
    # contract. This fails the build loudly instead of silently drifting.
    assertions = lib.singleton {
      assertion = cfg.port == 22;
      message = ''
        SSH port migration rejected (ADR-21).
        The canonical SSH port is 22. High-port SSH (53844 etc.) is DEPRECATED
        — it is obscurity, not security, and breaks the documented contract.
        If you really must change it, override grapefruitMedia.ssh.port AND
        update 523-nftables-hardening.nix + 594-backup-ssh.nix consistently.
        Current value: ${toString cfg.port}.
      '';
    };

    # ⚠️ VERIFY: services.openssh.ports is stable in 24.11+.
    #   Context7: "nixos services.openssh ports option"
    #   nixos.org: search.nixos.org/options → services.openssh.ports
  };
}
