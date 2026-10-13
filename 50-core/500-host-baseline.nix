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

  config = lib.mkMerge [
    {
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
          assertion = lib.all (i: (i.interfaceNamespace or null) == null && (i.socketNamespace or null) == null)
            (lib.attrValues (config.networking.wireguard.interfaces or { }));
          message = "[mediNix/architecture] WireGuard-Netns (interfaceNamespace/socketNamespace) ist verboten.";
        }
        {
          assertion =
            !(config.systemd.services ? sabnzbd)
            || (
              !((config.systemd.services.sabnzbd.serviceConfig.PrivateNetwork or false))
              && ((config.systemd.services.sabnzbd.serviceConfig.NetworkNamespacePath or null) == null)
              && !((config.systemd.services.sabnzbd.unitConfig or { }) ? JoinsNamespaceOf)
            );
          message = "[mediNix/architecture] VPN-confined Unit (sabnzbd) nutzt verbotenes Network-Namespace-Isolierungs-Feature.";
        }
        {
          assertion =
            config.services.vpnKillSwitch.instances == { }
            || (
              (config.services.vpnKillSwitch.instances ? sabnzbd)
              && (config.services.vpnKillSwitch.instances.sabnzbd.uid == 5410)
              && (lib.attrNames config.services.vpnKillSwitch.instances == [ "sabnzbd" ])
            );
          message = "[mediNix/security] Killswitch-Verletzung: Ausschließlich SABnzbd mit UID 5410 darf registriert sein.";
        }
        {
          assertion = !(config.virtualisation.docker.enable or false);
          message = "[mediNix/architecture] Docker-Daemon ('virtualisation.docker.enable = true') ist verboten! mediNix nutzt native systemd-Services (optional rootless Podman via oci-containers).";
        }
        {
          assertion = (config.containers or { }) == { };
          message = "[mediNix/architecture] 'containers.<name>' (systemd-nspawn) ist verboten! Alle mediNix-Dienste laufen nativ unter systemd.";
        }
        {
          assertion = lib.all (name:
            let svc = config.systemd.services.${name} or { }; in
            !(svc.serviceConfig.PrivateNetwork or false)
          ) (lib.attrNames (config.medinix.manifest or { }));
          message = "[mediNix/architecture] Zero-Container-Invariante verletzt: Kein mediNix-Dienst darf 'PrivateNetwork = true' (netns) nutzen!";
        }
        {
          assertion = lib.all (m:
            !lib.hasPrefix (toString config.medinix.storage.mediaRoot) (toString m.stateDir)
          ) (lib.attrValues (config.medinix.manifest or { }));
          message = "[mediNix/architecture] SQLite-Schutz-Invariante verletzt: StateDirectory darf niemals unter storage.mediaRoot liegen!";
        }
      ];
    }

    (lib.mkIf (cfg.enable && cfg.hostHygiene.enable) {
      services.journald.extraConfig = lib.mkDefault ''
        SystemMaxUse=500M
        SystemMaxFileSize=50M
        MaxRetentionSec=2week
      '';
    })
  ];
}
