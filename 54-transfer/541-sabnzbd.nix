# ---
# id: "541-sabnzbd"
# title: "SABnzbd — Usenet Downloader (Optimized with RestrictNetworkInterfaces)"
# domain: 54
# folder: 54-transfer
# status: active
# last_reviewed: 2026-09-07
# requires: ["lib/hardening-profiles", "lib/registry", "lib/memory-policy"]
# adr: ADR-5260
# ---
# Writes: state + mediaRoot/downloads + tmpfs. Not the library tree.
# Secrets are LoadCredentialEncrypted, never files under mediaRoot.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.sabnzbd;
  svc = config.medinix;
  reg = (import ../lib/registry.nix { inherit lib; }).services.sabnzbd;
  meta = config.medinix.manifest.sabnzbd;

  inherit (meta) port uid stateDir;
  gid = 5000;
  creds = import ../lib/creds.nix { inherit lib; };
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  memoryPolicy = import ../lib/memory-policy.nix { inherit lib; };

  vpnIf =
    if (config.services.vpnKillSwitch.vpnInterface or "") != "" then
      config.services.vpnKillSwitch.vpnInterface
    else if svc.vpn.interface != null && svc.vpn.interface != "" then
      svc.vpn.interface
    else
      "wg0";
in
{
  options.medinix.sabnzbd = {
    enable = lib.mkEnableOption "SABnzbd Usenet Downloader";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      defaultText = lib.literalExpression "null";
      description = ''
        Optionales Paket-Override für sabnzbd.
        null = NixOS-Modul-Default aus nixpkgs.
      '';
    };

    serverCredentialFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Pfad zur systemd-credential-Datei (.cred) mit Usenet-Server-Credentials.
        Format der entschlüsselten Datei:
          HOST=news.provider.com
          PORT=563
          USER=meinuser
          PASS=meinpasswort
          SSL=1
        Erfordert: systemd-creds encrypt --with-key=tpm2+host (siehe ONBOARDING.md).
      '';
    };
  };

  config = lib.mkMerge [
    # ── 1. SERVICE-MANIFEST (Top-Level: Immer im Katalog, SSoT) ─────────────
    {
      medinix.manifest.sabnzbd = {
        enable = cfg.enable;
        num = reg.num;
        accessGroup = "internal";

        ui = {
          title = "SABnzbd";
          description = "Usenet-Download-Client";
          icon = "sabnzbd";
          group = "Transfer";
        };

        monitoring = {
          enable = cfg.enable;
          type = "http";
          healthPath = "/api?mode=version";
          expectedStatus = 200;
        };

        ops = {
          priority = "medium";
          ramBudget = "4G";
          notes = "Usenet-Download-Client mit cgroup-VPN-Bindung.";
        };
      };
    }

    # ── 2. RUNTIME & SYSTEMD (Nur aktiv wenn cfg.enable = true) ─────────────
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = meta.num == reg.num;
          message = "[mediNix/541-sabnzbd] Manifest-Nummer (${toString meta.num}) stimmt nicht mit lib/registry.nix (${toString reg.num}) überein!";
        }
      ];

      users.users.sabnzbd = {
        inherit uid;
        group = "media";
        extraGroups = [ "media" ];
        home = stateDir;
        isSystemUser = true;
      };
      users.groups.media.gid = gid;

      services.sabnzbd = {
        enable = true;
        user = "sabnzbd";
        group = "media";
        # H30: the registry stateDir is canonical. nixpkgs derives BOTH
        # StateDirectory and configFile (/var/lib/<stateDir>/sabnzbd.ini) from
        # this option — so mediNix must not additionally set
        # serviceConfig.StateDirectory (that was the conflict).
        stateDir = "sabnzbd-${toString port}";
        openFirewall = false;
        configFile = null;
        allowConfigWrite = true;
        package = lib.mkIf (cfg.package != null) cfg.package;
        settings.misc = {
          inherit port;
          host = "127.0.0.1";
          language = svc.locale.language;
          download_dir = "${svc.storage.mediaRoot}/downloads";
          temp_dir = "/run/sabnzbd-tmp";
          check_new_rel = 0;
        };
      };

      systemd.services.sabnzbd = {
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        onFailure = [ "alert-ntfy@%n.service" ];
        serviceConfig = lib.mkMerge [
          profiles.python
          memoryPolicy.sabnzbd
          {
            User = "sabnzbd";
            Group = "media";
            UMask = "0002";
            TemporaryFileSystem = "/run/sabnzbd-tmp:size=1G";
            RuntimeDirectory = "sabnzbd-tmp";
            InaccessiblePaths = [
              "-/run/systemd/resolve"
              "-/run/dbus/system_bus_socket"
              "-${creds.storeDir}"
            ];
            ReadWritePaths = [
              stateDir
              "${svc.storage.mediaRoot}/downloads"
              "/run/sabnzbd-tmp"
            ];
          }
          # Defense-in-Depth: cgroup-BPF-Socketfilter im Linux-Kernel
          (lib.mkIf (svc.usenet-confinement.enable && vpnIf != "") {
            RestrictNetworkInterfaces = [
              "lo"
              vpnIf
            ];
          })
          {
            LoadCredentialEncrypted = lib.mkMerge [
              (lib.mkIf (cfg.serverCredentialFile != null) [
                "mediNix-sabnzbd-server:${cfg.serverCredentialFile}"
              ])
              (lib.mkIf (svc.secrets.sabnzbdApiKeyFile != null) [
                "sabnzbd-api-key:${svc.secrets.sabnzbdApiKeyFile}"
              ])
            ];
          }
        ];
        environment = lib.optionalAttrs (cfg.serverCredentialFile != null) {
          SABNZBD__SERVER_0__CREDENTIAL_FILE = "/run/credentials/sabnzbd.service/mediNix-sabnzbd-server";
        };
      };

      medinix.persist.extraPaths = [ stateDir ];
      medinix.ingress.vhosts."sabnzbd" = {
        accessGroup = "internal";
      };

      services.vpnKillSwitch.instances.sabnzbd = {
        enable = svc.usenet-confinement.enable;
        inherit uid;
      };
    })
  ];
}
