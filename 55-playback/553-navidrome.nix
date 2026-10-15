# ---
# id: "553-navidrome"
# title: "Navidrome — Music Server"
# domain: 55
# last_reviewed: 2026-10-02
# sprite: 50-core/icons.svg#navidrome
# adr: ADR-5530
# ---
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.navidrome;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.navidrome;
  meta = config.medinix.manifest.navidrome;

  inherit (meta) port stateDir;
  inherit (reg) gid;
  creds = import ../lib/creds.nix { inherit lib; };
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  memoryPolicy = import ../lib/memory-policy.nix { inherit lib; };

  package = if cfg.package != null then cfg.package else pkgs.navidrome;

  # RT-2 (first-run race): `stream` = WAN ohne Proxy-Auth, und Navidromes
  # erster Aufruf zeigt einen offenen Setup-Screen.
  exposedWan = builtins.elem meta.accessGroup [
    "stream"
    "public"
    "idp"
  ];
  adminCred = cfg.adminPasswordCredential;
in
{
  options.medinix.navidrome = {
    enable = lib.mkEnableOption "Navidrome Music Server";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      defaultText = lib.literalExpression "null";
      description = ''
        Optionales Paket-Override für Navidrome.
        null = NixOS-Modul-Default aus nixpkgs.
      '';
    };

    adminPasswordCredential = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Pfad zur .cred-Datei (systemd-creds, TPM-versiegelt) mit dem initialen
        Navidrome-Admin-Passwort. Inhalt: Rohtext-Passwort oder
        ND_ADMIN_PASSWORD=<pw>. 553 exportiert den Wert beim Start als
        ND_DEVAUTOCREATEADMINPASSWORD — Navidrome legt den Admin NUR an,
        solange der Initial-Setup noch nicht abgeschlossen ist (danach wird
        die Variable ignoriert; in der UI geänderte Passwörter bleiben
        erhalten). Pflicht bei WAN-Exposure (stream), alternativ
        setupCompleted = true nach Setup über einen internal-vHost.
      '';
    };

    setupCompleted = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Explizite Bestätigung (Ack im Stil von allowUnauthenticated), dass
        das initiale Admin-Konto bereits in der Web-UI erstellt wurde —
        Setup-Prozedur: vHost auf accessGroup = "internal" (LAN-only)
        deployen, Setup abschließen, dann erst auf stream exponieren und
        diesen Schalter setzen. Ohne adminPasswordCredential ODER
        setupCompleted ist ein WAN-exponiertes Navidrome ein Build-Fehler.
      '';
    };
  };

  config = lib.mkMerge [
    # ── 1. SERVICE-MANIFEST (Top-Level: Immer im Katalog, SSoT) ─────────────
    {
      medinix.manifest.navidrome = {
        inherit (cfg) enable;
        inherit (reg) num;
        accessGroup = "stream";

        ui = {
          title = "Navidrome";
          description = "Musik-Streaming & Subsonic-Server";
          icon = "navidrome";
          group = "Media";
        };

        monitoring = {
          inherit (cfg) enable;
          type = "http";
          healthPath = "/ping";
          expectedStatus = 200;
        };

        ops = {
          priority = "medium";
          ramBudget = "512M";
          notes = "Subsonic-kompatibler Musik-Server.";
        };
      };
    }

    # ── 2. RUNTIME & SYSTEMD (Nur aktiv wenn cfg.enable = true) ─────────────
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = meta.num == reg.num;
          message = "[mediNix/553-navidrome] Manifest-Nummer (${toString meta.num}) stimmt nicht mit lib/registry.nix (${toString reg.num}) überein!";
        }
        {
          assertion = !exposedWan || adminCred != null || cfg.setupCompleted;
          message = ''
            [mediNix] navidrome is on the WAN stream vhost (no proxy auth) and its
            first-run setup screen is OPEN — any first visitor would create the
            admin account (wildcard DNS + CT logs make fresh deployments findable).
            Fix A (preferred): medinix.navidrome.adminPasswordCredential = sealed
            credential — 553 pre-seeds the initial admin via
            ND_DEVAUTOCREATEADMINPASSWORD (ignored once the initial setup is
            complete, UI-changed passwords survive).
            Fix B: keep the vhost at accessGroup = "internal" while you complete
            the web setup, then set medinix.navidrome.setupCompleted = true.
          '';
        }
      ];

      # users.users.navidrome besitzt die Engine (lib/decimal-framework.nix, UPG).
      users.groups.media.gid = gid;

      systemd.tmpfiles.rules = [
        "d '${stateDir}' 0750 navidrome media -"
      ];

      systemd.services.navidrome = {
        after = [ "network-online.target" ];
        requires = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        onFailure = [ "alert-ntfy@%n.service" ];
        serviceConfig = lib.mkMerge [
          profiles.nodejs
          memoryPolicy.navidrome
          (
            {
              # RT-2: wrapper statt direktem ExecStart — das initiale Admin-Passwort
              # wird aus dem entschlüsselten Credential gelesen und NUR in der
              # Prozess-Umgebung gesetzt (nicht in der Unit-Definition, nicht im
              # Store). ND_DEVAUTOCREATEADMINPASSWORD wirkt ausschließlich, solange
              # der Initial-Setup nicht abgeschlossen ist (maintainer-bestätigt).
              ExecStart = pkgs.writeShellScript "navidrome-start" ''
                set -euo pipefail
                if [ -f "''${CREDENTIALS_DIRECTORY:-}/nd-admin-pw" ]; then
                  pw="$(cat "$CREDENTIALS_DIRECTORY/nd-admin-pw")"
                  case "$pw" in
                    ND_ADMIN_PASSWORD=*) pw="''${pw#ND_ADMIN_PASSWORD=}" ;;
                  esac
                  export ND_DEVAUTOCREATEADMINPASSWORD="$pw"
                fi
                exec ${package}/bin/navidrome --configfile ${stateDir}/navidrome.toml
              '';
              User = "navidrome";
              Group = "media";
              UMask = "0002";
              StateDirectory = "navidrome-${toString port}";
              ReadWritePaths = [ stateDir ];
              BindReadOnlyPaths = [ "${svc.storage.mediaRoot}/music:${svc.storage.mediaRoot}/music" ];
              InaccessiblePaths = [ "-${creds.storeDir}" ];
            }
            // lib.optionalAttrs (adminCred != null) {
              LoadCredentialEncrypted = [ "nd-admin-pw:${adminCred}" ];
            }
          )
        ];
        environment = {
          ND_PORT = toString port;
          ND_ADDRESS = "127.0.0.1";
          ND_MUSICFOLDER = "${svc.storage.mediaRoot}/music";
          ND_DATAFOLDER = stateDir;
          ND_ENABLEUSERSONSIGNUP = "false";
        };
      };
    })
  ];
}
