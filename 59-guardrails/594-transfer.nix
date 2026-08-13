{ config, lib, ... }:
let
  cfg  = config.grapefruitMedia;
  reg  = import ./590-registry.nix { inherit lib; };
in {
  config = lib.mkIf (cfg.enable && cfg.usenet-confinement.enable) {
    assertions = [
      (reg.mkErrorDoc "VPN-001" (cfg.vpn.interface != "") "5410")
      (reg.mkErrorDoc "VPN-002" (cfg.vpn.dnsServers != []) "5410")
      (reg.mkErrorDoc "VPN-003" (cfg.sabnzbd.enable || cfg.prowlarr.enable) "5410")
      (reg.mkErrorDoc "VPN-005" (!(cfg.vpn.wgConf != null && lib.hasPrefix "/nix/store/" cfg.vpn.wgConf)) "5410")
    ];
  };
}
