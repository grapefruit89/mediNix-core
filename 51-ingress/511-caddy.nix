# ---
# id: "511-caddy"
# title: "Caddy Chameleon Ingress — Manifest-driven Reverse Proxy (Dual-Mode & Split-Horizon)"
# domain: 51
# folder: 51-ingress
# status: active
# last_reviewed: 2026-10-13
# provides: ["caddy", "ingress"]
# requires: ["lib/service-factory"]
# adr: ADR-511
# links:
#   adr: ADR-511
# ---
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.medinix;
  ing = cfg.ingress;
  domain = cfg.host.domain;
  df = import ../lib/derive.nix;

  ingressMode = ing.mode or "auto";
  useGlobal =
    if ingressMode == "global" then
      true
    else if ingressMode == "standalone" then
      false
    else
      config.services.caddy.enable;

  # EIN Produzent für die Exposure: der Vhost-Override gewinnt (das ist die
  # dokumentierte Bedien-Oberfläche, 51-ingress/AGENTS.md), sonst das Manifest.
  # 511 und die Konsumenten (z. B. 532) loesen damit identisch auf — keine stille
  # Divergenz mehr (F2: LAN-Client spooft Host-Header und kommt ohne Login rein).
  accessGroupOf = n: m: cfg.ingress.vhosts.${n}.accessGroup or m.accessGroup;

  enabledServices = lib.filterAttrs (n: m: m.enable && accessGroupOf n m != "none") (
    config.medinix.manifest or { }
  );

  # Enabled public vhosts that would be WAN-reachable without forward_auth and
  # without an explicit acknowledgement (see assertion below).
  publicWithoutAuth = lib.filterAttrs (
    n: m: accessGroupOf n m == "public" && !(m.allowUnauthenticated or false)
  ) enabledServices;

  # Enabled public vhosts that carry an auth-bypass path list.
  publicBypassPaths = lib.filterAttrs (
    n: m:
    accessGroupOf n m == "public"
    && (m.unauthenticatedPaths or [ ]) != [ ]
    && !(m.allowUnauthenticated or false)
  ) enabledServices;

  # Declared-but-unresolvable vhosts in ingress.vhosts (RT-5/F7 loud instead of silently dead)
  unresolvedVhosts = lib.filter (n: !(enabledServices ? ${n})) (
    lib.attrNames (
      lib.filterAttrs (_: vhost: (vhost.accessGroup or "internal") != "none") (cfg.ingress.vhosts or { })
    )
  );

  inherit (ing) trustedCidrs;
  trustedCidrsStr = builtins.concatStringsSep " " trustedCidrs;

  tlsEnabled = ing.tls.acmeHost != null || ing.tls.mode == "custom" || ing.tls.mode == "internal";

  tlsDirective =
    if ing.tls.acmeHost != null then
      "tls /var/lib/acme/${ing.tls.acmeHost}/fullchain.pem /var/lib/acme/${ing.tls.acmeHost}/key.pem"
    else if ing.tls.mode == "custom" then
      "tls ${ing.tls.certFile} ${ing.tls.keyFile}"
    else if ing.tls.mode == "internal" then
      "tls internal"
    else
      "";

  securityHeaders = ''
    header {
      Strict-Transport-Security "max-age=63072000; includeSubDomains"
      X-Content-Type-Options "nosniff"
      X-Frame-Options "SAMEORIGIN"
      Referrer-Policy "strict-origin-when-cross-origin"
      -Server
    }
  '';

  # request_header: Strip client-supplied identity headers before forward_auth
  stripAuthHeaders = lib.concatMapStrings (h: "request_header -${h}\n") [
    "Remote-User"
    "Remote-Email"
    "Remote-Groups"
    "X-Auth-Request-User"
    "X-Auth-Request-Email"
  ];

  lanAbort = lib.optionalString (trustedCidrs != [ ]) ''
    @blocked not remote_ip ${trustedCidrsStr}
    abort @blocked
  '';

  adminEndpoint =
    if useGlobal then "admin unix//run/caddy/admin.sock" else "admin unix//run/caddy-media/admin.sock";

  globalOptions = ''
    ${adminEndpoint}
    auto_https off
  '';

  accessLogBlock = ''
    log {
      output stdout
      format filter {
        wrap json
        fields {
          request>uri regexp "\?.*" "?"
          request>headers>Authorization delete
          request>headers>Cookie delete
        }
      }
    }
  '';

  unauthenticatedPathsOf =
    m:
    let
      local = m.unauthenticatedPaths or [ ];
      global = ing.auth.unauthenticatedPaths or [ ];
    in
    lib.unique (global ++ local);

  # Einheitlicher Handler-Generator für alle Service-Typen
  mkServiceBlock =
    name: m:
    {
      isLocal ? false,
    }:
    let
      isStream = accessGroupOf name m == "stream";
      # .lan ist kein Trust-Boundary, wird aber nur per CIDR (lanAbort) gegated.
      # forward_auth gilt fuer WAN-public — kein localBypass-Schalter mehr
      # (er war nie verdrahtet, siehe docs/ingress-security-matrix.md R3).
      needsAuth =
        !isLocal
        && (ing.auth.mode == "forward-auth")
        && (accessGroupOf name m == "public")
        && !(m.allowUnauthenticated or false);
      skipPaths = unauthenticatedPathsOf m;
      skipMatcher = lib.optionalString (needsAuth && skipPaths != [ ]) ''
        @needAuth not path ${lib.concatStringsSep " " skipPaths}
      '';
      authBlock = lib.optionalString needsAuth ''
        ${stripAuthHeaders}
        ${skipMatcher}
        forward_auth ${lib.optionalString (skipPaths != [ ]) "@needAuth "}${ing.auth.forwardAuthUpstream} {
          uri ${ing.auth.forwardAuthUri}
          copy_headers Remote-User Remote-Email Remote-Groups \
                       X-Auth-Request-User X-Auth-Request-Email
        }
      '';
      transportOpts = lib.optionalString isStream ''
        flush_interval -1
        transport http {
          read_timeout 300s
          write_timeout 300s
        }
      '';
      customConfig = m.customConfig or "";
    in
    ''
      ${lib.optionalString (!isStream) "encode zstd gzip"}
      route {
        ${lib.optionalString isLocal lanAbort}
        ${authBlock}
        ${customConfig}
        reverse_proxy http://127.0.0.1:${toString m.port} {
          header_up X-Real-IP {client_ip}
          header_up X-Forwarded-For {client_ip}
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-Host {host}
          ${transportOpts}
        }
      }
    '';

  mkSite = name: body: {
    inherit name;
    body = body + "\n" + accessLogBlock;
  };

  publicNames =
    n: lib.unique ([ n ] ++ lib.optional (cfg.dns.hostnames ? ${n}) cfg.dns.hostnames.${n});

  # 1. Lokale VHosts: JEDER aktive Dienst bekommt unverschlüsseltes http://${name}.lan
  lanSites = lib.mapAttrsToList (
    name: meta: mkSite "http://${name}.lan" (mkServiceBlock name meta { isLocal = true; })
  ) enabledServices;

  # 2. Externe WAN-VHosts: NUR public, stream und idp (internal bleibt rein auf .lan!)
  wanServices = lib.filterAttrs (
    n: m:
    lib.elem (accessGroupOf n m) [
      "public"
      "stream"
      "idp"
    ]
  ) enabledServices;

  wanSites = lib.optionals (domain != null) (
    lib.concatLists (
      lib.mapAttrsToList (
        n: m:
        lib.concatMap (
          hostName:
          if tlsEnabled then
            [
              (mkSite "http://${hostName}.${domain}" "redir https://{host}{uri} permanent")
              (mkSite "${hostName}.${domain}" ''
                ${tlsDirective}
                ${securityHeaders}
                ${mkServiceBlock n m { isLocal = false; }}
              '')
            ]
          else
            [
              (mkSite "http://${hostName}.${domain}" (mkServiceBlock n m { isLocal = false; }))
            ]
        ) (publicNames n)
      ) wanServices
    )
  );

  # 3. Landingpage & Dashboard (Split-Horizon)
  landingOn = ing.landing.enable && ing.landing.root != null;
  landingLanRoot = if ing.landing.lanRoot != null then ing.landing.lanRoot else ing.landing.root;

  landingFiles = lib.optionalString landingOn ''
    root * ${toString ing.landing.root}
    file_server
  '';

  landingLanFiles = lib.optionalString landingOn ''
    root * ${toString landingLanRoot}
    file_server
  '';

  landingSites = lib.optionals landingOn (
    [ (mkSite "http://dashboard.lan" "${lanAbort}\n${landingLanFiles}") ]
    ++ lib.optionals (domain != null && tlsEnabled) [
      (mkSite "http://${domain}" "redir https://{host}{uri} permanent")
      (mkSite domain ''
        ${tlsDirective}
        ${securityHeaders}
        ${landingFiles}
      '')
    ]
    ++ lib.optionals (domain != null && !tlsEnabled) [
      (mkSite "http://${domain}" landingFiles)
    ]
  );

  # 4. Catch-All Abort für unbekannte WAN-Subdomains
  catchAllSites = lib.optionals (domain != null) (
    [ (mkSite "http://*.${domain}" "abort") ]
    ++ lib.optionals tlsEnabled [
      (mkSite "*.${domain}" ''
        ${tlsDirective}
        abort
      '')
    ]
  );

  allSites = lanSites ++ wanSites ++ landingSites ++ catchAllSites;

  siteNameCounts = lib.foldl' (acc: e: acc // { ${e.name} = (acc.${e.name} or 0) + 1; }) { } allSites;
  duplicateSiteNames = lib.sort builtins.lessThan (
    lib.attrNames (lib.filterAttrs (_: c: c > 1) siteNameCounts)
  );

  caddyConfigStr = ''
    {
      ${globalOptions}
    }

  ''
  + lib.concatMapStrings (e: ''
    ${e.name} {
      ${e.body}
    }
  '') allSites;

  caddyStandalone = (import ../lib/service-factory.nix { inherit lib config pkgs; }) {
    name = "caddy-media";
    inherit (df.derive "caddy-media" 511) uid; # 5110 — aus der SSoT abgeleitet
    # 511 serviert die Medienablage (Tier C) -> media NUR als extraGroups,
    # Primaergruppe bleibt die UPG (ADR-0000 §4).
    mediaGroup = true;
    execStart = "${pkgs.caddy}/bin/caddy run --config /etc/caddy-media/Caddyfile";
    stateDir = "/var/lib/caddy-media";
    profile = "network";
    # CPU/IO/Memory stehen in lib/memory-policy.nix (SSoT). Hier nur, was NICHT
    # zur Memory-/Ressourcen-Policy gehoert.
    extraConfig = {
      Type = lib.mkDefault "exec";
      WatchdogSec = lib.mkDefault "60s";
      RuntimeDirectoryMode = "0700";
      ExecReload = "${pkgs.caddy}/bin/caddy reload --config /etc/caddy-media/Caddyfile --adapter caddyfile --force";
    };
  };
