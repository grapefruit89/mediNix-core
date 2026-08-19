# ---
# id: "526-vpn-killswitch"
# title: "Dendritic Policy Routing Killswitch (KISS)"
# domain: 52
# folder: 52-security
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.services.vpnKillSwitch;
  activeInstances = lib.filterAttrs (n: v: v.enable) cfg.instances;
  uids = lib.mapAttrsToList (n: v: v.uid) activeInstances;
  uidList = lib.concatStringsSep ", " (map toString uids);
in
{
  options.services.vpnKillSwitch = {
    vpnInterface = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    routingTable = lib.mkOption {
      type = lib.types.int;
      default = ${toString cfg.routingTable};
      description = "The routing table and fwmark used for policy routing.";
    };
    dnsServers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "Enable VPN Confinement";
          uid = lib.mkOption { type = lib.types.int; };
        };
      });
      default = {};
    };
  };

  config = lib.mkIf (activeInstances != {}) {
    assertions = [
      {
        assertion = cfg.vpnInterface != "";
        message = "[vpnKillSwitch] vpnInterface must be defined when instances are active. Failing-Closed.";
      }
    ];
    # 1. NFTables Kill-Switch and Marking
    networking.nftables.enable = lib.mkDefault true;
    networking.nftables.tables.medinix_vpn = {
      family = "inet";
      content = ''
        chain mark {
          type route hook output priority mangle; policy accept;

          meta skuid != { ${uidList} } accept

          ip daddr { 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } accept
          ip6 daddr { ::1/128, fe80::/10, fc00::/7 } accept

          meta mark set ${toString cfg.routingTable}
        }

        chain killswitch {
          type filter hook output priority 0; policy accept;

          meta skuid != { ${uidList} } accept

          oifname "lo" accept
          ip daddr 127.0.0.0/8 accept
          ip6 daddr ::1/128 accept

          ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } accept
          ip6 daddr { fe80::/10, fc00::/7 } accept

          oifname "${cfg.vpnInterface}" accept

          meta skuid { ${uidList} } drop
        }
      '';
    };

    # 2. Policy Routing (Fail-Closed, No ExecStop)
    systemd.services."medinix-vpn-route" = {
      description = "mediNix VPN Policy Routing";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      before = map (n: "${n}.service") (lib.attrNames activeInstances);
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "medinix-vpn-route-start" ''
          ${pkgs.iproute2}/bin/ip rule add fwmark ${toString cfg.routingTable} table ${toString cfg.routingTable} priority 1000 2>/dev/null || true
          ${pkgs.iproute2}/bin/ip route replace unreachable default table ${toString cfg.routingTable} metric 100
          ${pkgs.iproute2}/bin/ip route replace default dev ${cfg.vpnInterface} table ${toString cfg.routingTable} metric 10

          ${pkgs.iproute2}/bin/ip -6 rule add fwmark ${toString cfg.routingTable} table ${toString cfg.routingTable} priority 1000 2>/dev/null || true
          ${pkgs.iproute2}/bin/ip -6 route replace unreachable default table ${toString cfg.routingTable} metric 100
          ${pkgs.iproute2}/bin/ip -6 route replace default dev ${cfg.vpnInterface} table ${toString cfg.routingTable} metric 10 2>/dev/null || true
        '';
      };
    };

    # 3. DNS Isolation File
    environment.etc."medinix-killswitch-resolv.conf".text = lib.concatMapStrings (
      dns: "nameserver ${dns}
"
    ) cfg.dnsServers;

    # 4. Inject strict isolation into systemd services
    systemd.services = lib.mapAttrs (name: v: {
      serviceConfig = {
        BindReadOnlyPaths = [ "/etc/medinix-killswitch-resolv.conf:/etc/resolv.conf" ];
      };
    }) activeInstances;
  };
}
