# context7:
#   - query: "networking.wg-quick.interfaces wireguard"
#     library: /websites/nixos_manual_nixos_unstable
# ---
# id: "526-vpn-killswitch"
# title: "Dendritic Policy Routing Killswitch (KISS)"
# domain: 52
# folder: 52-security
# status: active
# complexity: 5
# last_reviewed: 2026-08-20
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
# adr: ADR-5260
# ---

{ config, lib, pkgs, ... }:

let
  cfg = config.services.vpnKillSwitch;
  activeInstances = lib.filterAttrs (n: v: v.enable) cfg.instances;
  uids = lib.mapAttrsToList (n: v: v.uid) activeInstances;
  uidList = lib.concatStringsSep ", " (map toString uids);

  # Collect all allowed LAN CIDRs from active instances
  allowedLanCidrs = lib.unique (lib.flatten (lib.mapAttrsToList (n: v: v.allowedLanCidrs) activeInstances));
  lanCidrsStr = if allowedLanCidrs == [] then "" else builtins.concatStringsSep ", " allowedLanCidrs;

  mark = toString cfg.routingTable;
  table = toString cfg.routingTable;
  vpnIf = cfg.vpnInterface;
in
{
  options.services.vpnKillSwitch = {
    vpnInterface = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    routingTable = lib.mkOption {
      type = lib.types.int;
      default = 51820;
    };
    ipv6 = lib.mkEnableOption "IPv6 VPN Routing (Drop if false)";
    dnsServers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "Enable VPN Confinement";
          uid = lib.mkOption { type = lib.types.int; };
          allowedLanCidrs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Explicitly allowed LAN destinations for this service.";
          };
        };
      });
      default = {};
    };
  };

  config = lib.mkIf (activeInstances != {}) {
    assertions = [
      {
        assertion = cfg.dnsServers != [];
        message = "[vpnKillSwitch] dnsServers must not be empty. An empty resolv.conf causes DNS leaks via 127.0.0.1.";
      }
      {
        assertion = cfg.vpnInterface != "";
        message = "[vpnKillSwitch] vpnInterface must be defined when instances are active.";
      }
      {
        assertion = lib.all (n: lib.hasAttr n config.systemd.services) (lib.attrNames activeInstances);
        message = "vpnKillSwitch.instances.<name> must match an existing systemd service name.";
      }
    ];

    networking.nftables.tables.medinix_vpn_mark = {
      family = "inet";
      content = ''
        chain mark {
          type route hook output priority mangle; policy accept;
          ${lib.concatMapStringsSep "
" (name: ''
            meta skuid ${toString activeInstances.${name}.uid} jump mark_${name}
          '') (lib.attrNames activeInstances)}
        }
        ${lib.concatMapStringsSep "
" (name: ''
          chain mark_${name} {
            ip daddr 127.0.0.0/8 counter return
            ${lib.optionalString (activeInstances.${name}.allowedLanCidrs != []) ''
              ip daddr { ${lib.concatStringsSep ", " activeInstances.${name}.allowedLanCidrs} } accept
            ''}
            meta mark set ${mark}
          }
        '') (lib.attrNames activeInstances)}
      '';
    };

    networking.nftables.tables.medinix_vpn_filter = {
      family = "inet";
      content = ''
        chain killswitch {
          type filter hook output priority 0; policy accept;
          ${lib.concatMapStringsSep "
" (name: ''
            meta skuid ${toString activeInstances.${name}.uid} jump kill_${name}
          '') (lib.attrNames activeInstances)}
        }
        ${lib.concatMapStringsSep "
" (name: ''
          chain kill_${name} {
            oifname "lo" counter return
            ip daddr 127.0.0.0/8 counter return
            ip6 daddr ::1/128 counter return
            ${lib.optionalString (activeInstances.${name}.allowedLanCidrs != []) ''
              ip daddr { ${lib.concatStringsSep ", " activeInstances.${name}.allowedLanCidrs} } accept
            ''}
            meta mark ${mark} oifname "${vpnIf}" accept
            counter drop
          }
        '') (lib.attrNames activeInstances)}
      '';
    };

    systemd.services = {
      "medinix-vpn-route" = {
      description = "mediNix VPN Policy Routing";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      # P1-2: Hard dependency on wireguard interface
      requires = [ "wireguard-${vpnIf}.service" "nftables.service" ];
      after = [ "network-online.target" "wireguard-${vpnIf}.service" "nftables.service" ];
      before = map (n: "${n}.service") (lib.attrNames activeInstances);
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "medinix-vpn-route-start" ''
          set -euo pipefail

          hexmark="$(printf '0x%x' ${mark})"
          if ! ${pkgs.iproute2}/bin/ip rule show | grep -Eq "fwmark (${mark}|$hexmark) lookup ${table}"; then
            ${pkgs.iproute2}/bin/ip rule add fwmark ${mark} table ${table} priority 1000
          fi
          
          ${pkgs.iproute2}/bin/ip route replace unreachable default table ${table} metric 100
          src_ip=$(${pkgs.iproute2}/bin/ip -4 addr show dev ${vpnIf} | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
          if [ -n "$src_ip" ]; then
            ${pkgs.iproute2}/bin/ip route replace default dev ${vpnIf} table ${table} src $src_ip metric 10
          else
            ${pkgs.iproute2}/bin/ip route replace default dev ${vpnIf} table ${table} metric 10
          fi
          
          # Verify rule exists, otherwise fail-closed
          ${pkgs.iproute2}/bin/ip rule show | grep -Eq "fwmark (${mark}|$hexmark) lookup ${table}" || {
             echo "FATAL: IPv4 policy rule missing" >&2
             exit 1
          }

          ${if cfg.ipv6 then ''
          if ! ${pkgs.iproute2}/bin/ip -6 rule show | grep -Eq "fwmark (${mark}|$hexmark) lookup ${table}"; then
            ${pkgs.iproute2}/bin/ip -6 rule add fwmark ${mark} table ${table} priority 1000
          fi
          ${pkgs.iproute2}/bin/ip -6 route replace unreachable default table ${table} metric 100
          if ${pkgs.iproute2}/bin/ip -6 addr show dev ${vpnIf} | grep -q inet6; then
            ${pkgs.iproute2}/bin/ip -6 route replace default dev ${vpnIf} table ${table} metric 10
          fi
          ${pkgs.iproute2}/bin/ip -6 rule show | grep -Eq "fwmark (${mark}|$hexmark) lookup ${table}" || {
             echo "FATAL: IPv6 policy rule missing" >&2
             exit 1
          }
          '' else ""}
        '';
      };
    } // lib.mapAttrs (name: v: {
      requires = [ "medinix-vpn-route.service" ];
      after = [ "medinix-vpn-route.service" ];
      serviceConfig = {
        BindReadOnlyPaths = [ "/etc/medinix-killswitch-resolv.conf:/etc/resolv.conf" ];
      };
    }) activeInstances;

    environment.etc."medinix-killswitch-resolv.conf".text = lib.concatMapStrings (
      dns: "nameserver ${dns}\n"
    ) cfg.dnsServers;
  };
}
