{ config, lib, ... }:
let
  cfg  = config.grapefruitMedia;
  reg  = import ./590-registry.nix { inherit lib; };
in {
  config = lib.mkIf cfg.security.enable {
    # Invarianten = Systemgarantien über alle Domains hinweg.
    # Diese gelten unabhängig von Konfiguration — Architektur-Level.
    assertions = [
      (reg.mkInvariant "INV-01" true)  # Dezimalrahmen via registry.nix (SSoT)
      (reg.mkInvariant "INV-02" true)  # 127.0.0.1 Bindings durch Ingress/Caddy
      (reg.mkInvariant "INV-03" true)  # GID 5000 = media (registry.nix)
      (reg.mkInvariant "INV-04" (!cfg.usenet-confinement.enable || (cfg.vpn.interface != "" && cfg.vpn.dnsServers != [])))
      (reg.mkInvariant "INV-05" (!(cfg.vpn.wgConf != null && lib.hasPrefix "/nix/store/" (cfg.vpn.wgConf or ""))))
      (reg.mkInvariant "INV-06" (!cfg.services.jellyfin.enable || cfg.ingress.tls.mode != "off"))
      (reg.mkInvariant "INV-07" (!cfg.services.jellyfin.enable || !(config.systemd.services.jellyfin.serviceConfig.PrivateDevices or false)))
    ];
  };
}
