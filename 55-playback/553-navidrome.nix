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
  creds = import ../lib/creds.nix { inherit lib; };
  reg = registry.navidrome;
  inherit (reg) port;
  inherit (reg) uid;
  inherit (reg) gid;
  inherit (reg) stateDir;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  # RT-2 (first-run race): `stream` = WAN ohne Proxy-Auth, und Navidromes
  # erster Aufruf zeigt einen offenen Setup-Screen (wer zuerst kommt, legt
  # das Admin-Konto an). Gelernt von F2: die RESOLVED vHost-Exposure fragen,
  # nicht die Registry-Klasse.
  exposedWan = builtins.elem (svc.ingress.vhosts."navidrome".accessGroup or "none") [
    "stream"
    "public"
    "idp"
  ];
  adminCred = cfg.adminPasswordCredential;
in
lib.mkIf cfg.enable {
  assertions = [
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

  users.users.navidrome = {
    inherit uid;
    group = "media";
    extraGroups = lib.mkAfter [ "media" ];
    home = stateDir;
    isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.navidrome = {
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = lib.mkMerge [
      profiles.nodejs
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
            exec ${pkgs.navidrome}/bin/navidrome --configfile ${stateDir}/navidrome.toml
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

  medinix.ingress.vhosts."navidrome" = {
    accessGroup = "stream";
  };
}
