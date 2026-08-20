# ---
# id: "528-fde-tpm2"
# title: "Full Disk Encryption (LUKS2) + TPM2 Unlock Preparation"
# domain: 52
# folder: 52-security
# status: preparation
# complexity: 4
# last_reviewed: 2026-08-20
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia.security.fde;
in {
  options.grapefruitMedia.security.fde = {
    enable = lib.mkEnableOption "Full Disk Encryption via LUKS2 + TPM2 Auto-Unlock";
    
    rootUuid = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "UUID of the LUKS encrypted root partition (e.g. from blkid)";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.rootUuid != null;
        message = "Full Disk Encryption is enabled, but rootUuid is null. You must specify the LUKS partition UUID.";
      }
    ];

    # systemd in initrd is required for TPM2 unlock
    boot.initrd.systemd.enable = true;

    boot.initrd.luks.devices."root" = {
      device = "/dev/disk/by-uuid/${cfg.rootUuid}";
      crypttabExtraOpts = [ "tpm2-device=auto" ];
    };

    # NOTE: Before enabling this on a real machine, run:
    # systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/disk/by-uuid/<UUID>
  };
}
