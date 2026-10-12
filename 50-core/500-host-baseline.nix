# ---
# id: "500-host-baseline"
# title: "Host Hygiene & Systemd Journald Baseline"
# domain: 50
# folder: 50-core
# status: active
# complexity: 1
# last_reviewed: 2026-10-12
# ---
{
  config,
  lib,
  ...
}:

let
  cfg = config.medinix;
in
{
  options.medinix.hostHygiene = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Aktiviert mediNix Host-Hygiene, Journald-Limits und Anti-Pattern-Wächter.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.hostHygiene.enable) {
    services.journald.extraConfig = lib.mkDefault ''
      SystemMaxUse=500M
      SystemMaxFileSize=50M
      MaxRetentionSec=2week
    '';

    assertions = [
      {
        assertion = !(
          (config.system.autoUpgrade.enable or false)
          && (config.system.autoUpgrade.allowReboot or false)
        );
        message = "[mediNix/hostHygiene] 'system.autoUpgrade.allowReboot = true' ist verboten! Unkontrollierte Reboots gefährden laufende Datenbank- und Transcode-Jobs.";
      }
      {
        assertion = !(config.services.logrotate.enable or false);
        message = "[mediNix/hostHygiene] 'services.logrotate.enable = true' erkannt! mediNix nutzt natives systemd-journald mit SystemMaxUse.";
      }
      {
        assertion = !(config.networking.wireguard.useNetworkNamespace or false);
        message = "[mediNix/architecture] WireGuard-Network-Namespaces sind verboten. Ausschließlich UID-nftables-Routing.";
      }
      {
        assertion = lib.all (name: name == "sabnzbd") (lib.attrNames (config.services.vpnKillSwitch.instances or { }));
        message = "[mediNix/security] Unerwarteter Dienst im VPN-Killswitch! Nur SABnzbd (UID 5410) darf geroutet werden.";
      }
    ];
  };
}
