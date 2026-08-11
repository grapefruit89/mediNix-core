# ---
# id: "523-ssh"
# title: "SSH additive Match-Blocks (keine globalen SSH-Änderungen, portabel)"
# domain: 52
# folder: 52-security
# status: active
# complexity: 2
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-21
#   skill: nixos-context7-gate
# context7:
#   - query: "services.openssh.extraConfig Match block Address restrict LAN example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "services.openssh.settings.<key> freeform; extraConfig for Match blocks"
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
in
{
  # PORTABEL: kein SSH-Hardening im Modul. SSH-Hardening (LAN-Restriktion, key-only)
  # gehört in die Host-Config des Consumers, nicht in mediNix-core.
  # Wir lassen extraConfig leer — nur mkIf-Gate, damit künftige optionale
  # Match-Blöcke hier Landen KÖNNTEN, aber standardmäßig: nichts.
  # (Keine hardcoded IP/CIDR — bricht Portabilität.)
  services.openssh.extraConfig = lib.mkIf cfg.ssh.hardening.enable ''
    # Intentionally empty: SSH hardening is host responsibility, not module scope.
    # Add host-specific Match blocks in the consumer's configuration.nix.
  '';
}
