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

  # Chameleon wie in 511-caddy: mediNix entscheidet, ob es den DNS-Listener
  # BESITZT oder sich an einen bereits laufenden Blocky ANHAENGT. Der Host
  # sagt das ueber `medinix.blocky.mode`. Auto-Erkennung ueber
  # `services.blocky.enable` waere hier eine Rekursion, weil mediNix diese
  # Option selbst setzt - anders als Caddy, wo 511 `services.caddy.enable`
  # nie schreibt.
  #
  #   "managed"  = mediNix besitzt Blocky: Port, Upstreams, Blocklisten.
  #   "external" = Der Host betreibt Blocky bereits. mediNix fasst weder
  #                `enable` noch `ports` an und haengt nur customDNS an.
  managed = active && cfg.blocky.mode == "managed";
  external = active && cfg.blocky.mode == "external";

  targetIp = cfg.host.lanIp or "127.0.0.1";
  customMapping = {
    "lan" = targetIp;
  }
  // lib.optionalAttrs (domain != null) {
    "${domain}" = targetIp;
  };
in
{
  options.medinix.blocky = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Blocky Split-DNS für LAN (ersetzt mDNS/Avahi).";
    };
    mode = lib.mkOption {
      type = lib.types.enum [
        "managed"
        "external"
      ];
      default = "managed";
      description = ''
        Wer besitzt den DNS-Listener?

        "managed"  = mediNix konfiguriert Blocky vollstaendig (enable,
                     ports.dns = 0.0.0.0:53, Upstreams, Blocklisten).
        "external" = Ein Host-Blocky laeuft bereits (eigener Port, eigene
                     Upstreams, eigene Blocklisten). mediNix setzt weder
                     `enable` noch `ports` und haengt nur `customDNS` an -
                     ein Attrset, das sich Schluessel fuer Schluessel mergen
                     laesst.

        Auto-Erkennung gibt es bewusst nicht: mediNix setzt
        `services.blocky.enable` selbst, ein Test darauf waere eine Rekursion.
      '';
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

    services.blocky = lib.mkMerge [
      (lib.mkIf managed {
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
            mapping = customMapping;
          };
          blocking = {
            denylists = { };
            clientGroupsBlock = { };
          };
        };
      })

      # Chameleon-Anhang: Der Host besitzt den Listener. mediNix steuert nur
      # bei, was sich additiv mergen laesst - `customDNS` ist ein Attrset, also
      # Schluessel fuer Schluessel. Port, Upstreams und Blocklisten bleiben
      # unangetastet, weil sie Skalare bzw. konkurrierende Listen sind.
      (lib.mkIf external {
        settings.customDNS = {
          customTTL = "1h";
          filterUnmappedTypes = true;
          mapping = customMapping;
        };
      })
    ];

    systemd.services.blocky = lib.mkIf managed (
      (import ../50-core/service-factory.nix { inherit lib config pkgs; }) {
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
      }
    );

  };
}
