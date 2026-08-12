{ config, lib, ... }:
let
  cfg  = config.grapefruitMedia;
  reg  = import ./590-registry.nix { inherit lib; };
in {
  config = lib.mkIf cfg.enable {
    assertions = [
      (reg.mkErrorDoc "TLS-001" !(cfg.ingress.tls.acmeHost != null && cfg.ingress.tls.certFile != null) "5111")
      (reg.mkErrorDoc "TLS-002" (cfg.ingress.tls.mode != "custom" || (cfg.ingress.tls.certFile != null && cfg.ingress.tls.keyFile != null)) "5111")
      (reg.mkErrorDoc "TLS-003" !(cfg.jellyfin.enable && cfg.ingress.tls.mode == "off") "5111")
      (reg.mkErrorDoc "AUTH-001" !(cfg.ingress.auth.mode == "forward-auth" && !cfg.authProxyPresent) "5120")
    ];
  };
}
