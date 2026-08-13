# ---
# id: "595-playback-guardrails"
# title: "Playback & Media Guardrails"
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
    # INV-02: Binding — Jellyfin muss explizit auf 127.0.0.1 binden (nie 0.0.0.0)
    (reg.mkInvariant "INV-02"
      (!cfg.jellyfin.enable ||
       (config.systemd.services ? "jellyfin-5510" &&
        config.systemd.services."jellyfin-5510".environment.JELLYFIN_NetworkConfiguration__LocalNetworkAddresses or "" == "127.0.0.1")))

    # INV-06: Jellyfin darf nicht ohne TLS Ingress laufen (Security-Policy)
    (reg.mkInvariant "INV-06" (!cfg.jellyfin.enable || cfg.ingress.tls.mode != "off"))

    # INV-07: Jellyfin VA-API braucht PrivateDevices = false
    (reg.mkInvariant "INV-07"
      (!cfg.jellyfin.enable ||
       (config.systemd.services ? "jellyfin-5510" &&
        !(config.systemd.services."jellyfin-5510".serviceConfig.PrivateDevices or false))))
  ];
}
