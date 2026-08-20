# ---
# id: "590-guardrails"
# title: "Central Guardrails & Assertions"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 3
# last_reviewed: 2026-08-18
# links:
#   adr: ADR-5043
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
  reg = import ./599-assertion-registry.nix { inherit lib; };
  servicesReg = import ../lib/registry.nix { inherit lib; };
  vpn = cfg.vpn;
  st = cfg.storage;
  hasCold = st.backends ? cold;
  hasHot  = st.backends ? hot;
in
lib.mkIf cfg.enable {
  assertions = [

    # INV-PUBLIC-TLS-AUTH: Public VHosts must have TLS and Auth
    (reg.mkInvariant "INV-PUBLIC-TLS-AUTH"
      (let
        publicVhosts = lib.filterAttrs (_: v: v.accessGroup == "public") (cfg.ingress.vhosts or {});
      in
        publicVhosts == {} ||
        (cfg.ingress.tls.mode != "off" &&
         (cfg.ingress.auth.mode != "off" || cfg.ingress.allowPublicUnauth == true))
      ))

    # ---------------------------------------------------------
    # CORE GUARDRAILS
    # ---------------------------------------------------------
    (reg.mkInvariant "INV-01-PORT-FORMAT"
      (lib.all (svc: svc.port == null || svc.port == svc.num * 10) (lib.attrValues servicesReg.services)))

    (reg.mkInvariant "INV-01-PORT-UNIQUE"
      (let 
        ports = lib.filter (p: p != null) (map (s: s.port) (lib.attrValues servicesReg.services));
        sorted = lib.sort builtins.lessThan ports;
       in lib.length sorted == lib.length (lib.unique sorted)))

    (reg.mkInvariant "INV-01-UID-UNIQUE"
      (let 
        uids = lib.filter (p: p != null) (map (s: s.uid or null) (lib.attrValues servicesReg.services));
        sorted = lib.sort builtins.lessThan uids;
       in lib.length sorted == lib.length (lib.unique sorted)))

    (reg.mkInvariant "INV-03"
      (let servicesWithGid = lib.filterAttrs (_: svc: svc.gid != null) servicesReg.services;
       in lib.all (svc: svc.gid == 5000) (lib.attrValues servicesWithGid)))

    (reg.mkInvariant "INV-UMASK-01"
      (let dotnetServices = lib.filterAttrs (_: svc: svc.hardeningProfile == "dotnet" || svc.hardeningProfile == "dotnet-gpu") servicesReg.services;
       in lib.all (svc:
         let 
           unitName = "${svc.unitName}.service";
           isEnabled = cfg.${svc.name}.enable or false;
         in 
           !isEnabled ||
           (config.systemd.services ? ${svc.unitName} &&
            config.systemd.services.${svc.unitName}.serviceConfig.UMask or "" == "0002")
       ) (lib.attrValues dotnetServices)))

    # ---------------------------------------------------------
    # INGRESS & DNS GUARDRAILS
    # ---------------------------------------------------------
    (reg.mkErrorDoc "TLS-001" (!(cfg.ingress.tls.acmeHost != null && cfg.ingress.tls.certFile != null)) "5111")
    (reg.mkErrorDoc "TLS-002" (cfg.ingress.tls.mode != "custom" || (cfg.ingress.tls.certFile != null && cfg.ingress.tls.keyFile != null)) "5111")
    (reg.mkErrorDoc "TLS-003" (!(cfg.jellyfin.enable && cfg.ingress.tls.mode == "off")) "5111")
    
    (reg.mkErrorDoc "ACME-001"
      (cfg.ingress.tls.acmeHost != null ->
        (   cfg.ingress.tls.acmeCredential            != null
         || cfg.dns.ddns.cloudflareTokenCredential    != null
         || cfg.dns.ddns.tokenCredential              != null
         || cfg.dns.ddns.tokenFile                    != null))
      "5140")

    (reg.mkErrorDoc "AUTH-001" (!(cfg.ingress.auth.mode == "forward-auth" && !cfg.authProxyPresent)) "5120")

    (reg.mkErrorDoc "DNS-001"
      (cfg.dns.ddns.enable ->
        (   cfg.dns.ddns.cloudflareTokenCredential != null
         || cfg.dns.ddns.tokenCredential           != null
         || cfg.dns.ddns.tokenFile                 != null))
      "5130")

    (reg.mkInvariant "INV-DNS-01"
      (!config.services.resolved.enable || config.services.resolved.dnsovertls == "true"))

    # ---------------------------------------------------------
    # SECURITY GUARDRAILS
    # ---------------------------------------------------------
    (reg.mkInvariant "INV-SECRET"
      (let paths = [
        (cfg.dns.ddns.cloudflareTokenCredential or (cfg.dns.cloudflareTokenCredential or null))
        (cfg.sabnzbd.serverCredentialFile or null)
        (cfg.jellyfin.adminPasswordCredential or null)
        (cfg.secrets.sonarrApiKeyFile or null)
        (cfg.secrets.radarrApiKeyFile or null)
        (cfg.secrets.prowlarrApiKeyFile or null)
        (cfg.secrets.lidarrApiKeyFile or null)
        (cfg.secrets.readarrApiKeyFile or null)
        (cfg.secrets.jellyseerrApiKeyFile or null)
        (cfg.secrets.sabnzbdApiKeyFile or null)
        (cfg.secrets.navidromeOidcFile or null)
        (cfg.secrets.jellyseerrEnvFile or null)
      ];
      in lib.all (p: p == null || !(lib.hasPrefix "/nix/store/" p)) paths))

    (reg.mkInvariant "INV-TECH-01" (!config.virtualisation.docker.enable))
    (reg.mkInvariant "INV-TECH-02" (!config.virtualisation.podman.enable))
    (reg.mkInvariant "INV-TECH-03" (!config.services.cron.enable))
    (reg.mkInvariant "INV-FW-01" (config.networking.nftables.enable))

    # ---------------------------------------------------------
    # TRANSFER & VPN GUARDRAILS
    # ---------------------------------------------------------
    (reg.mkErrorDoc "VPN-001" (cfg.usenet-confinement.enable -> cfg.vpn.interface != "") "5410")
    (reg.mkErrorDoc "VPN-002" (cfg.usenet-confinement.enable -> cfg.vpn.dnsServers != []) "5410")
    (reg.mkErrorDoc "VPN-003" (cfg.usenet-confinement.enable -> (cfg.sabnzbd.enable || cfg.prowlarr.enable)) "5410")

    (reg.mkInvariant "INV-VPN-04"
      (let
        isIpv4 = s: builtins.match "[0-9]+(\\.[0-9]+){3}" s != null;
        isIpv6 = s: (lib.hasInfix ":" s) && (builtins.match "[0-9a-fA-F:]+" s != null);
       in lib.all (s: isIpv4 s || isIpv6 s) cfg.vpn.dnsServers))

    # VPN Assertions (if VPN enabled)
  ] ++ lib.optionals (vpn.enable) [
    (reg.mkError "STG-002" (vpn.peer.publicKey != ""))
    (reg.mkError "STG-003" (vpn.address != []))
    (reg.mkError "STG-004" (vpn.useExistingInterface || vpn.privateKeyCredentialPath != null))
    (reg.mkError "STG-005" (!vpn.useExistingInterface || vpn.interface != ""))
    (reg.mkError "VPN-006"
      (vpn.useExistingInterface ||
       lib.all (s:
         lib.hasPrefix "10." s || lib.hasPrefix "127." s || lib.hasPrefix "fd" s || lib.hasPrefix "192.168." s
       ) vpn.dns))
  ] ++ [
    # ---------------------------------------------------------
    # PLAYBACK GUARDRAILS
    # ---------------------------------------------------------
    (reg.mkInvariant "INV-02"
      (!cfg.jellyfin.enable ||
       (config.systemd.services ? "jellyfin-5510" &&
        config.systemd.services."jellyfin-5510".environment.JELLYFIN_NetworkConfiguration__LocalNetworkAddresses or "" == "127.0.0.1")))

    (reg.mkInvariant "INV-06" (!cfg.jellyfin.enable || cfg.ingress.tls.mode != "off"))

    (reg.mkInvariant "INV-07"
      (!cfg.jellyfin.enable ||
       (config.systemd.services ? "jellyfin-5510" &&
        !(config.systemd.services."jellyfin-5510".serviceConfig.PrivateDevices or false))))

    # ---------------------------------------------------------
    # STORAGE GUARDRAILS
    # ---------------------------------------------------------
    (reg.mkError "STG-001" (!(hasCold && !hasHot)))
    (reg.mkInvariant "INV-STG-01" (lib.all (p: !(lib.hasPrefix "/nix/store/" p)) (lib.attrValues st.backends)))
    (reg.mkInvariant "INV-STG-02" (!(lib.hasPrefix "/nix/store/" (toString st.mediaRoot))))

    # ---------------------------------------------------------
    # MAINTENANCE & OBSERVABILITY GUARDRAILS
    # ---------------------------------------------------------
    (reg.mkErrorDoc "STORE-003" (!(lib.hasPrefix "/nix/store" (cfg.maintenance.backup.repository or ""))) "5720")
    (reg.mkErrorDoc "SEC-001" (!(cfg.observability.crowdsec.enable && cfg.observability.crowdsec.enrollKeyFile == null)) "5820")
  ];
}
