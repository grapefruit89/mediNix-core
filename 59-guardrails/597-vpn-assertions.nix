# ---
# id: "597-vpn-assertions"
# title: "VPN Interface Guardrails (59-guardrails)"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-18
# links:
#   adr: ADR-5260
# ---
# Absicherung der flake-managed WireGuard-Options (526-vpn-interface.nix).
# Greift nur wenn vpn.enable = true.
#
# Hinweis: VPN-001/002/003 (usenet-confinement ↔ interface/dnsServers) bleiben
# in 594-transfer-guardrails.nix, da sie vom usenet-confinement abhängen.
# VPN-006 (DNS-Allowlist) ist hier weil es zum VPN-Modul gehört.
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
  reg = import ./590-registry.nix { inherit lib; };
  vpn = cfg.vpn;
in
lib.mkIf (cfg.enable && vpn.enable) {
  assertions = [
    # STG-002: publicKey muss gesetzt sein (kein leerer Peer)
    (reg.mkError "STG-002" (vpn.peer.publicKey != ""))

    # STG-003: address darf nicht leer sein
    (reg.mkError "STG-003" (vpn.address != []))

    # STG-004: Credential-Pfad muss gesetzt sein (kein Interface ohne Key)
    (reg.mkError "STG-004"
      (vpn.useExistingInterface || vpn.privateKeyCredentialPath != null))

    # STG-005: useExistingInterface = true → interface muss manuell gesetzt sein
    (reg.mkError "STG-005"
      (!vpn.useExistingInterface || vpn.interface != ""))

    # VPN-006 (DNS-Allowlist): nur lokale/VPN-interne Resolver erlaubt
    # Gilt für vpn.dns (neue Option) WENN vpn.enable && !useExistingInterface
    (reg.mkError "VPN-006"
      (vpn.useExistingInterface ||
       lib.all (s:
         lib.hasPrefix "10." s
         || lib.hasPrefix "127." s
         || lib.hasPrefix "fd" s
         || lib.hasPrefix "192.168." s
       ) vpn.dns))
  ];
}
