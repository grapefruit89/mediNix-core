# ---
# id: "522-service-slimming"
# title: "Service Slimming (disable bloat systemd units)"
# domain: 50
# folder: 52-security
# status: active
# complexity: 2
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-0000
# provides: []
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# 52-security/522-service-slimming.nix — Service Slimming (Gold Standard)
{ lib, pkgs, config, ... }:

{
  # Disable unnecessary systemd services (Gold Standard from mynixos-v5)
  systemd.services = {
    accounts-daemon.enable = false;
    ModemManager.enable = false;
    udisks2.enable = false;
    upower.enable = false;
    cups.enable = false;
    bluetooth.enable = false;
    wpa_supplicant.enable = false;
  };

  # Mask unnecessary units
  systemd.maskedUnits = [
    "plymouth-quit-wait.service"
    "systemd-networkd-wait-online.service"
  ];

  # Disable coredumps
  systemd.coredump.enable = false;
}
