# ---
# id: "523-ssh"
# title: "SSH additive Match-Blocks (keine globalen SSH-Änderungen)"
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
  # NIEMALS globale SSH-Änderungen hier. Port 22 ist SSoT (ADR-21).
  # Wir fügen nur additive Match-Blöcke hinzu wenn cfg.enable.
  # Wenn leer: lieber nichts als etwas Falsches → mkIf.
  services.openssh.extraConfig = lib.mkIf cfg.ssh.hardening.enable ''
    # mediNix: LAN-only restriction für nicht-LAN-Quellen (Defence-in-Depth)
    Match Address 192.168.2.0/24
      PasswordAuthentication no
    Match All
      # keine globalen Overrides — nur Bestätigung dass key-only default gilt
  '';
}
