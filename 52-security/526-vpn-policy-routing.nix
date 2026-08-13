# ---
# id: "526-vpn-policy-routing"
# title: "UID-based VPN Policy Routing (no netns) — deklarativ, parameterized by vpn.interface"
# domain: 52
# folder: 52-security
# status: active
# complexity: 4
# last_reviewed: 2026-08-13
# links:
#   adr: ADR-5410 (usenet-confinement), ADR-0000 (registry UIDs)
#   skill: nixos-context7-gate
#   ref: "Nix-Grok modules/10-network/1096-vpn.nix (UID-routing statt netns)"
# context7:
#   - query: "networking.routingPolicyRules uidRange lookup table"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "networking.routingPolicyRules.<name> = { uidRange; table; priority; }"
# ---
# UID-basiertes Policy-Routing für Usenet-Stack (SABnzbd 5410 + Prowlarr 5360).
# KEIN netns. Das Modul deklariert die Routing-Tabellen + ip rules selbst — der Host
# muss KEIN ip rule-Kochrezept pflegen. Voraussetzung: cfg.vpn.interface existiert
# (WireGuard-Interface vom Host bereitgestellt). Fail-closed: Tabelle ohne brauchbare
# Route → unreachable für die UIDs (kein Fallback auf Host-Default-Route).
#
# Wichtig: Modul erfindet KEIN networking.interfaces und kein systemd.network Routing.
# Nur routingPolicyRules + iproute2.tables (konsumieren vpn.interface als Parameter).
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
  vpnIf = cfg.vpn.interface;

  # Betroffene UIDs aus Registry (SABnzbd=5410, Prowlarr=5360)
  confinedUids = lib.mapAttrsToList
    (_: s: s.uid)
    (lib.filterAttrs (n: s: lib.elem n [ "sabnzbd" "prowlarr" ]) (import ../lib/registry.nix { inherit lib; }).services);
in
lib.mkIf (cfg.usenet-confinement.enable && vpnIf != "") {
  # Tabellennamen registrieren (nummer = UID, siehe ADR-0000 Isomorphie)
  networking.iproute2.tables = lib.listToAttrs (
    map (uid: lib.nameValuePair "vpn-${toString uid}" uid) confinedUids
  );

  # Policy Rules: UID → eigene Tabelle (lookup)
  networking.routingPolicyRules = lib.listToAttrs (
    map (uid: lib.nameValuePair "vpn-${toString uid}" {
      uidRange = "${toString uid}-${toString uid}";
      table    = "vpn-${toString uid}";
      priority = uid;  # eindeutige Priorität = UID
    }) confinedUids
  );

  # In jeder Tabelle: Default-Route durch VPN-Interface + fail-closed unreachable
  networking.routes = lib.flatten (
    map (uid: [
      {
        target     = "default";
        table      = "vpn-${toString uid}";
        via        = null;          # via nicht gesetzt → dev wird genutzt
        options    = [ "dev" vpnIf ];
      }
      {
        target     = "default";
        table      = "vpn-${toString uid}";
        via        = null;
        options    = [ "unreachable" ];  # fail-closed: kein VPN → keine Route
        metric     = 65535;
      }
    ]) confinedUids
  );
}
