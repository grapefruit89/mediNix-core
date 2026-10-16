# ---
# id: "552-audiobookshelf"
# title: "Audiobookshelf"
# domain: 55
# last_reviewed: 2026-10-02
# sprite: 50-core/icons.svg#audiobookshelf
# adr: ADR-5520
# links:
#   adr: ADR-552-audiobookshelf
# ---
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.audiobookshelf;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.audiobookshelf;
  meta = config.medinix.manifest.audiobookshelf;

  inherit (meta) port stateDir;
  inherit (reg) sharedGid;
  creds = import ../lib/creds.nix { inherit lib; };
  metadataDir = "${svc.storage.metadataDir}/audiobookshelf";
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  memoryPolicy = import ../lib/memory-policy.nix { inherit lib; };

  package = if cfg.package != null then cfg.package else pkgs.audiobookshelf;

  # RT-2 (first-run race): `stream` = WAN ohne Proxy-Auth. Audiobookshelf hat
  # KEINE env-basierte Admin-Erstellung — der erste Besucher des offenen
  # Setup-Screens wird Root-User.
  exposedWan = builtins.elem meta.accessGroup [
    "stream"
    "public"
    "idp"
  ];
in
{
  options.medinix.audiobookshelf = {
    enable = lib.mkEnableOption "Audiobookshelf Server";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      defaultText = lib.literalExpression "null";
      description = ''
        Optionales Paket-Override für Audiobookshelf.
        null = NixOS-Modul-Default aus nixpkgs.
      '';
    };

    enableQuickSync = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        NOTE (misnomer): enableQuickSync benennt Intel QSV Transcode-Mapping.
        In mediNix-core zeigt dies korrekt auf Audiobookshelf-Hardware-Zugriff.
      '';
    };

    setupCompleted = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Explizite Bestätigung, dass der Root-User über den First-Run-Setup
        erstellt wurde. Prozedur: vHost auf accessGroup = "internal"
        (LAN-only) deployen, Setup in der Web-UI abschließen, danach erst auf
        stream exponieren und diesen Schalter setzen. Ohne Bestätigung ist
        ein WAN-exponiertes Audiobookshelf ein Build-Fehler — der erste
        Besucher des offenen Setup-Screens würde sonst zum Root-User.
      '';
    };
  };

  config = lib.mkMerge [
    # ── 1. SERVICE-MANIFEST (Top-Level: Immer im Katalog, SSoT) ─────────────
    {
      medinix.manifest.audiobookshelf = {
        inherit (cfg) enable;
        inherit (reg) num;
        accessGroup = "stream";

        ui = {
          title = "Audiobookshelf";
          description = "Hörbuch- und Podcast-Streaming";
          icon = "audiobookshelf";
          group = "Media";
        };

        monitoring = {
          inherit (cfg) enable;
          type = "http";
          healthPath = "/healthcheck";
          expectedStatus = 200;
        };

        ops = {
          priority = "medium";
          ramBudget = "1G";
          notes = "Hörbuch- und Podcast-Server.";
        };
      };
    }

    # ── 2. RUNTIME & SYSTEMD (Nur aktiv wenn cfg.enable = true) ─────────────
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = meta.num == reg.num;
          message = "[mediNix/552-audiobookshelf] Manifest-Nummer (${toString meta.num}) stimmt nicht mit lib/registry.nix (${toString reg.num}) überein!";
        }
        {
          assertion = !exposedWan || cfg.setupCompleted;
          message = ''
            [mediNix] audiobookshelf is on the WAN stream vhost (no proxy auth)
            and its first-run setup screen is OPEN — any first visitor would
            become the root user (Audiobookshelf has no env-based admin pre-seed).
            Procedure: keep medinix.ingress.vhosts."audiobookshelf".accessGroup =
            "internal" (LAN-only, CIDR abort) while you complete the initial
            setup in the web UI, then set medinix.audiobookshelf.setupCompleted
            = true before exposing it as stream.
          '';
        }
      ];

      # users.users.audiobookshelf besitzt die Engine (lib/decimal-framework.nix, UPG).
      users.groups.media.gid = sharedGid;

      systemd.tmpfiles.rules = [
        "d '${stateDir}' 0750 audiobookshelf media -"
        "d '${metadataDir}' 0775 audiobookshelf media -"
      ];

      systemd.services.audiobookshelf = {
        after = [ "network-online.target" ];
        requires = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        onFailure = [ "alert-ntfy@%n.service" ];
        serviceConfig = lib.mkMerge [
          profiles.nodejs
          memoryPolicy.audiobookshelf
          {
            ExecStart = "${package}/bin/audiobookshelf";
            User = "audiobookshelf";
            Group = "media";
            UMask = "0002";
            StateDirectory = "audiobookshelf-${toString port}";
            ReadWritePaths = [
              stateDir
              metadataDir
            ];
            BindReadOnlyPaths = [ "${svc.storage.mediaRoot}/audiobooks:${svc.storage.mediaRoot}/audiobooks" ];
            InaccessiblePaths = [ "-${creds.storeDir}" ];
          }
        ];
        environment = {
          PORT = toString port;
          CONFIG_PATH = stateDir;
          METADATA_PATH = metadataDir;
          AUDIOBOOKS_PATH = "${svc.storage.mediaRoot}/audiobooks";
        };
      };
    })
  ];
}
