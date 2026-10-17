# ---
# id: "526-vpn-killswitch"
# title: "Dendritic Policy Routing Killswitch (KISS)"
# domain: 52
# folder: 52-security
# status: active
# complexity: 5
# last_reviewed: 2026-10-15
# provides: []
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-526
# links:
#   adr: ADR-526
# context7:
#   - query: "networking.wg-quick.interfaces wireguard"
#     library: /websites/nixos_manual_nixos_unstable
# ---
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.vpnKillSwitch;
  activeInstances = lib.filterAttrs (_n: v: v.enable) cfg.instances;

  mark = toString cfg.routingTable;
  table = toString cfg.routingTable;
  vpnIf = cfg.vpnInterface;

  # R15: identity chain. nftables matches `meta skuid <instance.uid>`, so the
  # instance uid, the registry uid and the uid of the user the unit actually
  # runs as must be the same number — otherwise the killswitch targets the
  # wrong process.
  registry = import ../lib/registry.nix { inherit lib; };
  instUidOf = n: activeInstances.${n}.uid;
  regUidOf = n: (registry.services.${n} or { }).uid or null;
  unitUserOf = n: ((config.systemd.services.${n} or { }).serviceConfig or { }).User or n;
  sysUidOf = n: (config.users.users.${unitUserOf n} or { }).uid or null;
  identityBroken = lib.filter (n: !(regUidOf n == instUidOf n && sysUidOf n == instUidOf n)) (
    lib.attrNames activeInstances
  );
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
      default = [ ];
    };
    instances = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "Enable VPN Confinement";
            uid = lib.mkOption { type = lib.types.int; };
            allowedLanCidrs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Explicitly allowed LAN destinations for this service.";
            };
          };
        }
      );
      default = { };
    };
  };

  config = lib.mkIf (activeInstances != { }) {
    assertions = [
      {
        assertion = cfg.dnsServers != [ ];
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
      {
        # R15: close registry → instance → systemd-user identity.
        assertion = identityBroken == [ ];
        message = ''
          [vpnKillSwitch] R15 identity chain broken. For every active instance
          registry.uid == instance.uid == users.<unit-user>.uid must hold.
          Offenders: ${lib.concatStringsSep ", " identityBroken}
        '';
      }
      {
        # R16: fail-closed IPv6. IPv6 on the host without an IPv6 killswitch is
        # an unfiltered escape from the confined uid.
        assertion = cfg.ipv6 || !(config.networking.enableIPv6 or false);
        message = ''
          [vpnKillSwitch] R16 fail-open IPv6: networking.enableIPv6 is on but
          services.vpnKillSwitch.ipv6 is false. Set ipv6 = true (or disable
          IPv6 on the host).
        '';
      }
      {
        assertion = !(lib.elem "medinix-vpn-route" (lib.attrNames activeInstances));
        message = ''
          [vpnKillSwitch] Instance name "medinix-vpn-route" collides with the
          route-setup service defined in this module. The left side of the `//`
          merge would be silently replaced by the instance entry. Rename the
          instance. Ref: ADR-526.
        '';
      }
      {
        assertion = config.networking.firewall.checkReversePath != true;
        message = "[mediNix/vpn] 'checkReversePath = true' (strict) verwirft asymmetrische Pakete im WireGuard-Routing! Zwingend 'loose' oder false erforderlich.";
      }
      {
        # A2: die Killswitch-Tabellen werden NUR geladen, wenn nftables aktiv
        # ist. Ohne enable sind sie deklariert, aber wirkungslos: kein fwmark →
        # die ip rule greift nicht → confined UIDs entkommen ueber die
        # Default-Route. Bewusst NICHT auf hostIntegration.nftables == "managed"
        # geprueft: ein external-Host mit eigener nftables-Aktivierung muss
        # durchgehen.
        assertion = config.networking.nftables.enable;
        message = ''
          [vpnKillSwitch] Active instances require networking.nftables.enable = true.
          Otherwise the killswitch tables are declared but never loaded and confined
          UIDs escape via the default route. Ref: ADR-526.
        '';
      }
    ];

    networking.firewall.checkReversePath = lib.mkDefault "loose";
    networking.firewall.logReversePathDrops = lib.mkDefault true;

    # A1 (Belt-and-Suspenders): nur die Tabellen sind gegated, NICHT das
    # Top-Level-mkIf — sonst wuerde bei nftables.enable = false der ganze
    # Killswitch (Services, Route-Unit, resolv.conf) mitabgeschaltet.
    networking.nftables.tables.medinix_vpn_mark = lib.mkIf config.networking.nftables.enable {
      family = "inet";
      content = ''
        chain vpn_mark {
          type route hook output priority mangle;
          ${lib.concatMapStringsSep "
" (name: ''
            meta skuid ${toString activeInstances.${name}.uid} jump mark_${name}
          '') (lib.attrNames activeInstances)}
        }
        ${lib.concatMapStringsSep "
" (name: ''
          chain mark_${name} {
            ip daddr 127.0.0.0/8 counter return
            ip6 daddr ::1/128 counter return
            ${lib.optionalString (activeInstances.${name}.allowedLanCidrs != [ ]) ''
              ip daddr { ${lib.concatStringsSep ", " activeInstances.${name}.allowedLanCidrs} } accept
            ''}
            meta mark set ${mark}
          }
        '') (lib.attrNames activeInstances)}
      '';
    };

    networking.nftables.tables.medinix_vpn_filter = lib.mkIf config.networking.nftables.enable {
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
            ${lib.optionalString (activeInstances.${name}.allowedLanCidrs != [ ]) ''
              ip daddr { ${lib.concatStringsSep ", " activeInstances.${name}.allowedLanCidrs} } accept
            ''}
            meta mark ${mark} oifname "${vpnIf}" accept
            counter drop
          }
        '') (lib.attrNames activeInstances)}
      '';
    };

    systemd.services =
      lib.recursiveUpdate
        {
          # IMPERATIV (bewusst): networking.iproute2 auf unstable bietet keine Option
          # fuer ip rule / ip route mit fwmark und unreachable default (nur
          # rttablesExtraConfig). Der Type=oneshot-Service ist der deklarative
          # Ersatz: Zustand wird bei jedem Boot neu hergestellt, ExecStart
          # verifiziert fail-closed via `ip rule show | grep`. Umbau auf
          # systemd-networkd ([RoutingPolicyRule]/[Route]) ist offen.
          "medinix-vpn-route" = {
            description = "mediNix VPN Policy Routing";
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            # P1-2: Hard dependency on wireguard interface
            requires = [
              "wireguard-${vpnIf}.service"
              "nftables.service"
            ];
            after = [
              "network-online.target"
              "wireguard-${vpnIf}.service"
              "nftables.service"
            ];
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

                ${
                  if cfg.ipv6 then
                    ''
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
                    ''
                  else
                    ""
                }
              '';
            };
          };
        }
        (
          lib.mapAttrs (_name: _v: {
            requires = [ "medinix-vpn-route.service" ];
            after = [ "medinix-vpn-route.service" ];
            serviceConfig = {
              BindReadOnlyPaths = [ "/etc/medinix-killswitch-resolv.conf:/etc/resolv.conf" ];
            };
          }) activeInstances
        );

    environment.etc."medinix-killswitch-resolv.conf".text = lib.concatMapStrings (
      dns: "nameserver ${dns}\n"
    ) cfg.dnsServers;
  };
}
