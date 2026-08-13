# ---
# meta:
#   id: 596
#   type: guardrail
#   name: dns-assertions
#   description: Ensures DNS-over-TLS (DoT) is enabled to prevent DNS leaks and guarantees firewall presence.
# ---
{ config, lib, ... }:

{
  config = lib.mkIf (config.services.resolved.enable) {
    assertions = [
      {
        assertion = config.services.resolved.dnsovertls == "true" || config.services.resolved.dnsovertls == "opportunistic";
        message = "[POL-DNS-001] Verschlüsseltes DNS (DoT) ist nicht aktiv! DNS-Leaks möglich.";
      }
      {
        assertion = config.networking.nftables.enable;
        message = "[POL-FW-001] NFTables Firewall muss aktiv sein (für VPN UID Kill-Switch)!";
      }
    ];
  };
}
