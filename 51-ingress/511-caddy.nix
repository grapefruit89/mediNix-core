# ---
# id: "511-caddy"
# title: "Caddy Chameleon Ingress — stream/internal/public/idp templates (stock Caddy, Lego TLS)"
# domain: 51
# folder: 51-ingress
# status: active
# last_reviewed: 2026-09-02
# provides: ["caddy", "ingress"]
# requires: ["lib/service-factory", "lib/registry"]
# adr: ADR-511
# ---
# .local is a hostname, not a network. WAN clients can send Host: jellyfin.local
# to :80. Every .local site therefore gets the same remote_ip abort as internal.
# localBypass only skips forward_auth *after* that CIDR check.
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.medinix;
  ing = cfg.ingress;
  ingressMode = ing.mode or "auto";
  useGlobal =
    if ingressMode == "global" then
      true
    else if ingressMode == "standalone" then
      false
    else
      config.services.caddy.enable;

  registry = (import ../lib/registry.nix { inherit lib; }).services;
  enabledServices = lib.filterAttrs (
    n: vhost:
    let
      enabled = cfg.${n}.enable or cfg.${lib.toCamelCase n}.enable or false;
      hasPort = (registry.${n}.port or null) != null;
      hasStatic = (vhost.customConfig or "") != "";
    in
    enabled && vhost.accessGroup != "none" && (hasPort || hasStatic)
  ) cfg.ingress.vhosts;

  # Enabled public vhosts that would be WAN-reachable without forward_auth and
  # without an explicit acknowledgement (see assertion below).
  publicWithoutAuth = lib.filterAttrs (
    _: v: v.accessGroup == "public" && !(v.allowUnauthenticated or false)
  ) enabledServices;

  # Enabled public vhosts that carry an auth-bypass path list.
  publicBypassPaths = lib.filterAttrs (
    _: v:
    v.accessGroup == "public"
    && (v.unauthenticatedPaths or [ ]) != [ ]
    && !(v.allowUnauthenticated or false)
  ) enabledServices;

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

  # request_header (NOT header!): `header` only edits RESPONSE headers.
  # We must strip client-supplied identity headers from the REQUEST before
  # forward_auth copies the trusted ones in (Caddy docs: header = response).
  stripAuthHeaders = ''
    request_header {
      -Remote-User
      -Remote-Email
      -Remote-Groups
      -X-Auth-Request-User
      -X-Auth-Request-Email
    }
  '';

  # Only meaningful with a non-empty trust list; the assertion below makes an
  # empty trustedCidrs alongside enabled vhosts a build error.
  lanAbort = lib.optionalString (trustedCidrs != [ ]) ''
    @blocked not remote_ip ${trustedCidrsStr}
    abort @blocked
  '';

  globalOptions = ''
    admin localhost:2019
    auto_https off
  '';

  mkProxy =
    n: extra:
    lib.optionalString ((registry.${n}.port or null) != null) ''
      reverse_proxy http://127.0.0.1:${toString registry.${n}.port} {
        header_up X-Real-IP {client_ip}
        header_up X-Forwarded-For {client_ip}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}
        ${extra}
      }
    '';

  streamTransport = ''
    flush_interval -1
    transport http {
      read_timeout 300s
      write_timeout 300s
    }
  '';

  # F5: Pocket-ID is an OIDC provider, NOT a forward-auth endpoint (its docs:
  # "exclusively an OIDC provider … no built-in proxy provider"). forward_auth
  # needs an actual auth proxy (oauth2-proxy / tinyauth / caddy-security), so
  # the upstream must be set explicitly — no Pocket-ID fallback.
  authUpstream = ing.auth.forwardAuthUpstream;

  unauthenticatedPathsOf =
    vhost:
    let
      local = vhost.unauthenticatedPaths or [ ];
      global = ing.auth.unauthenticatedPaths or [ ];
    in
    lib.unique (global ++ local);

  # Per-vhost override wins; null means inherit the global default.
  localBypassOf =
    vhost: if (vhost.localBypass or null) != null then vhost.localBypass else ing.auth.localBypass;

  mkBaseConfig =
    n: vhost:
    {
      isLocal ? false,
    }:
    let
      applyAuth = ing.auth.mode == "forward-auth" && (!isLocal || !(localBypassOf vhost));
      skipPaths = unauthenticatedPathsOf vhost;
      skipMatcher = lib.optionalString (applyAuth && skipPaths != [ ]) ''
        @needAuth not path ${lib.concatStringsSep " " skipPaths}
      '';
      authBlock = lib.optionalString applyAuth ''
        ${stripAuthHeaders}
        ${skipMatcher}
        forward_auth ${lib.optionalString (skipPaths != [ ]) "@needAuth "}${authUpstream} {
          uri ${ing.auth.forwardAuthUri}
          copy_headers Remote-User Remote-Email Remote-Groups \
                       X-Auth-Request-User X-Auth-Request-Email
        }
      '';
      # .local always CIDR-gated. Domain internal too. Stream/public/idp on
      # the real hostname stay reachable from WAN when that is the policy.
      cidrGate = lib.optionalString (isLocal || vhost.accessGroup == "internal") lanAbort;
    in
    {
      stream = ''
        ${lib.optionalString isLocal lanAbort}
        encode off
        ${vhost.customConfig}
        ${mkProxy n streamTransport}
      '';
      internal = ''
        ${cidrGate}
        encode zstd gzip
        ${vhost.customConfig}
        ${mkProxy n ""}
      '';
      public = ''
        ${lib.optionalString isLocal lanAbort}
        encode zstd gzip
        ${authBlock}
        ${vhost.customConfig}
        ${mkProxy n ""}
      '';
      idp = ''
        ${lib.optionalString isLocal lanAbort}
        encode zstd gzip
        ${vhost.customConfig}
        ${mkProxy n ""}
      '';
    }
    .${vhost.accessGroup};

  mkHttpsBody = n: vhost: ''
    ${tlsDirective}
    ${securityHeaders}
    ${mkBaseConfig n vhost { isLocal = false; }}
  '';
  mkHttpBody = n: vhost: mkBaseConfig n vhost { isLocal = false; };
  mkLocalBody = n: vhost: mkBaseConfig n vhost { isLocal = true; };

  mkSite = name: body: { inherit name body; };

  publicNames = n: lib.unique ([ n ] ++ lib.optional (cfg.dns.hostnames ? n) cfg.dns.hostnames.${n});

  mkDomainSites =
    n: vhost: hostName:
    if tlsEnabled then
      [
        (mkSite "http://${hostName}.${cfg.domain}" "redir https://{host}{uri} permanent")
        (mkSite "${hostName}.${cfg.domain}" (mkHttpsBody n vhost))
      ]
    else
      [
        (mkSite "http://${hostName}.${cfg.domain}" (mkHttpBody n vhost))
      ];

  serviceSites = lib.concatLists (
    lib.mapAttrsToList (
      n: vhost:
      (lib.optionals (cfg.domain != null) (lib.concatMap (mkDomainSites n vhost) (publicNames n)))
      ++ [ (mkSite "http://${n}.local" (mkLocalBody n vhost)) ]
    ) enabledServices
  );

  landingOn = ing.landing.enable && ing.landing.root != null;
  landingFiles = lib.optionalString landingOn ''
    root * ${toString ing.landing.root}
    file_server
  '';
  landingHttpsBody = ''
    ${tlsDirective}
    ${securityHeaders}
    ${lanAbort}
    ${landingFiles}
  '';
  landingHttpLanBody = ''
    ${lanAbort}
    ${landingFiles}
  '';

  landingSites = lib.optionals landingOn (
    (lib.optionals (cfg.domain != null && tlsEnabled) [
      (mkSite "http://${cfg.domain}" "redir https://{host}{uri} permanent")
      (mkSite cfg.domain landingHttpsBody)
    ])
    ++ (lib.optionals (cfg.domain != null && !tlsEnabled) [
      (mkSite "http://${cfg.domain}" landingHttpLanBody)
    ])
    ++ [ (mkSite "http://home.local" landingHttpLanBody) ]
  );

  catchAllSites =
    lib.optionals (cfg.domain != null) [
      (mkSite "http://*.${cfg.domain}" "abort")
    ]
    ++ lib.optionals (cfg.domain != null && tlsEnabled) [
      (mkSite "*.${cfg.domain}" ''
        ${tlsDirective}
        abort
      '')
    ];

  allSites = serviceSites ++ landingSites ++ catchAllSites;

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
    uid = registry.caddy.uid;
    execStart = "${pkgs.caddy}/bin/caddy run --config /etc/caddy-media/Caddyfile";
    stateDir = registry.caddy.stateDir;
    profile = "network";
    extraConfig = {
      Type = lib.mkDefault "notify";
      WatchdogSec = lib.mkDefault "60s";
      CPUWeight = lib.mkDefault 400;
      IOWeight = lib.mkDefault 200;
      MemoryMin = lib.mkDefault "64M";
      MemoryLow = lib.mkDefault "128M";
      MemoryHigh = lib.mkDefault "512M";
      MemoryMax = lib.mkDefault "768M";
      ManagedOOMPreference = lib.mkDefault "avoid";
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
          upstream (oauth2-proxy / tinyauth / caddy-security) via
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

    systemd.services.caddy.serviceConfig.OOMScoreAdjust = lib.mkIf useGlobal (-900);

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
