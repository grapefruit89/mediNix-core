# lib/service-contract.nix
#
# mediNix-core: Zentraler Metadaten-Vertrag (Manifest)
# Definiert den typisierten Steckbrief für alle mediNix-Dienste.
# Reiner Vertrag für Ingress, Monitoring und UI — KEIN systemd-Generator!
{ config, lib, ... }:

let
  cfg = config.medinix;
in
{
  options.medinix.manifest = lib.mkOption {
    description = ''
      Deklarativer Dienst-Steckbrief. Jeder Dienst in mediNix deklariert
      hier seine Identität, Routing-Klasse, UI-Daten und Monitoring-Ziele.
    '';
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, config, ... }:
        {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Aktivierungsstatus des Dienstes im Gesamtsystem.";
            };

            # --- PFLICHTFELDER (Kein Default: Fehlt die Angabe, bricht die Eval ab) ---
            num = lib.mkOption {
              type = lib.types.int;
              example = 551;
              description = "3-stellige Dezimalrahmen-ID (z. B. 551 -> Port 5510, UID 5510).";
            };

            accessGroup = lib.mkOption {
              type = lib.types.enum [
                "stream"
                "internal"
                "public"
                "idp"
                "none"
              ];
              description = "Routing-Klasse im Chameleon-Caddy (511).";
            };

            # --- MONITORING (Gatus / Health-Checks) ---
            monitoring = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Gatus-Monitoring für diesen Dienst aktivieren.";
              };

              type = lib.mkOption {
                type = lib.types.enum [
                  "http"
                  "tcp"
                  "systemd"
                  "none"
                ];
                default = "http";
                description = ''
                  Prüfmethode für Gatus:
                  - http: GET-Request auf Port + healthPath.
                  - tcp: Reiner TCP-Socket-Check (für Daemons ohne Web-UI).
                  - systemd: Prüft nur den Unit-Status 'active (running)'.
                  - none: Kein Monitoring (z. B. für Oneshot-Mover oder statische SPAs).
                '';
              };

              healthPath = lib.mkOption {
                type = lib.types.nullOr (lib.types.strMatching "^/.*$");
                default = null;
                example = "/health";
                description = "HTTP-Pfad für den Healthcheck. Pflicht wenn type == 'http'.";
              };

              expectedStatus = lib.mkOption {
                type = lib.types.int;
                default = 200;
                description = "Erwarteter HTTP-Statuscode (z. B. 200 oder 302).";
              };
            };

            # --- UI & LANDINGPAGE (518) ---
            ui = {
              title = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Anzeigename auf der Landingpage.";
              };

              description = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "Kurzbeschreibung der Funktionalität.";
              };

              icon = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Icon-Identifier (SVG-Symbol-ID im Sprite).";
              };

              group = lib.mkOption {
                type = lib.types.str;
                default = "Media";
                description = "Kategorie-Zuordnung auf der Landingpage.";
              };

              showOnLanding = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Dienst auf der Landingpage darstellen (nur bei stream/public wirksam).";
              };
            };

            # --- OPERATIONAL METADATA (OPS) ---
            ops = {
              priority = lib.mkOption {
                type = lib.types.str;
                default = "medium";
                description = "Betriebspriorität des Dienstes (z. B. high, medium, low).";
              };

              ramBudget = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "Erwartetes RAM-Budget.";
              };

              notes = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "Betriebsnotizen für Administratoren.";
              };
            };

            # --- ABGELEITETE SSoT-WERTE (Internal: Aus num mathematisch berechnet) ---
            port = lib.mkOption {
              type = lib.types.port;
              internal = true;
              default = config.num * 10;
              description = "Mathematisch abgeleiteter Dienst-Port (num * 10).";
            };

            uid = lib.mkOption {
              type = lib.types.int;
              internal = true;
              default = config.num * 10;
              description = "Mathematisch abgeleitete Dienst-UID (num * 10).";
            };

            stateDir = lib.mkOption {
              type = lib.types.path;
              internal = true;
              default = "/var/lib/${name}-${toString (config.num * 10)}";
              description = "Standard-StateDirectory des Dienstes.";
            };
          };
        }
      )
    );
  };

  config = lib.mkIf cfg.enable {
    assertions =
      let
        allNums = lib.mapAttrsToList (_: m: m.num) cfg.manifest;
        hasDuplicateNums = lib.length allNums != lib.length (lib.unique allNums);
        duplicateNums = lib.filter (num: lib.length (lib.filter (n: n == num) allNums) > 1) (
          lib.unique allNums
        );
      in
      lib.flatten [
        # 1. Monitoring Invariante: Wenn type == "http", muss ein healthPath angegeben sein
        (lib.mapAttrsToList (name: m: {
          assertion =
            !(m.enable && m.monitoring.enable && m.monitoring.type == "http" && m.monitoring.healthPath == null);
          message = ''
            [mediNix/manifest] Dienst '${name}' hat monitoring.type = "http", aber 'healthPath' ist null!
            -> Lösung: Setze medinix.manifest.${name}.monitoring.healthPath = "/..." (z. B. "/" oder "/health")
               oder wähle type = "tcp", "systemd" oder "none".
          '';
        }) cfg.manifest)

        # 2. Dezimalrahmen Invariante: num muss im Bereich 500..599 liegen (ADR-0000)
        (lib.mapAttrsToList (name: m: {
          assertion = m.num >= 500 && m.num <= 599;
          message = ''
            [mediNix/manifest] Dienst '${name}' nutzt num = ${toString m.num}.
            Der mediNix-Dezimalrahmen (ADR-0000) erlaubt für Projekt 5 nur Nummern zwischen 500 und 599!
          '';
        }) cfg.manifest)

        # 3. Kollisions-Invariante: Jede num darf nur einmal vergeben sein (ADR-0000 Port/UID-Eindeutigkeit)
        [
          {
            assertion = !hasDuplicateNums;
            message = ''
              [mediNix/manifest] Kollision im Dezimalrahmen: Doppelte 'num' im Manifest gefunden!
              Doppelte IDs: ${lib.concatMapStringsSep ", " toString duplicateNums}
              Jede Dienst-ID 'num' muss eindeutig sein (ADR-0000), da Port und UID (num * 10) daraus abgeleitet werden.
            '';
          }
        ]
      ];
  };
}
