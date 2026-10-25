# ---
# id: "515-blocky"
# title: "Blocky — Split-DNS für LAN (ersetzt mDNS/Avahi)"
# domain: 51
# folder: 51-ingress
# status: active
# complexity: 3
# last_reviewed: 2026-10-25
# links:
#   adr: ADR-515-mdns-avahi-aliases
# provides: ["split-dns"]
# requires: ["lib/registry", "lib/service-factory"]
# ports: [53]
# state_dir: "/var/lib/blocky"
# nixpkgs_attr: "services.blocky"
# uds_socket: false
# systemd_hardened: true
# ---
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix;
  domain = cfg.host.domain;
  active = cfg.enable && (cfg.blocky.enable or true);
in
{
  options.medinix.blocky = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Blocky Split-DNS für LAN (ersetzt mDNS/Avahi).";
    };
  };

  config = lib.mkIf active {
    medinix.manifest.blocky = {
      enable = true;
      num = 515;
      accessGroup = "none";
      hasDaemon = true;
      role = "split-dns";
      capabilities = [ "CAP_NET_BIND_SERVICE" ];
      ui = {
        title = "Blocky";
        description = "Split-DNS für LAN";
        icon = "blocky";
        group = "Security";
        showOnLanding = false;
      };
      monitoring = {
        enable = false;
      };
      ops = {
        priority = "high";
        ramBudget = "128M";
        notes = "Split-DNS Proxy für *.lan und *.${toString domain}.";
      };
      sources = {
        upstream = "https://0xerr0r.github.io/blocky/";
        repo = "https://github.com/0xerr0r/blocky";
        nixos = "https://search.nixos.org/options?query=services.blocky";
      };
    };

    services.blocky = {
      enable = true;
      settings = {
        ports = {
          dns = "0.0.0.0:53";
          http = "127.0.0.1:5150";
        };
        upstreams.groups.default = [ "https://1.1.1.1/dns-query" ];
        customDNS = {
          customTTL = "1h";
          filterUnmappedTypes = true;
          mapping =
            {
              "lan" = "127.0.0.1";
            }
            // lib.optionalAttrs (domain != null) {
              "${domain}" = "127.0.0.1";
            };
        };
        blocking = {
          denylists = { };
          clientGroupsBlock = { };
        };
      };
    };

    systemd.services.blocky = (import ../lib/service-factory.nix { inherit lib config pkgs; }) {
      name = "blocky";
      profile = "network";
      ownsAccount = false;
      hardeningOnly = true;
      extraConfig = {
        User = "blocky";
        Group = "blocky";
        DynamicUser = lib.mkForce false;
      };
    };
  };
}
