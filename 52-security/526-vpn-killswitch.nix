# ---
# id: "526-vpn-killswitch"
# title: "Declarative VPN Kill-Switch Instances"
# domain: 52
# folder: 52-security
# status: active
# complexity: 5
# last_reviewed: 2026-08-18
# links:
#   adr: ADR-5410, ADR-5260
# ---
{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkOption
    mkEnableOption
    types
    mkIf
    nameValuePair
    mapAttrs'
    mkMerge
    concatStringsSep;

  ip = "${pkgs.iproute2}/bin/ip";
  nft = "${pkgs.nftables}/bin/nft";
  bpftool = "${pkgs.bpftool}/bin/bpftool";
  systemctl = "${pkgs.systemd}/bin/systemctl";

  # The submodule defining a single killswitch instance
  instanceType = types.submodule ({ name, config, ... }: {
    options = {
      enable = mkEnableOption "VPN confinement for ${name}";

      unit = mkOption {
        type = types.str;
        default = name;
        description = "The systemd service name without .service suffix (e.g. sabnzbd).";
      };

      user = mkOption {
        type = types.str;
        default = name;
        description = "The user under which the service runs. User must exist in config.users.users.";
      };

      vpnInterface = mkOption {
        type = types.str;
        default = "vpn0";
      };

      vpnUnit = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The systemd unit managing the VPN (e.g. wireguard-vpn0.service). Set to null if managed dynamically by networkd.";
      };

      routingTable = mkOption {
        type = types.ints.positive;
      };

      routingPriority = mkOption {
        type = types.ints.between 1 32765;
      };

      dnsServers = mkOption {
        type = types.listOf types.str;
        default = [ "10.64.0.1" ];
      };

      stateDirectory = mkOption {
        type = types.str;
        default = name;
        description = "StateDirectory name in /var/lib/";
      };
      
      blockedSocketPaths = mkOption {
        type = types.listOf types.str;
        default = [
          "/run/systemd/resolve"
          "/run/dbus/system_bus_socket"
        ];
        description = "List of UDS paths to block to prevent Localhost Relays.";
      };
    };
  });

  cfg = config.services.vpnKillSwitch;

