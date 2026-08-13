{ config, lib, ... }:
let
  cfg  = config.grapefruitMedia;
  reg  = import ./590-registry.nix { inherit lib; };
in {
  config = lib.mkIf cfg.enable {
    assertions = [
      (reg.mkErrorDoc "SEC-001" !(cfg.observability.crowdsec.enable && cfg.observability.crowdsec.enrollKeyFile == null) "5820")
    ];
  };
}
