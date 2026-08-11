# ---
# id: "543-mover"
# title: "Smart Mover SSD(Tier B) -> HDD(Tier C), event-driven"
# domain: 50
# folder: 54-transfer
# status: active
# complexity: 3
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-30-storage
# provides: []
# requires: ["lib/abc-tiering"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: "systemd.services.mediNix-mover"
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# ---
# 54-transfer/543-mover.nix — Smart Mover (SSD to HDD)
{ lib, pkgs, config, ... }:

{
  # Event-driven mover: SSD (Tier B) -> HDD (Tier C) when full
  systemd.services.mediNix-mover = {
    description = "Smart Mover: SSD to HDD";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/bash -c 'echo Mover logic here'";
    };
  };

  # Timer: Check every hour (no cron!)
  systemd.timers.mediNix-mover = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}