in
lib.mkMerge [
  (lib.mkIf (cfg.enable && ing.enable) {
    assertions = [
      {
        assertion = !(cfg.ingress.tls.acmeHost != null && cfg.ingress.tls.certFile != null);
        message = "[mediNix] Do not set both acmeHost and certFile.";
      }
      {
        assertion =
          cfg.ingress.tls.mode != "custom"
          || (cfg.ingress.tls.certFile != null && cfg.ingress.tls.keyFile != null);
        message = "[mediNix] Custom TLS needs certFile and keyFile.";
      }
      {
        assertion =
          cfg.ingress.auth.mode != "forward-auth"
          || (cfg.authProxyPresent && cfg.ingress.auth.forwardAuthUpstream != "");
        message = ''
          [mediNix] auth.mode = "forward-auth" needs an explicit forward-auth
          upstream (oauth2-proxy, ADR-517) via
          authProxyPresent = true + ingress.auth.forwardAuthUpstream.
          Pocket-ID is an OIDC provider and has NO forward-auth endpoint, so it
          is NOT a valid upstream.
        '';
      }
      {
        assertion = ingressMode != "global" || config.services.caddy.enable;
        message = "[mediNix] ingress.mode = global requires services.caddy.enable.";
      }
      {
        assertion = duplicateSiteNames == [ ];
        message = "[mediNix] Duplicate Caddy site hostnames: ${lib.concatStringsSep ", " duplicateSiteNames}";
      }
      {
        assertion = unresolvedVhosts == [ ];
        message = ''
          [mediNix] ingress.vhosts declares hostnames whose service enable
          flag cannot be resolved: ${lib.concatStringsSep ", " unresolvedVhosts}.
        '';
      }
      {
        assertion =
          lib.all (
            c:
            builtins.match "(10\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|127\\.|169\\.254\\.|100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.|[fF][cCdD][0-9A-Fa-f]{2}:|[fF][eE]80:|::1/).*" c
            != null
          ) trustedCidrs
          && !(lib.any (lib.hasSuffix "/0") trustedCidrs);
        message = "[mediNix/511] trustedCidrs enthält Nicht-Private-Netze oder /0 (Gefahr der WAN-Freischaltung).";
      }
      {
        assertion = cfg.ingress.auth.mode == "forward-auth" || publicWithoutAuth == { };
        message = "[mediNix] public vhost(s) without authentication: ${lib.concatStringsSep ", " (lib.attrNames publicWithoutAuth)}. Set ingress.auth.mode = \"forward-auth\", or acknowledge each with allowUnauthenticated = true.";
      }
      {
        assertion = publicBypassPaths == { };
        message = "[mediNix] public vhost(s) with unauthenticatedPaths (auth bypass): ${lib.concatStringsSep ", " (lib.attrNames publicBypassPaths)}. Remove the paths, switch to accessGroup = \"stream\", or set allowUnauthenticated = true.";
      }
      {
        assertion = (enabledServices == { } && !landingOn) || trustedCidrs != [ ];
        message = "[mediNix] ingress.trustedCidrs is empty but vhosts/landing are enabled. Set your real LAN CIDR(s) — no implicit trust of RFC1918/CGNAT.";
      }
    ];

    services.caddy.globalConfig = lib.mkIf useGlobal globalOptions;

    services.caddy.virtualHosts = lib.mkIf useGlobal (
      lib.listToAttrs (
        map (e: {
          inherit (e) name;
          value = {
            extraConfig = e.body;
          };
        }) allSites
      )
    );

    systemd.services.caddy = lib.mkIf useGlobal {
      serviceConfig = {
        OOMScoreAdjust = -900;
        RuntimeDirectory = "caddy";
        RuntimeDirectoryMode = "0700";
      };
    };

    environment.etc."caddy-media/Caddyfile" = lib.mkIf (!useGlobal) {
      text = caddyConfigStr;
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf (!useGlobal && cfg.hostIntegration.firewall == "managed")
        (
          if tlsEnabled then
            [
              80
              443
            ]
          else
            [ 80 ]
        );
    networking.firewall.allowedUDPPorts = lib.mkIf (
      !useGlobal && cfg.hostIntegration.firewall == "managed" && tlsEnabled
    ) [ 443 ];
  })

  (lib.mkIf (cfg.enable && ing.enable && !useGlobal) caddyStandalone)

  (lib.mkIf (cfg.enable && ing.enable && ing.tls.acmeHost != null) {
    users.groups.caddy = { };
    security.acme.certs.${ing.tls.acmeHost}.reloadServices =
      if useGlobal then [ "caddy.service" ] else [ "caddy-media.service" ];
  })

  (lib.mkIf (cfg.enable && ing.enable && !useGlobal && ing.tls.acmeHost != null) {
    users.users.caddy-media.extraGroups = [ "caddy" ];
  })
]
