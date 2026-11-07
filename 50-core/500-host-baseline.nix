# ---
# id: "500-host-baseline"
# title: "Host Hygiene & Systemd Journald Baseline"
# domain: 50
# folder: 50-core
# status: active
# complexity: 1
# last_reviewed: 2026-10-12
# links:
#   adr: ADR-5000
# ---
{
  config,
  lib,
  ...
}@args:

let
  cfg = config.medinix;
  self = args.self or null;
  # SSoT: UID nicht hartkodieren, sondern aus der Registry ableiten.
  sab = (import ./registry.nix { inherit lib; }).services.sabnzbd;
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
          assertion =
            !((config.system.autoUpgrade.enable or false) && (config.system.autoUpgrade.allowReboot or false));
          message = "[mediNix/hostHygiene] 'system.autoUpgrade.allowReboot = true' ist verboten! Unkontrollierte Reboots gefährden laufende Datenbank- und Transcode-Jobs.";
        }
        # Bewusst KEINE Pruefung auf `services.logrotate.enable`: nixpkgs setzt in
        # nixos/modules/system/boot/systemd.nix selbst Eintraege fuer
        # /var/log/wtmp und /var/log/btmp. Dadurch ist der Default von `enable`
        # bereits true, ohne dass der Host etwas tut. Die alte Fassung schlug
        # deshalb je nach nixpkgs-Stand zufaellig fehl (Host e554fab: true,
        # mediNix-CI 3ec6363: false) - Versions-Skew, kein Architekturverstoss.
        # Geprueft wird jetzt das eigentliche Ziel: der Host bringt keine EIGENEN
        # logrotate-Settings mit, sondern ueberlaesst das journald.
        {
          assertion =
            let
              upstreamDefaults = [
                "/var/log/wtmp"
                "/var/log/btmp"
              ];
              ownSettings = builtins.filter (name: !(builtins.elem name upstreamDefaults)) (
                builtins.attrNames (config.services.logrotate.settings or { })
              );
            in
            ownSettings == [ ];
          message = "[mediNix/hostHygiene] Eigene logrotate-Settings erkannt! mediNix nutzt natives systemd-journald mit SystemMaxUse - Host-Logrotation ist unnoetig.";
        }
        {
          assertion = !(config.networking.wireguard.useNetworkNamespace or false);
          message = "[mediNix/architecture] WireGuard-Network-Namespaces sind verboten. Ausschließlich UID-nftables-Routing.";
        }
        {
          assertion = lib.all (
            i: (i.interfaceNamespace or null) == null && (i.socketNamespace or null) == null
          ) (lib.attrValues (config.networking.wireguard.interfaces or { }));
          message = "[mediNix/architecture] WireGuard-Netns (interfaceNamespace/socketNamespace) ist verboten.";
        }
        {
          assertion =
            !(config.systemd.services ? sabnzbd)
            || (
              !(config.systemd.services.sabnzbd.serviceConfig.PrivateNetwork or false)
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
              && (config.services.vpnKillSwitch.instances.sabnzbd.uid == sab.uid)
              && (lib.attrNames config.services.vpnKillSwitch.instances == [ "sabnzbd" ])
            );
          message = "[mediNix/security] Killswitch-Verletzung: Ausschließlich SABnzbd mit UID ${toString sab.uid} darf registriert sein.";
        }
        {
          assertion = !(config.virtualisation.docker.enable or false);
          message = "[mediNix/architecture] Docker-Daemon ('virtualisation.docker.enable = true') ist verboten! mediNix nutzt native systemd-Services und KEINE Container-Engine (ADR-0000, docs/NO-CONTAINERS.md).";
        }
        {
          assertion = (config.containers or { }) == { };
          message = "[mediNix/architecture] 'containers.<name>' (systemd-nspawn) ist verboten! Alle mediNix-Dienste laufen nativ unter systemd.";
        }
        {
          assertion = lib.all (
            name:
            let
              svc = config.systemd.services.${name} or { };
            in
            !(svc.serviceConfig.PrivateNetwork or false)
          ) (lib.attrNames (config.medinix.manifest or { }));
          message = "[mediNix/architecture] Zero-Container-Invariante verletzt: Kein mediNix-Dienst darf 'PrivateNetwork = true' (netns) nutzen!";
        }
        {
          assertion = lib.all (
            m: !lib.hasPrefix (toString config.medinix.storage.mediaRoot) (toString m.stateDir)
          ) (lib.attrValues (config.medinix.manifest or { }));
          message = "[mediNix/architecture] SQLite-Schutz-Invariante verletzt: StateDirectory darf niemals unter storage.mediaRoot liegen!";
        }
        {
          assertion =
            !lib.hasPrefix (toString config.medinix.storage.mediaRoot) (
              toString config.medinix.storage.downloadDir
            );
          message = "[mediNix/storage] Das Download-Verzeichnis darf kein Teil des HDD-Archivs (mediaRoot) sein.";
        }
      ];
    }

    (lib.mkIf (cfg.enable && cfg.hostHygiene.enable) {
      services.logrotate.enable = lib.mkDefault false;
      environment.etc."systemd/journald.conf.d/10-mediNix.conf".text = ''
        [Journal]
        Storage=persistent
        SystemMaxUse=500M
        SystemMaxFileSize=50M
        SystemKeepFree=2G
        MaxRetentionSec=2week
        RateLimitIntervalSec=0
        RateLimitBurst=0
      '';
    })

    (lib.mkIf cfg.enable {
      system.nixos.label = lib.mkIf (
        self != null
      ) "${config.system.nixos.version}-${self.shortRev or "dirty"}";
      system.configurationRevision = lib.mkIf (self != null) (self.rev or null);
    })
  ];
}
