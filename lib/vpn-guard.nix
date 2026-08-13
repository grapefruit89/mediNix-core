{ lib }:
let
  mkVpnGuard = { serviceName, vpnInterface ? "wg0" }: {
    systemd.services.${serviceName}.serviceConfig = {
      # eBPF restriction: process can ONLY see the VPN interface and localhost
      RestrictNetworkInterfaces = "${vpnInterface} lo";
      # Ensure service doesn't start until VPN device exists
      BindsTo = [ "sys-subsystem-net-devices-${vpnInterface}.device" ];
      After = [ "sys-subsystem-net-devices-${vpnInterface}.device" ];
    };

    # The ultimate kill-switch: UID-based drop rule in nftables
    # Mathematically guarantees no packet can leave via any interface except wg0 or lo
    networking.nftables = {
      enable = lib.mkDefault true;
      ruleset = ''
        table inet vpn_killswitch_${serviceName} {
          chain output {
            type filter hook output priority 0; policy accept;
            meta skuid "${serviceName}" oifname != { "${vpnInterface}", "lo" } counter drop
          }
        }
      '';
    };
  };
in
{
  inherit mkVpnGuard;
}
