# ---
# id: "520-core-security"
# title: "Host baseline: media GID, break-glass user, recommended sysctl, optional LUKS+TPM2"
# domain: 52
# folder: 52-security
# status: active
# complexity: 3
# last_reviewed: 2026-09-02
# links:
# provides: ["media-gid", "emergency-user", "recommended-sysctl"]
# requires: ["lib/registry"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-0000
# ---
# 520 is the host-baseline organ for domain 52.
# Not a kitchen sink: VPN stays in 525 + 526 (different failure domain).
# Former 528 (FDE prep) and 529 (recommended.* only) were header-heavy stubs.
{ config, lib, ... }:

let
  cfg = config.medinix;
  em  = cfg.security.emergencyUser;
  fde = cfg.security.fde or { enable = false; rootUuid = null; };
in {
  options.medinix.security.fde = {
    enable = lib.mkEnableOption "LUKS2 root + TPM2 unlock (initrd systemd)";
    rootUuid = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "UUID of the LUKS root partition (blkid).";
    };
  };

  config = lib.mkMerge [

    (lib.mkIf cfg.enable {
      users.groups.media.gid = 5000;
      users.users.media = {
        isSystemUser = true;
        group = "media";
      };

      assertions = [{
        assertion =
          (cfg.hostIntegration.firewall or "off") != "managed"
          || config.networking.firewall.enable
          || config.networking.nftables.enable;
        message = ''
          [mediNix] hostIntegration.firewall = managed only opens 80/443 lists.
          It does not turn the host firewall on. Set networking.firewall.enable
          or networking.nftables.enable, or set firewall = external|off.
        '';
      }];

      # Host may apply these. 520 does not write boot.kernel.sysctl itself
      # (additive host integration — README).
      medinix.recommended.sysctl = {
        "kernel.kptr_restrict" = 2;
        "kernel.dmesg_restrict" = 1;
        "kernel.kexec_load_disabled" = 1;
        "kernel.yama.ptrace_scope" = 1;
        "fs.protected_hardlinks" = 1;
        "fs.protected_symlinks" = 1;
        "fs.protected_fifos" = 2;
        "fs.protected_regular" = 2;
        "net.ipv4.conf.all.accept_redirects" = 0;
        "net.ipv6.conf.all.accept_redirects" = 0;
        "net.ipv4.conf.all.accept_source_route" = 0;
        "net.ipv4.conf.all.rp_filter" = 2;
        "net.ipv4.conf.default.rp_filter" = 2;
      };
      medinix.recommended.firewall.checkReversePath = false;
      medinix.recommended.mountOptions.staging = [ "noexec" "nosuid" "nodev" ];
    })

    (lib.mkIf (cfg.enable && em.enable) {
      users.users.media-admin = {
        isNormalUser = true;
        extraGroups = [ "media" ];
        openssh.authorizedKeys.keys = em.sshKeys;
      };

      security.sudo.extraConfig =
        let
          registry = import ../lib/registry.nix { inherit lib; };
          restartCmds = lib.mapAttrsToList
            (_: svc: "/run/current-system/sw/bin/systemctl restart ${svc.unitName}.service")
            registry.services;
          cmdString = lib.concatStringsSep ", \\\n                                           " restartCmds;
        in ''
          media-admin ALL=(root) NOPASSWD: ${cmdString}
          media-admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl status * --no-pager
        '';
    })

    (lib.mkIf (cfg.enable && fde.enable) {
      assertions = [{
        assertion = fde.rootUuid != null;
        message = ''
          [mediNix] security.fde.enable requires security.fde.rootUuid.
          Enroll before first boot:
            systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/disk/by-uuid/<UUID>
        '';
      }];
      boot.initrd.systemd.enable = true;
      boot.initrd.luks.devices."root" = {
        device = "/dev/disk/by-uuid/${fde.rootUuid}";
        crypttabExtraOpts = [ "tpm2-device=auto" ];
      };
    })
  ];
}
