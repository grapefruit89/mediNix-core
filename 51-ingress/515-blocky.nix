# ---
# id: "515-blocky"
# title: "Blocky — Split-DNS für LAN (ersetzt mDNS/Avahi)"
# domain: 51
# folder: 51-ingress
# status: active
# complexity: 3
# last_reviewed: 2026-10-25
# links:
#   adr: ADR-515
# provides: ["split-dns"]
# requires: ["50-core/registry", "50-core/service-factory"]
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
            let
              targetIp = cfg.host.lanIp or "127.0.0.1";
            in
            {
              "lan" = targetIp;
            }
            // lib.optionalAttrs (domain != null) {
              "${domain}" = targetIp;
            };
        };
        blocking = {
          denylists = { };
          clientGroupsBlock = { };
        };
      };
    };

    systemd.services.blocky = (import ../50-core/service-factory.nix { inherit lib config pkgs; }) {
      name = "blocky";
      profile = "network";
      ownsAccount = false;
      hardeningOnly = true;
      extraConfig = {
        User = "blocky";
        Group = "blocky";
        # Upstream (nixpkgs blocky) setzt DynamicUser = true plain. mediNix
        # braucht die feste UID 5150 (ADR-0000 §4: UID = Port = Primär-GID,
        # UPG + Peer-Isolation), deshalb mkForce false. Siehe Todo 17.
        DynamicUser = lib.mkForce false;
      };
    };
  };
}
