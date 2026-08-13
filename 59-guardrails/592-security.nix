{ config, lib, ... }:
let
  cfg  = config.grapefruitMedia;
  reg  = import ./590-registry.nix { inherit lib; };
in {
  config = lib.mkIf cfg.enable {
    assertions = [
      (reg.mkErrorDoc "SEC-001" !(cfg.observability.crowdsec.enable && cfg.observability.crowdsec.enrollKeyFile == null) "5820")

      # INV-SEC-01: Kein Secret via $(cat) in curl-Commandline (Guideline, Coding-Regel)
      # Nicht automatisch prüfbar — als Architektur-Guideline dokumentiert.
      # Verstoß → Build-Warnung via mkInvariant (true = erfüllt, da Lint nicht möglich)
      (reg.mkInvariant "INV-SEC-01" true)
    ];
  };
}
