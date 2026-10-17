# ---
# id: "517-oauth2-proxy"
# title: "oauth2-proxy — forward-auth bridge to the IdP (ADR-517)"
# domain: 51
# folder: 51-ingress
# status: active
# complexity: 3
# last_reviewed: 2026-10-17
# links:
# provides: ["forward-auth-proxy"]
# requires: ["lib/registry"]
# ports: [5170]
# upstream_docs: ["https://oauth2-proxy.github.io/oauth2-proxy/"]
# forum_links: []
# upstream_github: "https://github.com/oauth2-proxy/oauth2-proxy"
# nixpkgs_attr: "services.oauth2-proxy"
# state_dir: "/var/lib/oauth2-proxy"
# uds_socket: false
# systemd_hardened: true
# adr: ADR-517
# links:
#   adr: ADR-517
# ---
# 51-ingress/517-oauth2-proxy.nix — Forward-Auth-Bruecke (ADR-517)
#
# Rolle: Caddy (511) fragt diesen Proxy per `forward_auth`, der Proxy fragt das
# IdP (Pocket ID, 512) per OIDC. Kein eigener vhost: 511 reicht `/oauth2/*`
# jedes geschuetzten vhosts hierher durch.
#
# Vertrag mit 511:
#   517 liefert: Prozess auf 127.0.0.1:5170, `authProxyPresent = true` und den
#     Default-Upstream `http://127.0.0.1:5170`.
#   517 liefert NICHT: TLS, vhosts, DNS, Caddyfiles — das bleibt bei 511.
#
# Secrets sind versiegelt (ADR-521): der Klartext lebt nur im
# Credential-Verzeichnis der Unit (`%d`); der Store sieht nur Pfade.
{
  config,
  lib,
  ...
}:

let
  cfg = config.medinix;
  oa = cfg.oauth2Proxy;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  svc = registry.oauth2-proxy;
in
{
  options.medinix.oauth2Proxy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Forward-Auth-Proxy starten. Wer ihn einschaltet, verdrahtet 511
        mit: `authProxyPresent` wird wahr und
        `ingress.auth.forwardAuthUpstream` defaultet auf
        `http://127.0.0.1:${toString svc.port}` (ADR-517).
      '';
    };
    oidcIssuerUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "https://id.example.com";
      description = ''
        OIDC-Issuer, den der Browser erreicht (oeffentliche URL des IdP). Muss
        gesetzt sein, wenn `enable` true ist.
      '';
    };
    clientID = lib.mkOption {
      type = lib.types.str;
      default = "mediNix";
      description = ''
        OIDC-Client-ID, die beim Issuer registriert ist.
      '';
    };
    clientSecretCredential = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Pfad zum **versiegelten** Credential (systemd-Credential-Format,
        ADR-521) mit dem OIDC-Client-Secret. Wird als `LoadCredentialEncrypted`
        geladen und ueber `%d/client-secret` gelesen; nie als Klartext.
      '';
    };
    cookieSecretCredential = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Pfad zum **versiegelten** Credential (ADR-521) mit dem
        Cookie-Signing-Secret (32 Byte). Wird ueber `%d/cookie-secret` gelesen.
      '';
    };
  };

  config = lib.mkIf oa.enable {
    assertions = [
      {
        assertion = oa.oidcIssuerUrl != "";
        message = ''
          [mediNix/517] oauth2Proxy.enable = true, aber oidcIssuerUrl fehlt.
          Was: Der Auth-Proxy hat keinen OIDC-Issuer.
          Warum: Der Browser wird zum Issuer umgeleitet; ohne URL kein Login -
            also auch kein forward_auth fuer die geschuetzten Dienste.
          Wie: medinix.oauth2Proxy.oidcIssuerUrl = "https://<idp-host>" setzen.
        '';
      }
      {
        assertion = oa.clientSecretCredential != null && oa.cookieSecretCredential != null;
        message = ''
          [mediNix/517] oauth2Proxy.enable = true, aber die versiegelten
          Credential-Pfade fehlen.
          Was: clientSecretCredential und cookieSecretCredential muessen gesetzt sein.
          Warum: Secrets kommen nur versiegelt herein (ADR-521) - kein Klartext im
            Store und kein stiller Fallback auf ein leeres Secret.
          Wie: beide Optionen auf die vom Host erzeugten, versiegelten
            Credential-Dateien zeigen lassen.
        '';
      }
    ];

    services.oauth2-proxy = {
      enable = true;
      provider = "oidc";
      inherit (oa) clientID;
      oidcIssuerUrl = oa.oidcIssuerUrl;
      httpAddress = "http://127.0.0.1:${toString svc.port}";
      # 511 setzt die X-Forwarded-*-Header; ohne reverseProxy verwirft der
      # Proxy sie, ohne setXauthrequest sieht der Dienst keinen Benutzer.
      reverseProxy = true;
      setXauthrequest = true;
      # Nutzlast kommt ueber das Credential-Verzeichnis (`%d`). Die
      # nixpkgs-Optionen clientSecretFile/cookie.secretFile bleiben bewusst
      # null: daraus baut das Modul ein UNVERSIEGELTES LoadCredential, das die
      # verschluesselte Datei nur kopieren wuerde.
      extraConfig = {
        client-secret-file = "%d/client-secret";
        cookie = {
          secret-file = "%d/cookie-secret";
        };
      };
    };

    systemd.services.oauth2-proxy.serviceConfig = {
      LoadCredentialEncrypted = [
        "client-secret:${oa.clientSecretCredential}"
        "cookie-secret:${oa.cookieSecretCredential}"
      ];
      StateDirectory = "oauth2-proxy";
      # ADR-5050-Baseline. Bewusst OHNE `RestrictNetworkInterfaces`: der Proxy
      # muss den Issuer erreichen koennen (Netz + DNS). Die Abschottung nach
      # aussen macht der Loopback-Listener plus 511 als einziges WAN-Gesicht.
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      CapabilityBoundingSet = [ "" ];
    };

    # ADR-0000: eine Quelle fuer Port/UID (Registry), nichts hartkodiert.
    users.users.oauth2-proxy.uid = svc.uid;

    # F19: kein manueller Spiegel mehr. Wer 517 einschaltet, hat einen
    # Auth-Proxy, und 511 zeigt automatisch auf ihn - beides mkDefault, der Host
    # kann (z. B. auf einen externen Proxy) ueberschreiben.
    medinix.authProxyPresent = lib.mkDefault true;
    medinix.ingress.auth.forwardAuthUpstream = lib.mkDefault "http://127.0.0.1:${toString svc.port}";
  };
}