in {
  options.services.vpnKillSwitch = {
    instances = mkOption {
      type = types.attrsOf instanceType;
      default = {};
      description = "Declarative VPN Kill-Switch instances (Safety Magnet pattern).";
    };
  };

  config = mkIf (cfg.instances != {}) (
    let
      activeInstances = lib.filterAttrs (n: v: v.enable) cfg.instances;
      
      # Generate policy services
      policyServices = mapAttrs' (name: instance: 
        let uid = toString config.users.users.${instance.user}.uid;
        in nameValuePair "vpn-policy-${instance.unit}" {
          description = "Permanent VPN kill-switch policy routing for ${instance.unit}";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-pre.target" ];
          before = [ "${instance.unit}.service" ];
          unitConfig.DefaultDependencies = true;
          
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "root"; Group = "root";
            CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
            AmbientCapabilities = [ "CAP_NET_ADMIN" ];
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true; PrivateTmp = true;
            
            ExecStart = pkgs.writeShellScript "install-policy-${instance.unit}" ''
              #!/bin/sh
              set -eu
              
              # First clean up any old rules to ensure idempotency
              ${ip} -4 rule del priority ${toString instance.routingPriority} 2>/dev/null || true
              
              ${ip} -4 rule add \
                priority ${toString instance.routingPriority} \
                uidrange ${uid}-${uid} \
                table ${toString instance.routingTable}
                
              ${ip} -4 route replace \
                blackhole default \
                metric 42760 \
                table ${toString instance.routingTable}
            '';
            
            # NO ExecStop! The policy should never fail open if the service is stopped.
            # If an admin intentionally wants to remove the kill-switch, they must rebuild NixOS.
          };
          path = [ pkgs.iproute2 pkgs.coreutils ];
        }
      ) activeInstances;

      # Generate targeted systemd modifications
      hardenedServices = mapAttrs' (name: instance:
        let 
          uid = toString config.users.users.${instance.user}.uid;
          vpnBinds = lib.optional (instance.vpnUnit != null) instance.vpnUnit;
        in nameValuePair instance.unit {
          
          requires = [ "vpn-policy-${instance.unit}.service" "nftables.service" ] ++ vpnBinds;
          bindsTo = vpnBinds;
          partOf = vpnBinds;
          after = [ 
            "vpn-policy-${instance.unit}.service" 
            "nftables.service"
            "network-online.target" 
          ] ++ vpnBinds;
          
          # Prevent permanent death on pre-flight failure
          unitConfig.StartLimitBurst = 0;
          
          serviceConfig = {
            # lib.mkForce resolves merge collisions for allowlists and scalars
            RestrictNetworkInterfaces = lib.mkForce [ "lo" instance.vpnInterface ];
            RestrictAddressFamilies = lib.mkForce [ "AF_UNIX" "AF_INET" ]; # AF_NETLINK removed
            SystemCallArchitectures = lib.mkForce "native";
            NoNewPrivileges = lib.mkForce true;
            CapabilityBoundingSet = lib.mkForce "";
            AmbientCapabilities = lib.mkForce "";
            RestrictSUIDSGID = lib.mkForce true;
            RestrictNamespaces = lib.mkForce true;
            ProtectControlGroups = lib.mkForce true;
            ProtectKernelTunables = lib.mkForce true;
            ProtectKernelModules = lib.mkForce true;
            ProtectKernelLogs = lib.mkForce true;
            PrivateTmp = lib.mkForce true;
            ProtectSystem = lib.mkForce "strict";
            ProtectHome = lib.mkForce true;
            PrivateMounts = lib.mkForce true;
            ProtectProc = lib.mkForce "invisible";
            ProcSubset = lib.mkForce "pid";
            LockPersonality = lib.mkForce true;
            RestrictRealtime = lib.mkForce true;
            MemoryDenyWriteExecute = lib.mkForce true;
            StateDirectory = lib.mkForce instance.stateDirectory;

            # NO mkForce for lists that should concatenate
            ReadWritePaths = [ "/var/lib/${instance.stateDirectory}" ];
            InaccessiblePaths = instance.blockedSocketPaths;
            BindReadOnlyPaths = [ "/etc/vpn-resolv-${instance.unit}.conf:/etc/resolv.conf" ];

            # Strict verification of the routing and firewall state before starting
            ExecStartPre = [
              "+${pkgs.writeShellScript "pre-flight-${instance.unit}" ''
                set -eu

                # Verify RPDB EXACT Match
                RULE=$(${ip} -4 rule show priority ${toString instance.routingPriority})
                if ! echo "$RULE" | ${pkgs.gnugrep}/bin/grep -q "uidrange ${uid}-${uid} lookup ${toString instance.routingTable}"; then
                  echo "FATAL: Exact routing policy rule missing or incorrect!" >&2
                  exit 1
                fi

                # Verify Blackhole EXACT Match
                ROUTE=$(${ip} -4 route show table ${toString instance.routingTable} match default)
                if ! echo "$ROUTE" | ${pkgs.gnugrep}/bin/grep -q "^blackhole default"; then
                  echo "FATAL: Blackhole route missing from table ${toString instance.routingTable}!" >&2
                  exit 1
                fi
                
                # Verify VPN Route Match AND Metric (< 42760)
                VPN_ROUTES=$(${ip} -4 route show table ${toString instance.routingTable} dev ${instance.vpnInterface} match default 2>/dev/null || true)
                HAS_VALID_ROUTE=false
                while IFS= read -r route_line; do
                  if [ -z "$route_line" ]; then continue; fi
                  # Extract metric (defaults to 0 if not specified)
                  METRIC=$(echo "$route_line" | ${pkgs.gnugrep}/bin/grep -oP '(?<=metric )\d+' || echo "0")
                  if [ "$METRIC" -lt 42760 ]; then
                    HAS_VALID_ROUTE=true
                    break
                  fi
                done <<< "$VPN_ROUTES"
                
                if [ "$HAS_VALID_ROUTE" = "false" ]; then
                  echo "FATAL: VPN default route missing or metric >= 42760!" >&2
                  exit 1
                fi

                # Verify Canary EXACT Match (using -n for numeric output to avoid name resolution)
                CANARY=$(${nft} -n list chain inet vpn-killswitch output)
                if ! echo "$CANARY" | ${pkgs.gnugrep}/bin/grep -q "skuid ${uid} oifname != \"lo\" oifname != \"${instance.vpnInterface}\" counter"; then
                  echo "FATAL: nftables canary rule missing for UID ${uid}!" >&2
                  exit 1
                fi
              ''}"
            ];

            # Verify BPF hooks are active
            ExecStartPost = [
              "+${pkgs.writeShellScript "verify-bpf-${instance.unit}" ''
                set -eu
                CGROUP=$(${systemctl} show --property=ControlGroup --value "${instance.unit}.service")
                
                if [ -z "$CGROUP" ] || [ "$CGROUP" = "/" ]; then
                  echo "FATAL: Could not determine cgroup for ${instance.unit}.service" >&2
                  exit 1
                fi
                
                OUTPUT=$(${bpftool} cgroup show "/sys/fs/cgroup$CGROUP" effective)
                
                # Strict check for exactly what RestrictNetworkInterfaces installs
                if ! echo "$OUTPUT" | ${pkgs.gnugrep}/bin/grep -q 'cgroup_inet_ingress'; then
                  echo "FATAL: cgroup_inet_ingress BPF missing!" >&2; exit 1
                fi
                if ! echo "$OUTPUT" | ${pkgs.gnugrep}/bin/grep -q 'cgroup_inet_egress'; then
                  echo "FATAL: cgroup_inet_egress BPF missing!" >&2; exit 1
                fi
              ''}"
            ];
          };
        }
      ) activeInstances;

      # Generate Custom Resolv.conf files
      resolvEtc = mapAttrs' (name: instance:
        nameValuePair "vpn-resolv-${instance.unit}.conf" {
          text = concatStringsSep "\n" (map (dns: "nameserver ${dns}") instance.dnsServers);
        }
      ) activeInstances;

      # Generate the single declarative nftables ruleset for all instances
      nftablesConfig = {
        enable = true;
        tables.vpn-killswitch = {
          family = "inet";
          content = ''
            chain output {
              type filter hook output priority -50; policy accept;
              ${concatStringsSep "\n" (lib.mapAttrsToList (name: instance: 
                let uid = toString config.users.users.${instance.user}.uid;
                in ''
                # Block outbound localhost initiation (Relay protection)
                meta skuid ${uid} oifname "lo" ct state new counter drop
                # General WAN leak canary
                meta skuid ${uid} oifname != "lo" oifname != "${instance.vpnInterface}" counter drop
              '') activeInstances)}
            }
          '';
        };
      };

    in mkMerge [
      {
        systemd.services = policyServices;
        environment.etc = resolvEtc;
        networking.nftables = nftablesConfig;
        
        assertions = (lib.mapAttrsToList (name: instance: {
          assertion = config.users.users ? "${instance.user}" && config.users.users.${instance.user}.uid != null;
          message = "SECURITY INVARIANT VIOLATION: User ${instance.user} does not exist or has no static UID assigned. Required by vpnKillSwitch.";
        }) activeInstances) ++ (lib.mapAttrsToList (name: instance: {
          assertion = !(builtins.elem "AF_INET6" config.systemd.services.${instance.unit}.serviceConfig.RestrictAddressFamilies);
          message = "SECURITY INVARIANT VIOLATION: IPv6 is not supported by vpnKillSwitch. Remove AF_INET6 from RestrictAddressFamilies for ${instance.unit}.";
        }) activeInstances) ++ (lib.mapAttrsToList (name: instance: {
          assertion = instance.vpnUnit == null || config.systemd.services ? "${lib.removeSuffix ".service" instance.vpnUnit}";
          message = "SECURITY INVARIANT VIOLATION: vpnUnit ${instance.vpnUnit} does not exist in config.systemd.services.";
        }) (lib.filterAttrs (n: v: v.vpnUnit != null) activeInstances)) ++ [
           
          {
            assertion = lib.length (lib.unique (lib.mapAttrsToList (n: v: v.routingPriority) activeInstances)) == lib.length (lib.mapAttrsToList (n: v: v.routingPriority) activeInstances);
            message = "SECURITY INVARIANT VIOLATION: Duplicate routingPriority values detected. Each instance must have a unique routingPriority.";
          }
        ];
      }
      
      # Inject hardening into the actual services
      {
        systemd.services = hardenedServices;
      }
    ]
  );
}
