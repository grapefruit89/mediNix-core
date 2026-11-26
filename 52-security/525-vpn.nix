# ---
# id: "525-vpn"
# title: "WireGuard Interface, Policy Routing & Killswitch (52-security)"
# domain: 52
# folder: 52-security
# status: active
# complexity: 5
# last_reviewed: 2026-11-26
# anchors: ["bulkhead", "poka-yoke", "defense-in-depth"]
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
# links:
#   adr: ADR-526
# context7:
#   - query: "networking.wg-quick.interfaces wireguard"
#     library: /websites/nixos_manual_nixos_unstable
# ---
# Kanonisches VPN-Modul fuer mediNix (ADR-526):
#   1. WireGuard Interface-Erstellung & TPM/systemd-creds Schluessel-Einbindung
#   2. Dendritic Policy Routing & nftables Killswitch fuer geschuetzte Dienste (z. B. SABnzbd)
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix;
  inherit (cfg) vpn;
  ifName = vpn.interfaceName;
  credMount = "/run/credentials/wireguard-${ifName}.service/wg-private-key";

  ksCfg = config.services.vpnKillSwitch;
  activeInstances = lib.filterAttrs (_n: v: v.enable) ksCfg.instances;

  mark = toString ksCfg.routingTable;
  table = toString ksCfg.routingTable;
  vpnIf = ksCfg.vpnInterface;

  # R15: identity chain. nftables matches `meta skuid <instance.uid>`, so the
  # instance uid, the registry uid and the uid of the user the unit actually
  # runs as must be the same number — otherwise the killswitch targets the
  # wrong process.
  registry = import ../50-core/registry.nix { inherit lib; };
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
            localAllow = lib.mkOption {
              type = lib.types.listOf lib.types.port;
              default = [ ];
              description = "Explizit erlaubte ausgehende TCP-Zielports auf 127.0.0.1 (Loopback East-West). Default [] = Zero-Trust.";
            };
          };
        }
      );
      default = { };
    };
  };

  config = lib.mkMerge [
    # ── WireGuard Interface (Flake-managed) ──────────────────────────────────
    (lib.mkIf (cfg.enable && vpn.enable && !vpn.useExistingInterface) {
      assertions = [
        {
          assertion = vpn.privateKeyCredentialPath != null;
          message = ''
            [mediNix] vpn.enable is active and useExistingInterface = false, but vpn.privateKeyCredentialPath is null!

            [AI/Admin Context]
            Reason: mediNix creates the WireGuard interface and needs a TPM-sealed Private Key credential.
            Without it, networking.wireguard.interfaces.${ifName}.privateKeyFile points to a non-existent path,
            causing cryptic systemd failures instead of clear guardrail messages.
            Ref: ADR-526 (Flake-managed WireGuard Interface)
            Fix: Set medinix.vpn.privateKeyCredentialPath to the path of the TPM-sealed .cred file
            (systemd-creds encrypt --with-key=tpm2+host), or set medinix.vpn.useExistingInterface = true.
          '';
        }
        {
          assertion = (config.medinix.vpn.dns or [ ]) != [ ];
          message = "[mediNix/vpn] Schutz vor unverschlüsselten DNS-Leaks: 'medinix.vpn.dns' darf bei aktivem VPN nicht leer sein!";
        }
        {
          # A3: ein peerloses WireGuard-Interface ist up, traegt aber keinen
          # Verkehr — "VPN down, und niemand merkt es".
          assertion = vpn.peer.publicKey != "";
          message = ''
            [mediNix] vpn.enable = true and useExistingInterface = false, but
            vpn.peer.publicKey is empty. A peerless WireGuard interface carries no
            traffic. Ref: ADR-526.
          '';
        }
      ];

      medinix.vpn.interface = lib.mkDefault ifName;
      medinix.vpn.dnsServers = lib.mkDefault vpn.dns;
      services.vpnKillSwitch.vpnInterface = lib.mkDefault ifName;
      services.vpnKillSwitch.dnsServers = lib.mkDefault vpn.dns;

      networking.wireguard.interfaces.${ifName} = {
        ips = vpn.address;
        privateKeyFile = credMount;
        allowedIPsAsRoutes = false;

        peers = lib.optional (vpn.peer.publicKey != "") {
          publicKey = vpn.peer.publicKey;
          endpoint = vpn.peer.endpoint;
          allowedIPs = vpn.peer.allowedIPs;
          persistentKeepalive = vpn.peer.persistentKeepalive;
        };
      };

      systemd.services."wireguard-${ifName}" = {
        serviceConfig = {
          LoadCredentialEncrypted = [
            "wg-private-key:${vpn.privateKeyCredentialPath}"
          ];
          Restart = "always";
          RestartSec = "5s";
        };
      };
    })

    # ── Policy Routing & nftables Killswitch ────────────────────────────────
    (lib.mkIf (activeInstances != { }) {
      assertions = [
        {
          assertion = ksCfg.dnsServers != [ ];
          message = "[vpnKillSwitch] dnsServers must not be empty. An empty resolv.conf causes DNS leaks via 127.0.0.1.";
        }
        {
          assertion = ksCfg.vpnInterface != "";
          message = "[vpnKillSwitch] vpnInterface must be defined when instances are active.";
        }
        {
          assertion = lib.all (n: lib.hasAttr n config.systemd.services) (lib.attrNames activeInstances);
          message = "vpnKillSwitch.instances.<name> must match an existing systemd service name.";
        }
        {
          assertion = identityBroken == [ ];
          message = ''
            [vpnKillSwitch] R15 identity chain broken. For every active instance
            registry.uid == instance.uid == users.<unit-user>.uid must hold.
            Offenders: ${lib.concatStringsSep ", " identityBroken}
          '';
        }
        {
          assertion = ksCfg.ipv6 || !(config.networking.enableIPv6 or false);
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

      networking.nftables.tables.medinix_vpn_mark = lib.mkIf config.networking.nftables.enable {
        family = "inet";
        content = ''
          chain vpn_mark {
            type route hook output priority mangle;
            ${lib.concatMapStringsSep "\n" (name: ''
              meta skuid ${toString activeInstances.${name}.uid} jump mark_${name}
            '') (lib.attrNames activeInstances)}
          }
          ${lib.concatMapStringsSep "\n" (name: ''
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
        content =
          let
            v4Dns = lib.filter (d: !(lib.hasInfix ":" d)) ksCfg.dnsServers;
            v6Dns = lib.filter (d: lib.hasInfix ":" d) ksCfg.dnsServers;
            v4DnsSet = lib.concatStringsSep ", " v4Dns;
            v6DnsSet = lib.concatStringsSep ", " v6Dns;
          in
          ''
            chain killswitch {
              type filter hook output priority 0; policy accept;
              ${lib.concatMapStringsSep "\n" (name: ''
                meta skuid ${toString activeInstances.${name}.uid} jump kill_${name}
              '') (lib.attrNames activeInstances)}
            }
            ${lib.concatMapStringsSep "\n" (name: ''
              chain kill_${name} {
                # S-06: 1) Nur Antwortpakete auf eingehende Verbindungen (Caddy/*arr/Gatus -> 127.0.0.1)
                oifname "lo" ct state established,related ct direction reply counter accept

                # S-06: 2) Explizite East-West-Allowlist (nur 127.0.0.1 + definierter TCP-Zielport)
                ${lib.optionalString (activeInstances.${name}.localAllow != [ ]) ''
                  oifname "lo" ip daddr 127.0.0.1 tcp dport { ${
                    lib.concatMapStringsSep ", " toString activeInstances.${name}.localAllow
                  } } counter accept
                ''}

                # S-06: 3) Alle uebrigen lokalen Ziele (lo, 127/8, ::1) hart droppen
                oifname "lo" counter drop
                ip daddr 127.0.0.0/8 counter drop
                ip6 daddr ::1/128 counter drop

                # 4) Explizite LAN-CIDRs
                ${lib.optionalString (activeInstances.${name}.allowedLanCidrs != [ ]) ''
                  ip daddr { ${lib.concatStringsSep ", " activeInstances.${name}.allowedLanCidrs} } accept
                ''}

                # DNS-Leak-Schutz: Ausschließlich an konfigurierte VPN-DNS-Server durch den Tunnel
                ${lib.optionalString (v4DnsSet != "") ''
                  ip daddr { ${v4DnsSet} } udp dport 53 meta mark ${mark} oifname "${vpnIf}" accept
                  ip daddr { ${v4DnsSet} } tcp dport 53 meta mark ${mark} oifname "${vpnIf}" accept
                ''}
                ${lib.optionalString (ksCfg.ipv6 && v6DnsSet != "") ''
                  ip6 daddr { ${v6DnsSet} } udp dport 53 meta mark ${mark} oifname "${vpnIf}" accept
                  ip6 daddr { ${v6DnsSet} } tcp dport 53 meta mark ${mark} oifname "${vpnIf}" accept
                ''}
                udp dport { 53, 853, 5353 } counter drop
                tcp dport { 53, 853 } counter drop

                # IPv6 bei IPv4-only VPN verwerfen
                ${lib.optionalString (!ksCfg.ipv6) ''
                  meta nfproto ipv6 counter drop
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
            "medinix-vpn-route" = {
              description = "mediNix VPN Policy Routing";
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ];
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

                  # S-08: Kernel-RPDB uidrange Regel fuer Fail-Closed selbst bei nftables-Stop
                  ${lib.concatMapStringsSep "\n" (name: ''
                    uidStr="${toString activeInstances.${name}.uid}"
                    if ! ${pkgs.iproute2}/bin/ip rule show | grep -Eq "uidrange $uidStr-$uidStr lookup ${table}"; then
                      ${pkgs.iproute2}/bin/ip rule add uidrange "$uidStr-$uidStr" table ${table} priority 900
                    fi
                    ${
                      if ksCfg.ipv6 then
                        ''
                          if ! ${pkgs.iproute2}/bin/ip -6 rule show | grep -Eq "uidrange $uidStr-$uidStr lookup ${table}"; then
                            ${pkgs.iproute2}/bin/ip -6 rule add uidrange "$uidStr-$uidStr" table ${table} priority 900
                          fi
                        ''
                      else
                        ""
                    }
                  '') (lib.attrNames activeInstances)}

                  ${pkgs.iproute2}/bin/ip route replace unreachable default table ${table} metric 100
                  src_ip=$(${pkgs.iproute2}/bin/ip -4 addr show dev ${vpnIf} 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1 || true)
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
                    if ksCfg.ipv6 then
                      ''
                        if ! ${pkgs.iproute2}/bin/ip -6 rule show | grep -Eq "fwmark (${mark}|$hexmark) lookup ${table}"; then
                          ${pkgs.iproute2}/bin/ip -6 rule add fwmark ${mark} table ${table} priority 1000
                        fi
                        ${pkgs.iproute2}/bin/ip -6 route replace unreachable default table ${table} metric 100
                        if ${pkgs.iproute2}/bin/ip -6 addr show dev ${vpnIf} 2>/dev/null | grep -q inet6; then
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
                BindReadOnlyPaths = [
                  "/etc/medinix-killswitch-resolv.conf:/etc/resolv.conf"
                  "/etc/medinix-killswitch-nsswitch.conf:/etc/nsswitch.conf"
                ];
                InaccessiblePaths = [
                  "-/run/nscd"
                  "-/run/systemd/resolve"
                  "-/run/dbus/system_bus_socket"
                  "-/run/avahi-daemon"
                  "-/run/caddy"
                  "-/run/caddy-media"
                  "-/run/pocket-id"
                  "-/run/oauth2-proxy"
                  "-/run/ntfy"
                ];
              };
            }) activeInstances
          );

      environment.etc."medinix-killswitch-resolv.conf".text =
        lib.concatMapStrings (dns: "nameserver ${dns}\n") ksCfg.dnsServers
        + "options timeout:2 attempts:2 single-request\n";

      environment.etc."medinix-killswitch-nsswitch.conf".text = ''
        passwd: files
        group:  files
        shadow: files
        hosts:  files dns
      '';
    })
  ];
}
