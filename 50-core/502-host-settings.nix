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
          "${cfg.host.hostname}.lan";
      description = "Vollständig qualifizierter Domain-Name (FQDN) des Hosts.";
    };

    ramGb = lib.mkOption {
      type = lib.types.int;
      default = 16;
      description = "Physischer Arbeitsspeicher des Hosts in GB.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      let
        dom = cfg.host.domain;
        tld = if dom != null then lib.last (lib.splitString "." dom) else "";
      in
      [
        {
          assertion =
            dom == null
            || (
              dom != ""
              && builtins.match "^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$" dom != null
            );
          message = "[mediNix/host] 'medinix.host.domain' darf nicht leer sein und muss einem validen Domain-Format entsprechen! Gegeben: '${toString dom}'";
        }
        {
          assertion =
            cfg.host.adminEmail == null
            || (
              cfg.host.adminEmail != ""
              && builtins.match "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$" cfg.host.adminEmail != null
            );
          message = "[mediNix/host] 'medinix.host.adminEmail' muss eine valide E-Mail-Adresse sein! Gegeben: '${toString cfg.host.adminEmail}'";
        }
      ]
      ++ lib.optionals (dom != null) [
        {
          assertion = tld != "local";
          message = ''
            [mediNix/RFC-6762] TLD '.local' ist verboten!
            Grund: '.local' ist per RFC 6762 strikt für mDNS (Multicast DNS / Avahi / Apple Bonjour) reserviert.
            Die Nutzung in Unicast-DNS führt zu Timeouts, Hängern und DNS-Auflösungsfehlern auf macOS und iOS.
            Für das Heimnetz nutzt mediNix fest und unverschlüsselt '*.lan'.
          '';
        }
        {
          assertion = tld != "home";
          message = ''
            [mediNix/RFC-8375] TLD '.home' ist verboten!
            Grund: '.home' wurde von ICANN/IETF wegen massiver Kollisionen eingefroren.
            RFC 8375 definiert stattdessen '.home.arpa', was jedoch unhandlich ist.
            Für das Heimnetz nutzt mediNix fest und unverschlüsselt '*.lan'.
          '';
        }
        {
          assertion = tld != "internal";
          message = ''
            [mediNix/architecture] TLD '.internal' wird für externe Domains nicht unterstützt!
            Grund: mediNix reserviert das interne Routing fest für die 3-Buchstaben-TLD '.lan' (KISS-Prinzip).
            Trage unter 'medinix.host.domain' deine echte öffentliche WAN-Domain (z. B. 'deinedomain.de') für Cloudflare/ACME ein.
          '';
        }
        {
          assertion = !lib.hasSuffix ".lan" dom;
          message = ''
            [mediNix/architecture] 'medinix.host.domain' darf nicht auf '.lan' enden!
            Grund: '.lan' ist im mediNix-Chassis bereits als unveränderliche Invariante für alle internen Dienste
            (z. B. seerr.lan, jellyfin.lan) fest verdrahtet.
            Unter 'medinix.host.domain' gehört ausschließlich deine öffentliche Domain für WAN/HTTPS.
          '';
        }
        {
          assertion =
            (cfg.secrets.cloudflareEnvFile != null)
            || ((cfg.ingress.tls.acmeCredential or null) != null)
            || (
              cfg.ingress.tls.mode == "internal"
              || cfg.ingress.tls.mode == "custom"
              || cfg.ingress.tls.mode == "off"
            );
          message = ''
            [mediNix/secrets] Wenn 'medinix.host.domain' gesetzt ist, muss 'medinix.secrets.cloudflareEnvFile'
            (oder ingress.tls.acmeCredential) konfiguriert sein, es sei denn ingress.tls.mode steht auf internal/custom/off!
          '';
        }
      ];
  };
}
