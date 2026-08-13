# ---
# id: "594-transfer-guardrails"
# title: "Transfer & VPN Guardrails"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-13
# links:
#   adr: ADR-5043
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
  reg = import ./590-registry.nix { inherit lib; };
in
lib.mkIf cfg.enable {
  assertions = [
    # Transfer-spezifische Checks
    (reg.mkErrorDoc "VPN-001" (cfg.usenet-confinement.enable -> cfg.vpn.interface != "") "5410")
    (reg.mkErrorDoc "VPN-003" (cfg.usenet-confinement.enable -> (cfg.sabnzbd.enable || cfg.prowlarr.enable)) "5410")

    # INV-VPN-02: vpn.dns darf nicht existieren
    (reg.mkInvariant "INV-VPN-02" (!(cfg.vpn ? dns)))

    # INV-VPN-04: dnsServers Einträge müssen syntaktisch IPs sein
    (reg.mkInvariant "INV-VPN-04"
      (let
        isIpv4 = s: builtins.match "[0-9]+(\\.[0-9]+){3}" s != null;
        isIpv6 = s: (lib.hasInfix ":" s) && (builtins.match "[0-9a-fA-F:]+" s != null);
       in lib.all (s: isIpv4 s || isIpv6 s) cfg.vpn.dnsServers))

    # VPN-006: POLICY DNS Allowlist (nur lokale oder VPN-interne Resolver)
    (reg.mkError "VPN-006"
      (lib.all (s: lib.hasPrefix "10." s || lib.hasPrefix "127." s || lib.hasPrefix "fd" s) cfg.vpn.dnsServers))
  ];
}
