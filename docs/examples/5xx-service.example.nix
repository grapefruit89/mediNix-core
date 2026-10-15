# ---
# id: "5xx-service-template"
# title: "Agent Blueprint — Kopiere diese Vorlage fuer jeden neuen Dienst"
# status: template
# contract: schemaVersion = 1 (ADR-0010)
# ---
# Diese Vorlage ist ABSICHTLICH minimal. Sie enthaelt nur, was ein Dienst
# wirklich selbst beitragen MUSS — alles andere ist abgeleitet oder gehoert
# jemand anderem:
#
#   Eigentuemer                            | Was
#   ---------------------------------------|-----------------------------------
#   lib/decimal-framework.nix (Engine)     | users.users.<name>, UPG-Gruppe,
#                                          | StateDirectory/-Mode, UMask, WorkingDirectory
#   lib/service-factory.nix                | Unit-Geruest, Hardening-Profil, tmpfiles
#   lib/service-contract.nix               | Manifest-Schema, Pflichtfelder, Assertions
#   DIESES MODUL                           | Manifest-Daten + notfalls Unit-Feinheiten
#
# Deshalb gilt hier bewusst NICHT: kein users.users, kein Group, kein
# stateDir-Port-Suffix (ADR-0000 §9) und keine Container — kein Docker, kein
# Podman/oci-containers, kein systemd-nspawn (das erzwingen die Assertions in
# 50-core/500-host-baseline.nix fail-closed).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # ══════════════════════════════════════════════════════════════════════════
  # 1. PARAMETER DES DIENSTES — das ist der "Ankreuzbogen"
  # ══════════════════════════════════════════════════════════════════════════
  serviceName = "myservice"; # Kleinbuchstaben; dient als User-, Unit- und stateDir-Name
  svcNum = 559; # 5 (Projekt) · Dekade · Slot. Slot 0 ist reserviert (Block-ID, kein Daemon).
  accessGroup = "internal"; # "internal" | "stream" | "public" | "idp" | "none"

  # Ableitungen (ADR-0000: Port = UID = Primaer-GID = Num * 10)
  cfg = config.medinix.${serviceName};
  meta = config.medinix.manifest.${serviceName};
  inherit (meta) uid stateDir;
in
{
  # ══════════════════════════════════════════════════════════════════════════
  # 2. OPTIONEN DES MODULS (privater Scope)
  # ══════════════════════════════════════════════════════════════════════════
  options.medinix.${serviceName} = {
    enable = lib.mkEnableOption "${serviceName} service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.${serviceName};
      description = "Zu verwendendes Upstream-Paket.";
    };
  };

  config = lib.mkMerge [
    # ════════════════════════════════════════════════════════════════════════
    # 3. MANIFEST — das schwarze Brett fuer Caddy, Gatus und die Landingpage
    #    Pflicht: num, accessGroup. Alles andere hat Defaults (siehe Contract).
    # ════════════════════════════════════════════════════════════════════════
    {
      medinix.manifest.${serviceName} = {
        inherit (cfg) enable;
        num = svcNum;
        inherit accessGroup;

        ui = {
          title = "${serviceName}";
          description = "Kurzbeschreibung des Dienstes";
          icon = "${serviceName}";
          group = "Media"; # Landingpage-Kategorie
        };

        monitoring = {
          inherit (cfg) enable;
          type = "http"; # "http" | "tcp" | "systemd" | "none"
          healthPath = "/health"; # muss mit "/" beginnen
          expectedStatus = 200;
        };

        ops = {
          priority = "medium"; # "high" | "medium" | "low"
          ramBudget = "512M";
          notes = "Wofuer ist dieser Dienst da?";
        };

        sources = {
          upstream = "https://example.com";
          repo = "https://github.com/example/repo";
          nixos = "https://search.nixos.org/options";
        };
      };
    }

    # ════════════════════════════════════════════════════════════════════════
    # 4. UNIT — die Factory liefert ein ganzes Config-Fragment (systemd.*,
    #    medinix.*). Sie wird deshalb als eigener mkMerge-Block gemergt und
    #    NICHT einem Attribut wie systemd.services.<name> zugewiesen.
    # ════════════════════════════════════════════════════════════════════════
    (lib.mkIf cfg.enable (
      import ../lib/service-factory.nix { inherit lib config pkgs; } {
        name = serviceName;
        ownsAccount = false; # users.users.<name> besitzt die Engine (UPG)
        inherit uid stateDir; # uid fuer Guardrail 591, stateDir fuer StateDirectory
        execStart = "${cfg.package}/bin/${serviceName}";
        profile = "base"; # lib/hardening-profiles.nix: base|network|script|python|dotnet|…
        extraConfig = {
          # Nur dienstspezifische Feinheiten. Beispiele:
          # Environment = [ "PORT=${toString meta.port}" ];
          # AmbientCapabilities = [ "CAP_NET_RAW" ];   # nur aus der Capability-Whitelist
        };
      }
    ))
  ];
}
