{ config, lib, ... }:
let
  cfg  = config.grapefruitMedia;
  reg  = import ./590-registry.nix { inherit lib; };
in {
  config = lib.mkIf cfg.enable {
    assertions = [
      (reg.mkErrorDoc "DNS-001" !(cfg.ingress.ddns.enable && cfg.ingress.ddns.token == null) "5130")
    ];
  };
}
