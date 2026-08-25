# ---
# id: "515-mdns"
# title: "Avahi mDNS: {service}.local -> LAN-IP (Robust Alive-Check)"
# domain: 51
# folder: 51-ingress
# status: active
# complexity: 3
# last_reviewed: 2026-08-19
# links: 
# provides: []
# requires: ["lib/registry"]
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
  
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  # Only services that are actually enabled
  enabledNames = lib.attrNames (lib.filterAttrs (n: vhost:
    let
      enabled = cfg.${n}.enable or cfg.${lib.toCamelCase n}.enable or false;
    in enabled && (registry.${n}.port or null) != null
  ) cfg.ingress.vhosts);

  aliasScript = pkgs.writeShellScript "medinix-mdns-aliases" ''
    set -euo pipefail

    get_lan_ip() {
      ip=$(${pkgs.iproute2}/bin/ip -4 route get 1.1.1.1 2>/dev/null \
        | ${pkgs.gawk}/bin/awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }' \
        || true)
      if [ -z "''${ip:-}" ]; then
        ip=$(${pkgs.iproute2}/bin/ip -4 -o addr show scope global \
          | ${pkgs.gawk}/bin/awk '{ split($4, a, "/"); print a[1]; exit }' \
          || true)
      fi
      printf '%s' "''${ip:-}"
    }

    IP=""
    for _try in 1 2 3 4 5 6 7 8 9 10; do
      IP=$(get_lan_ip)
      if [ -n "$IP" ]; then
        break
      fi
      sleep 1
    done

    if [ -z "$IP" ]; then
      echo "medinix-mdns: no LAN IPv4 after retries -- skip publish" >&2
      exit 1
    fi

    echo "medinix-mdns: publishing aliases -> $IP"

    pids=""
    ${lib.concatMapStrings (name: ''
      ${pkgs.avahi}/bin/avahi-publish -a -R ${name}.local "$IP" &
      pids="$pids $!"
    '') enabledNames}

    cleanup() {
      for p in $pids; do
        kill "$p" 2>/dev/null || true
      done
    }
    trap cleanup EXIT INT TERM

    sleep 2
    alive=0
    for p in $pids; do
      if kill -0 "$p" 2>/dev/null; then
        alive=$((alive + 1))
      fi
    done

    if [ "$alive" -eq 0 ]; then
      echo "medinix-mdns: kein einziger Alias konnte publiziert werden." >&2
      echo "  Haeufigste Ursache: services.avahi.publish.userServices = false." >&2
      exit 1
    fi

    echo "medinix-mdns: $alive Alias(e) aktiv"
    wait
  '';
in
lib.mkIf (cfg.enable && cfg.ingress.enable && cfg.discovery.mdns.enable && enabledNames != [ ]) {
  services.avahi = {
    enable = true;
    nssmdns4 = lib.mkDefault true;
    publish = {
      enable = true;
      addresses = true;
      userServices = true;
    };
  };

  systemd.services.medinix-mdns-aliases = {
    description = "medinix mDNS aliases ({service}.local -> LAN-IP)";
    after = [ "avahi-daemon.service" "network-online.target" ];
    wants = [ "avahi-daemon.service" "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      Type = "simple";
      ExecStart = "${aliasScript}";
      Restart = "on-failure";
      RestartSec = "5s";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
    };
  };

  systemd.services.medinix-mdns-aliases-restart = {
    description = "Restart media mDNS aliases after network change";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl restart medinix-mdns-aliases.service";
    };
  };

  systemd.paths.medinix-mdns-aliases-refresh = {
    description = "Watch network leases for media mDNS re-publish";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "/run/systemd/netif/leases";
      Unit = "medinix-mdns-aliases-restart.service";
      MakeDirectory = false;
    };
  };
}
