# ---
# id: "541-sabnzbd"
# title: "SABnzbd — Usenet Downloader (Optimized with RestrictNetworkInterfaces)"
# domain: 54
# folder: 54-transfer
# status: active
# last_reviewed: 2026-09-07
# requires: ["lib/hardening-profiles", "lib/memory-policy"]
# adr: ADR-526
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
  meta = config.medinix.manifest.sabnzbd;

  inherit (meta) port uid stateDir;
  creds = import ../lib/creds.nix { inherit lib; };
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  memoryPolicy = import ../lib/memory-policy.nix { inherit lib; };
  tempDir = "/run/sabnzbd-tmp";

  vpnIf =
    if (config.services.vpnKillSwitch.vpnInterface or "") != "" then
      config.services.vpnKillSwitch.vpnInterface
    else if svc.vpn.interface != null && svc.vpn.interface != "" then
      svc.vpn.interface
    else
      "";
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
        inherit (cfg) enable;
        num = 541;
        accessGroup = "internal";
        extraGroups = [ "media" ];

        ui = {
          title = "SABnzbd";
          description = "Usenet-Download-Client";
          icon = "sabnzbd";
          group = "Transfer";
        };

        monitoring = {
          inherit (cfg) enable;
          type = "http";
          healthPath = "/api?mode=version";
          expectedStatus = 200;
        };

        arr = {
          role = "downloader";
        };

        ops = {
          priority = "medium";
          ramBudget = "4G";
          notes = "Usenet-Download-Client mit cgroup-VPN-Bindung.";
        };

        sources = {
          upstream = "https://sabnzbd.org/wiki/";
          repo = "https://github.com/sabnzbd/sabnzbd";
          nixos = "https://wiki.nixos.org/wiki/SABnzbd";
          nixpkgsTest = "https://github.com/NixOS/nixpkgs/blob/master/nixos/tests/sabnzbd.nix";
          api = "https://sabnzbd.org/wiki/advanced/api";
        };
      };
    }

    # ── 2. RUNTIME & SYSTEMD (Nur aktiv wenn cfg.enable = true) ─────────────
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.sabnzbd.settings.misc.port == meta.port;
          message = "[mediNix/541-sabnzbd] Port-Konflikt: SABnzbd MUSS auf ${toString meta.port} laufen.";
        }
        {
          assertion = !(config.systemd.services.sabnzbd.serviceConfig.PrivateNetwork or false);
          message = "[mediNix/541-sabnzbd] 'PrivateNetwork = true' (netns) ist verboten! SABnzbd nutzt UID-Routing (${toString meta.uid}).";
        }
        {
          assertion =
            (!svc.usenet-confinement.enable)
            || ((config.services.vpnKillSwitch.instances.sabnzbd.uid or null) == meta.uid);
          message = "[mediNix/541-sabnzbd] UID-Mismatch: SABnzbd muss für den Killswitch zwingend UID ${toString meta.uid} nutzen.";
        }
        {
          assertion = (!svc.usenet-confinement.enable) || (vpnIf != "");
          message = ''
            [mediNix/541-sabnzbd] FEHLER: VPN-DEADSWITCH KONFIGURATIONSFEHLER!
            SABnzbd ist aktiv mit usenet-confinement.enable = true, aber weder 'medinix.vpn.interface' noch 'services.vpnKillSwitch.vpnInterface' ist definiert.

            ARCHITEKTUR-GRUND:
            SABnzbd lädt geschützte Inhalte. Um IP-Leaks ins WAN bei Verbindungsausfall
            zu 100 % auszuschließen, MUSS zwingend ein physisches VPN-Interface (z. B. "wg0")
            für die cgroup-BPF-Isolation und den systemd-Deadswitch gebunden sein.

            BEHEBUNG:
            Definiere in deiner Host-Konfiguration:
              medinix.vpn.interface = "wg0";
          '';
        }
        {
          assertion =
            let
              ifaces = config.systemd.services.sabnzbd.serviceConfig.RestrictNetworkInterfaces or [ ];
            in
            (!svc.usenet-confinement.enable)
            || (lib.elem "lo" ifaces && lib.elem vpnIf ifaces && (lib.length ifaces == 2));
          message = ''
            [mediNix/541-sabnzbd] FEHLER: RESTRICT_NETWORK_INTERFACES INVARIANTE VERLETZT!
            Die cgroup-Schnittstellenbeschränkung für SABnzbd wurde manipuliert oder ist unvollständig:
            ${toString (config.systemd.services.sabnzbd.serviceConfig.RestrictNetworkInterfaces or [ ])}

            ARCHITEKTUR-GRUND:
            Die Liste darf bei aktivem Confinement STRIKT nur ["lo" "${vpnIf}"] enthalten.
            Jedes zusätzliche Interface (wie eth0) öffnet ein potenzielles Leak-Fenster.

            BEHEBUNG:
            Entferne manuelle Überschreibungen von serviceConfig.RestrictNetworkInterfaces.
          '';
        }
        {
          assertion =
            !(svc.usenet-confinement.enable && vpnIf != "")
            || !(lib.elem "0.0.0.0/0" (config.systemd.services.sabnzbd.serviceConfig.IPAddressAllow or [ ]));
          message = ''
            [mediNix/541-sabnzbd] FEHLER: IPAddressAllow darf bei aktivem Usenet-Confinement
            kein Wildcard-Routing enthalten!
            Gefunden: "0.0.0.0/0" in serviceConfig.IPAddressAllow.

            ARCHITEKTUR-GRUND:
            Wildcard-Routing im IPAddressAllow-Filter hebelt die RestrictNetworkInterfaces-Isolation
            aus und ermöglicht unkontrollierten Traffic. Ohne Confinement ist WAN-Egress
            dagegen gewollt (Usenet) und networkPolicy.internet setzt das Wildcard bewusst.

            BEHEBUNG:
            Entferne "0.0.0.0/0" aus serviceConfig.IPAddressAllow (oder schalte
            medinix.usenet-confinement ab).
          '';
        }
      ];

      services.sabnzbd = {
        enable = true;
        user = "sabnzbd";
        group = "sabnzbd";
        # H30: the registry stateDir is canonical. nixpkgs derives BOTH
        # StateDirectory and configFile (/var/lib/<stateDir>/sabnzbd.ini) from
        # this option — so mediNix must not additionally set
        # serviceConfig.StateDirectory (that was the conflict).
        stateDir = "sabnzbd";
        openFirewall = false;
        configFile = null;
        allowConfigWrite = true;
        package = lib.mkIf (cfg.package != null) cfg.package;
        settings.misc = {
          inherit port;
          host = "127.0.0.1";
          language = svc.locale.language;
          download_dir = "${svc.storage.downloadDir}";
          temp_dir = tempDir;
          check_new_rel = 0;
        };
      };

      systemd.services.sabnzbd = {
        unitConfig = {
          RequiresMountsFor = [
            stateDir
            svc.storage.downloadDir
          ];
        };
        bindsTo = lib.optional (
          svc.usenet-confinement.enable && vpnIf != ""
        ) "sys-subsystem-net-devices-${vpnIf}.device";
        wants = [ "network-online.target" ];
        after = [
          "network-online.target"
        ]
        ++ lib.optional (
          svc.usenet-confinement.enable && vpnIf != ""
        ) "sys-subsystem-net-devices-${vpnIf}.device";
        wantedBy = [ "multi-user.target" ];
        onFailure = [ "alert-ntfy@%n.service" ];
        preStart = ''
          DOWNLOAD_PATH="${svc.storage.downloadDir}"
          ${pkgs.coreutils}/bin/mkdir -p "$DOWNLOAD_PATH"
          DEV=$(${pkgs.coreutils}/bin/df -P "$DOWNLOAD_PATH" | ${pkgs.gawk}/bin/awk 'NR>1 {print $1}')
          DISK=$(${pkgs.util-linux}/bin/lsblk -no PKNAME "$DEV" 2>/dev/null || ${pkgs.coreutils}/bin/basename "$DEV")

          if [ -f "/sys/block/$DISK/queue/rotational" ]; then
            ROTATIONAL=$(${pkgs.coreutils}/bin/cat "/sys/block/$DISK/queue/rotational")
            if [ "$ROTATIONAL" -eq "1" ]; then
              echo "[mediNix/541-sabnzbd] FATAL: Download-Verzeichnis '$DOWNLOAD_PATH' liegt auf einer HDD ($DISK)!" >&2
              echo "Usenet-Downloads und PAR2-Entpackvorgänge auf rotierenden Platten sind verboten (IOPS-Kollaps)." >&2
              exit 1
            fi
          fi
        '';
        serviceConfig = lib.mkMerge [
          profiles.python
          memoryPolicy.sabnzbd
          {
            User = "sabnzbd";
            UMask = "0002";
            TemporaryFileSystem = "${tempDir}:size=1G";
            RuntimeDirectory = "sabnzbd-tmp";
            InaccessiblePaths = [
              "-/run/systemd/resolve"
              "-/run/dbus/system_bus_socket"
              "-${creds.storeDir}"
            ];
            ReadWritePaths = [
              tempDir
              stateDir
              "${svc.storage.downloadDir}"
              "${svc.storage.mediaRoot}"
            ];
          }
          # Defense-in-Depth: cgroup-BPF-Socketfilter im Linux-Kernel
          (lib.mkIf (svc.usenet-confinement.enable && vpnIf != "") {
            RestrictNetworkInterfaces = [
              "lo"
              vpnIf
            ];
            # Wildcard-Routing aus profiles.python entfernen; RestrictNetworkInterfaces & nftables steuern den Pfad
            IPAddressDeny = lib.mkForce [ ];
            IPAddressAllow = lib.mkForce [ ];
          })
          (lib.mkIf (svc.secrets.usenetEnvFile or null != null) {
            EnvironmentFile = [ svc.secrets.usenetEnvFile ];
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
        environment = {
          SABNZBD__MISC__TEMP_DIR = tempDir;
        }
        // lib.optionalAttrs (cfg.serverCredentialFile != null) {
          SABNZBD__SERVER_0__CREDENTIAL_FILE = "/run/credentials/sabnzbd.service/mediNix-sabnzbd-server";
        };
      };

      medinix.persist.extraPaths = [ stateDir ];

      services.vpnKillSwitch.instances.sabnzbd = {
        enable = svc.usenet-confinement.enable;
        inherit uid;
      };
    })
  ];
}
