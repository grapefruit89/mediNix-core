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
  registry = import ../lib/registry.nix { inherit lib; };
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

      assertions = [
        # C1: firewall = managed → mediNix OWNS the packet filter AND it MUST be
        # active. 500 enables networking.firewall.enable in that case; this
        # assertion is the guardrail. external/off make no claim.
        {
          assertion =
            cfg.hostIntegration.firewall != "managed"
            || config.networking.firewall.enable
            || config.networking.nftables.enable;
          message = ''
            [mediNix] hostIntegration.firewall = managed but no host firewall is
            active (500 enables networking.firewall.enable). Ref: ADR-520.
          '';
        }
        # One packet-filter owner only (firewall XOR nftables managed).
        {
          assertion = !(cfg.hostIntegration.firewall == "managed"
            && cfg.hostIntegration.nftables == "managed");
          message = ''
            [mediNix] Set only one packet-filter owner: firewall = managed XOR
            nftables = managed. Ref: ADR-520.
          '';
        }
      ];

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

      # R14 / C3+C6: only the explicitly allowed units — never "all registry
      # services" (that would auto-grow the privileged surface with the registry).
      security.sudo.extraConfig =
        let
          allowed = em.allowedServices;
          unitOf = n: (registry.services.${n} or { }).unitName or n;
          restartCmds = map
            (n: "/run/current-system/sw/bin/systemctl restart ${unitOf n}.service")
            allowed;
          cmdString = lib.concatStringsSep ", \\\n                                           " restartCmds;
        in
        lib.optionalString (restartCmds != []) ''
          media-admin ALL=(root) NOPASSWD: ${cmdString}
        '' + ''
          media-admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl status * --no-pager
        '';

      assertions = [
        # C6: an emergency user that may restart nothing is a config error —
        # declare intent explicitly instead of an implicit empty default.
        {
          assertion = em.allowedServices != [ ];
          message = ''
            [mediNix] security.emergencyUser.enable with an empty allowedServices
            is not allowed. List the units media-admin may restart. Ref: ADR-520.
          '';
        }
        # C4+C5: every allowlist entry must be a known registry service.
        {
          assertion = lib.all (n: registry.services ? ${n}) em.allowedServices;
          message = ''
            [mediNix] security.emergencyUser.allowedServices has unknown service(s):
            ${lib.concatStringsSep ", " (lib.filter (n: !(registry.services ? ${n})) em.allowedServices)}
            Ref: ADR-520.
          '';
        }
      ];
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
