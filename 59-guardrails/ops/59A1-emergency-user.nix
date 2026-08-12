# ---
# id: "59A1-emergency-user"
# title: "Emergency-User — lokaler Break-Glass Account (59-guardrails/ops)"
# domain: 59
# folder: 59-guardrails/ops
# status: active
# complexity: 2
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5930 (Emergency Access)
#   skill: nixos-context7-gate
# ---
# Break-Glass Account für Wartungszugriff. Nie für den Alltag.
# UID außerhalb des Dezimal-Servicespektrums (9xxx) um Konflikte zu vermeiden.
{ config, lib, ... }:
let
  cfg = config.grapefruitMedia;
in lib.mkIf cfg.security.emergencyUser.enable {
  users.users.emergency = {
    uid = 9001;
    isSystemUser = true;
    group = "wheel";
    extraGroups = [ "media" "sudo" ];
    openssh.authorizedKeys.keys = cfg.emergencyUser.sshKeys;
    shell = lib.mkDefault "/run/current-system/sw/bin/bash";
  };
}
