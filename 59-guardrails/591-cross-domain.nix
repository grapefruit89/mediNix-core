{ config, lib, ... }:

let
  cfg = config.medinix;
  svcReg = import ../lib/registry.nix { inherit lib; };
in lib.mkIf cfg.enable {
  assertions = [
    {
      assertion = cfg.security.usenet-confinement.enable -> 
        (config.services.vpnKillSwitch.instances ? sabnzbd && config.services.vpnKillSwitch.instances.sabnzbd.enable);
      message = ''
        [mediNix] security.usenet-confinement.enable is true, but SABnzbd is not registered in the vpnKillSwitch instances!
        
        [AI/Admin Context]
        Reason: usenet-confinement is a high-level abstraction that must map down to an active VPN killswitch instance for SABnzbd. If it doesn't, the service might run unconfined on the WAN interface, causing IP leaks.
        Ref: ADR-5260 (VPN Killswitch & Usenet Confinement)
        Fix: Check the wiring between `525-usenet-confinement.nix` and `vpnKillSwitch.instances`.
      '';
    }
    {
      assertion = (cfg.security.usenet-confinement.enable && cfg.prowlarr.enable) -> 
        (config.services.vpnKillSwitch.instances ? prowlarr && config.services.vpnKillSwitch.instances.prowlarr.enable);
      message = ''
        [mediNix] Usenet confinement and Prowlarr are both enabled, but Prowlarr is not in the killswitch!
        
        [AI/Admin Context]
        Reason: Prowlarr and SABnzbd interact closely. If SABnzbd is confined but Prowlarr is not, Prowlarr's indexer API calls will leak the true IP, compromising the privacy goal of the usenet-confinement feature.
        Ref: ADR-5260 (Cross-module IP Leak Prevention)
        Fix: Add Prowlarr to `vpnKillSwitch.instances`.
      '';
    }
  ];
}
