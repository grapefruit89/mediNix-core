# ---
# id: "594-transfer-guardrails"
# title: "Transfer & VPN Guardrails"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-18
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
    # Transfer-spezifische Checks (usenet-confinement ↔ VPN)
    # VPN-001: interface muss gesetzt sein wenn confinement aktiv
    # Gilt sowohl für useExistingInterface=true (manuell) als auch
    # für vpn.enable=true (wird via 526-vpn-interface automatisch gesetzt).
    (reg.mkErrorDoc "VPN-001" (cfg.usenet-confinement.enable -> cfg.vpn.interface != "") "5410")
    (reg.mkErrorDoc "VPN-002" (cfg.usenet-confinement.enable -> cfg.vpn.dnsServers != []) "5410")
    (reg.mkErrorDoc "VPN-003" (cfg.usenet-confinement.enable -> (cfg.sabnzbd.enable || cfg.prowlarr.enable)) "5410")
    # VPN-005 entfernt: cfg.vpn.wgConf existiert nicht (VPN via interface, kein wgConf-Pfad)
    # VPN-006 migriert nach 597-vpn-assertions.nix (gehört zum VPN-Modul, nicht zu Transfer)

    # INV-VPN-02: vpn.dns ist jetzt eine gültige Option (flake-managed VPN).
    # Diese Invariante ist obsolet — Option existiert seit 526-vpn-interface.
    # (entfernt, bleibt als Kommentar zur Dokumentation)

    # INV-VPN-04: dnsServers Einträge müssen syntaktisch IPs sein
    (reg.mkInvariant "INV-VPN-04"
      (let
        isIpv4 = s: builtins.match "[0-9]+(\\.[0-9]+){3}" s != null;
        isIpv6 = s: (lib.hasInfix ":" s) && (builtins.match "[0-9a-fA-F:]+" s != null);
       in lib.all (s: isIpv4 s || isIpv6 s) cfg.vpn.dnsServers))
  ];
}
