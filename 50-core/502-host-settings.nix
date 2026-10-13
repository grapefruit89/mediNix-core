# ---
# id: "502-host-settings"
# title: "Host Settings & Domain Baseline"
# domain: 50
# folder: 50-core
# status: active
# complexity: 1
# last_reviewed: 2026-10-12
# ---
{
  config,
  lib,
  ...
}:

let
  cfg = config.medinix;
in
{
  imports = [
    (lib.mkAliasOptionModule [ "medinix" "domain" ] [ "medinix" "host" "domain" ])
  ];

  options.medinix.host = {
    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "media.example.com";
      description = ''
        Unicast-Base-Domain für die L2-vHosts ({service}.{domain}).
        null = KEINE L2-Namen. L1-mDNS ({service}.local) läuft unabhängig immer.
        WICHTIG: NIEMALS auf .local enden — .local ist Multicast-DNS (RFC 6762).
      '';
    };

    adminEmail = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "admin@example.com";
      description = "Administrative E-Mail-Adresse für ACME / Alerting.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName or "medinix";
      description = "Hostname des mediNix-Nodes.";
    };

    fqdn = lib.mkOption {
      type = lib.types.str;
      default =
        if cfg.host.domain != null then
          "${cfg.host.hostname}.${cfg.host.domain}"
        else
          "${cfg.host.hostname}.local";
      description = "Vollständig qualifizierter Domain-Name (FQDN) des Hosts.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.host.domain == null
          || (cfg.host.domain != "" && builtins.match "^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$" cfg.host.domain != null);
        message = "[mediNix/host] 'medinix.host.domain' darf nicht leer sein und muss einem validen Domain-Format entsprechen! Gegeben: '${toString cfg.host.domain}'";
      }
      {
        assertion =
          cfg.host.domain == null || !lib.hasSuffix ".local" cfg.host.domain;
        message = "[mediNix/host] 'medinix.host.domain' darf nicht auf '.local' enden (RFC 6762 mDNS-Konflikt)! Gegeben: '${toString cfg.host.domain}'";
      }
      {
        assertion =
          cfg.host.adminEmail == null
          || (cfg.host.adminEmail != "" && builtins.match "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$" cfg.host.adminEmail != null);
        message = "[mediNix/host] 'medinix.host.adminEmail' muss eine valide E-Mail-Adresse sein! Gegeben: '${toString cfg.host.adminEmail}'";
      }
    ];
  };
}
