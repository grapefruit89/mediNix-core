# ---
# id: "5xx-service-template"
# title: "Agent Blueprint — Kopiere diese Vorlage für jeden neuen Dienst"
# status: template
# contract: schemaVersion = 1 (ADR-0010)
# ---
# Packaging-Hierarchie & Invarianten (ADR-0010):
# 1. Prio 1 (Standard): Natives Nixpkgs-Paket direkt unter systemd.
# 2. Prio 2 (Ausnahme): Falls OCI zwingend nötig ist, deklarativ via
#    'virtualisation.oci-containers' mit Podman (daemonless),
#    gebunden an 127.0.0.1:<port> und ins Manifest gemappt.
#    Docker-Daemon und systemd-nspawn sind strikt verboten.
# 3. State-Isolation: SQLite-Datenbanken verbleiben unter stateDir (/var/lib/...),
#    niemals unter storage.mediaRoot!
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # ══════════════════════════════════════════════════════════════════════════
  # 1. PARAMETER DES DIENSTES (Hier ausfüllen)
  # ══════════════════════════════════════════════════════════════════════════
  serviceName = "myservice"; # Kleinbuchstaben, z. B. "audiobookshelf"
  svcNum      = 559;         # Modul-ID aus lib/registry.nix (500–599)
  accessGroup = "internal";  # "internal" | "stream" | "public" | "idp" | "none"

  # Ableitungen (Dezimalrahmen: Port = UID = Num * 10)
  cfg      = config.medinix.${serviceName};
  meta     = config.medinix.manifest.${serviceName};
  inherit (meta) port uid stateDir;

  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
in
{
  # ══════════════════════════════════════════════════════════════════════════
  # 2. DIENST-OPTIONEN (Privater Scope des Moduls)
  # ══════════════════════════════════════════════════════════════════════════
  options.medinix.${serviceName} = {
    enable = lib.mkEnableOption "${serviceName} service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.${serviceName};
      description = "Zu verwendendes Upstream-Paket.";
    };
  };

  # ══════════════════════════════════════════════════════════════════════════
  # 3. MANIFEST-PUBLISHER (Öffentliches Schwarzes Brett für Caddy & Gatus)
  # ══════════════════════════════════════════════════════════════════════════
  config.medinix.manifest.${serviceName} = {
    inherit (cfg) enable;
    num = svcNum;
    inherit accessGroup;

    ui = {
      title = "${serviceName}";
      description = "Kurzbeschreibung des Dienstes";
      icon = "${serviceName}";
      group = "Media"; # "Media" | "Downloads" | "System"
    };

    monitoring = {
      inherit (cfg) enable;
      type = "http"; # "http" | "tcp" | "none"
      healthPath = "/health"; # Muss mit / beginnen!
      expectedStatus = 200;
    };

    ops = {
      priority = "medium"; # "high" | "medium" | "low"
      ramBudget = "512M";
      notes = "Standard-Dienst.";
    };

    sources = {
      upstream = "https://example.com";
      repo     = "https://github.com/example/repo";
      nixos    = "https://search.nixos.org/options";
      api      = "https://example.com/api-docs";
    };
  };

  # ══════════════════════════════════════════════════════════════════════════
  # 4. SYSTEMD & RUNTIME (Wird nur instanziiert, wenn enable = true)
  # ══════════════════════════════════════════════════════════════════════════
  config = lib.mkIf cfg.enable {
    # Fail-Closed Invariante gegen Desynchronisation
    assertions = [
      {
        assertion = meta.port == svcNum * 10 && meta.uid == svcNum * 10;
        message = "[mediNix/${toString svcNum}-${serviceName}] Port/UID-Invariante verletzt!";
      }
    ];

    # Eigener System-User im Dezimalrahmen
    users.users.${serviceName} = {
      inherit uid;
      group = "media";
      home = stateDir;
      isSystemUser = true;
    };

    systemd.services.${serviceName} = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      onFailure = [ "alert-ntfy@%n.service" ];

      serviceConfig = lib.mkMerge [
        profiles.base # oder profiles.network, profiles.python
        {
          ExecStart = "${cfg.package}/bin/${serviceName} --port ${toString port}";
          User = serviceName;
          Group = "media";
          StateDirectory = "${serviceName}-${toString port}";
          Restart = "on-failure";
          RestartSec = "10s";
        }
      ];
    };
  };
}
