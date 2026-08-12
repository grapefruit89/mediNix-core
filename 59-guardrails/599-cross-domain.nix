{ config, lib, ... }:

let
  cfg  = config.grapefruitMedia;
  reg  = import ./590-registry.nix { inherit lib; };
in {
  config = lib.mkIf cfg.enable {
    # Invarianten = Systemgarantien über alle Domains hinweg.
    # Diese gelten unabhängig von Konfiguration — Architektur-Level.
    assertions = [
      # INV-01: Port = ServiceNumber * 10 (Dezimalrahmen SSoT aus lib/registry.nix)
      (reg.mkInvariant "INV-01"
        (let registry = import ../lib/registry.nix { inherit lib; };
         in lib.all (svc: svc.port == null || svc.port == svc.num * 10)
              (lib.attrValues registry.services)))

      # INV-02: Binding — Jellyfin muss explizit auf 127.0.0.1 binden (nie 0.0.0.0)
      (reg.mkInvariant "INV-02"
        (!cfg.jellyfin.enable ||
         (config.systemd.services ? "jellyfin-5510" &&
          config.systemd.services."jellyfin-5510".environment ?
          "JELLYFIN_NetworkConfiguration__LocalNetworkAddresses")))

      # INV-03: GID 5000 = media für alle Core-Mediendienste in der Registry
      (reg.mkInvariant "INV-03"
        (let registry = import ../lib/registry.nix { inherit lib; };
         in lib.all (svc: svc.gid == 5000)
              (lib.attrValues registry.services)))

      # INV-04: usenet-confinement Konsistenz
      (reg.mkInvariant "INV-04" (!cfg.usenet-confinement.enable || (cfg.vpn.interface != "" && cfg.vpn.dnsServers != [])))

      # INV-05: Keine Secrets im Nix-Store
      (reg.mkInvariant "INV-05" (!(cfg.vpn.wgConf != null && lib.hasPrefix "/nix/store/" (cfg.vpn.wgConf or ""))))

      # INV-06: Kein WAN-Streaming ohne TLS
      (reg.mkInvariant "INV-06" (!cfg.jellyfin.enable || cfg.ingress.tls.mode != "off"))

      # INV-07: Jellyfin VA-API braucht PrivateDevices = false
      (reg.mkInvariant "INV-07" (!cfg.jellyfin.enable || !(config.systemd.services.jellyfin.serviceConfig.PrivateDevices or false)))

      # INV-VPN-02: vpn.dns (ohne Servers) darf nicht existieren — nur vpn.dnsServers
      (reg.mkInvariant "INV-VPN-02" (!(cfg.vpn ? dns)))

      # INV-UMASK-01: dotnet-Dienste müssen UMask=0002 haben
      (reg.mkInvariant "INV-UMASK-01"
        (let dotnetServices = [ "sonarr-5320" "radarr-5330" "readarr-5340"
                                "lidarr-5350" "prowlarr-5360" "jellyseerr-5610" "jellyfin-5510" ];
         in lib.all (svc:
           !(config.systemd.services ? ${svc}) ||
           config.systemd.services.${svc}.serviceConfig.UMask == "0002")
         dotnetServices))

      # INV-SECRET: Kein Secret-Pfad im Nix-Store
      (reg.mkInvariant "INV-SECRET"
        (let paths = [
          cfg.dns.cloudflareTokenCredential
          cfg.sabnzbd.serverCredentialFile
          cfg.jellyfin.adminPasswordCredential
          cfg.secrets.sonarrApiKeyFile
          cfg.secrets.radarrApiKeyFile
          cfg.secrets.prowlarrApiKeyFile
          cfg.secrets.lidarrApiKeyFile
          cfg.secrets.readarrApiKeyFile
          cfg.secrets.jellyseerrApiKeyFile
          cfg.secrets.sabnzbdApiKeyFile
          cfg.secrets.navidromeOidcFile
          cfg.secrets.jellyseerrEnvFile
        ];
        in lib.all (p: p == null || !(lib.hasPrefix "/nix/store/" p)) paths))
    ];
  };
}
