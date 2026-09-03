# ---
# id: "583-runtime-guard"
# title: "Runtime-Guard - hourly check of the running machine (nftables/0.0.0.0/VPN)"
# domain: 58
# folder: 58-observability
# status: active
# complexity: 3
# last_reviewed: 2026-08-25
# links: 
# provides: []
# requires: ["lib/hardening-profiles", "lib/registry"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  # Get ntfy port from registry
  ntfyPort = (import ../lib/registry.nix { inherit lib; }).services.ntfy.port;
  ntfy = "http://127.0.0.1:${toString ntfyPort}/mediNix-runtime";

  registry = import ../lib/registry.nix { inherit lib; };
  portsList = lib.mapAttrsToList (_: svc: toString svc.port) (lib.filterAttrs (_: svc: svc.port != null) registry.services);
  portsRegex = lib.concatStringsSep "|" portsList;

  script = pkgs.writeShellApplication {
    name = "mediNix-runtime-guard";
    runtimeInputs = [ pkgs.iproute2 pkgs.nftables pkgs.curl pkgs.procps pkgs.jq ];
    text = ''
      set -euo pipefail
      NTFY="${ntfy}"

      alert() {
        local msg="$1"
        if ! curl --fail --silent --show-error -d "$msg" "$NTFY"; then
          echo "CRITICAL: notification failed: $msg" >&2
        fi
      }

      # 1. Check actual mediNix VPN security object.
      if ! nft list table inet medinix_vpn_filter >/dev/null 2>&1; then
        alert "CRITICAL: medinix_vpn_filter nftables table missing"
        exit 1
      fi
      if ! nft list chain inet medinix_vpn_filter killswitch >/dev/null 2>&1; then
        alert "CRITICAL: VPN killswitch chain missing"
        exit 1
      fi
      if ! nft list chain inet medinix_vpn killswitch >/dev/null 2>&1; then
        alert "CRITICAL: VPN killswitch chain missing"
        exit 1
      fi

      # 2. Socket inspection must fail closed.
      if ! LISTENERS="$(ss -H -ltnp)"; then
        alert "CRITICAL: unable to inspect listening sockets"
        exit 1
      fi
      BAD="$(printf '%s
' "$LISTENERS" | grep -E '(\[::\]|:::|\*|0\.0\.0\.0):(${portsRegex})\b' || true)"
      if [ -n "$BAD" ]; then
        alert "CRITICAL: wildcard listener detected: $BAD"
      fi

      # 3. VPN interface.
      IFACE="${toString cfg.vpn.interface}"
      if [ -n "$IFACE" ]; then
        if ! ip link show "$IFACE" >/dev/null 2>&1; then
          alert "CRITICAL: VPN interface down"
        fi
      fi

      echo "Runtime-Guard OK"
    '';
  };
in
lib.mkIf (cfg.enable && cfg.observability.runtimeGuard) {
  systemd.timers.mediNix-runtime-guard = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      Unit = "mediNix-runtime-guard.service";
    };
  };

  systemd.services.mediNix-runtime-guard = {
    unitConfig = {
      StartLimitIntervalSec = "1h";
      StartLimitBurst = 2;
    };
    serviceConfig = profiles.script // { 
      Type = "oneshot";
      PrivateNetwork = false;
      # CAP_NET_ADMIN required for nft list (read-only queries need it too)
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
      AmbientCapabilities = [ "CAP_NET_ADMIN" ];
      
    };
    path = [ pkgs.iproute2 pkgs.nftables pkgs.curl pkgs.procps pkgs.jq ];
    script = "${lib.getExe script}";
  };
}
