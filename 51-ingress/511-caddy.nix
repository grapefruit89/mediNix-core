# ---
# id: "511-caddy"
# title: "Caddy Chameleon Ingress — stream/internal/public/idp templates (stock Caddy, Lego TLS)"
# domain: 51
# folder: 51-ingress
# status: active
# last_reviewed: 2026-10-02
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

  # RT-5 (ntfy lesson): the enable flag of a vhost key <n> must resolve via
  # medinix.<n>.enable, medinix.<camelCase n>.enable (pocket-id → pocketId) or
  # medinix.observability.<n>.enable (domain-58 organs). A vhost key without a
  # resolvable enable flag is a BUILD ERROR (assertion below), never a
  # silently dropped site (F7).
  enabledOf =
    n: cfg.${n}.enable or cfg.${lib.toCamelCase n}.enable or cfg.observability.${n}.enable or false;

  # Reiner Manifest-Konsument: Liest Dienste direkt aus config.medinix.manifest
  manifestServices = lib.mapAttrs (
    n: m:
    let
      vhost = (cfg.ingress.vhosts or { }).${n} or { };
    in
    m // {
      accessGroup = vhost.accessGroup or m.accessGroup;
      customConfig = vhost.customConfig or (m.customConfig or "");
      allowUnauthenticated = vhost.allowUnauthenticated or (m.allowUnauthenticated or false);
      localBypass = if (vhost.localBypass or null) != null then vhost.localBypass else (m.localBypass or null);
      unauthenticatedPaths = (m.unauthenticatedPaths or [ ]) ++ (vhost.unauthenticatedPaths or [ ]);
    }
  ) (lib.filterAttrs (_: m: m.enable && m.accessGroup != "none") (config.medinix.manifest or { }));

  # Legacy-Kompatibilität für vhosts außerhalb des Manifests (z. B. pocket-id)
  legacyVhosts = lib.filterAttrs (
    n: vhost:
    let
      hasPort = (registry.${n}.port or null) != null;
      hasStatic = (vhost.customConfig or "") != "";
    in
    !(manifestServices ? ${n}) && enabledOf n && vhost.accessGroup != "none" && (hasPort || hasStatic)
  ) (cfg.ingress.vhosts or { });

  legacyNormalized = lib.mapAttrs (
    n: vhost: {
      port = registry.${n}.port or null;
      accessGroup = vhost.accessGroup;
      customConfig = vhost.customConfig or "";
      allowUnauthenticated = vhost.allowUnauthenticated or false;
      localBypass = vhost.localBypass or null;
      unauthenticatedPaths = vhost.unauthenticatedPaths or [ ];
    }
  ) legacyVhosts;

  enabledServices = manifestServices // legacyNormalized;

  # Declared-but-unresolvable vhosts (F7 made loud instead of silently dead).
  unresolvedVhosts = lib.filter (n: !(manifestServices ? ${n}) && !enabledOf n) (
    lib.attrNames (lib.filterAttrs (_: vhost: vhost.accessGroup != "none") (cfg.ingress.vhosts or { }))
  );
  # Enabled public vhosts that would be WAN-reachable without forward_auth and
  # without an explicit acknowledgement (see assertion below).
  publicWithoutAuth = lib.filterAttrs (
    _: m: m.accessGroup == "public" && !(m.allowUnauthenticated or false)
  ) enabledServices;

  # Enabled public vhosts that carry an auth-bypass path list.
  publicBypassPaths = lib.filterAttrs (
    _: m:
    m.accessGroup == "public"
    && (m.unauthenticatedPaths or [ ]) != [ ]
    && !(m.allowUnauthenticated or false)
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

  # RT-1: the admin API is unauthenticated and accepts POST /load (full config
  # replacement). On 127.0.0.1:2019 EVERY sandboxed service could reach it —
  # the hardening profiles allow loopback egress (Prowlarr talks WAN indexers),
  # so a compromised service could take over the whole edge without root.
  # A unix socket inside the unit's RuntimeDirectory is owner-only by default.
  # Reloads keep working: `caddy reload` reads the admin address from the
  # config file (upstream fix in v2.6.1; do NOT append a |mode suffix — that
  # breaks reload, caddy#5694).
  adminEndpoint =
    if useGlobal then "admin unix//run/caddy/admin.sock" else "admin unix//run/caddy-media/admin.sock";

  globalOptions = ''
    ${adminEndpoint}
    auto_https off
  '';
  mkProxy =
    n: m: extra:
    let
      targetPort = m.port or registry.${n}.port or null;
    in
    lib.optionalString (targetPort != null) ''
      reverse_proxy http://127.0.0.1:${toString targetPort} {
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
    m:
    let
      local = m.unauthenticatedPaths or [ ];
      global = ing.auth.unauthenticatedPaths or [ ];
    in
    lib.unique (global ++ local);

  # Per-service override wins; null means inherit the global default.
  localBypassOf =
    m: if (m.localBypass or null) != null then m.localBypass else ing.auth.localBypass;

  mkBaseConfig =
    n: m:
    {
      isLocal ? false,
    }:
    let
      applyAuth = ing.auth.mode == "forward-auth" && (!isLocal || !(localBypassOf m));
      skipPaths = unauthenticatedPathsOf m;
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
      cidrGate = lib.optionalString (isLocal || m.accessGroup == "internal") lanAbort;
      customConfig = m.customConfig or "";
    in
    {
      stream = ''
        ${lib.optionalString isLocal lanAbort}
        encode off
        ${customConfig}
        ${mkProxy n m streamTransport}
      '';
      internal = ''
        ${cidrGate}
        encode zstd gzip
        ${customConfig}
        ${mkProxy n m ""}
      '';
      public = ''
        ${lib.optionalString isLocal lanAbort}
        encode zstd gzip
        ${authBlock}
        ${customConfig}
        ${mkProxy n m ""}
      '';
      idp = ''
        ${lib.optionalString isLocal lanAbort}
        encode zstd gzip
        ${customConfig}
        ${mkProxy n m ""}
      '';
    }
    .${m.accessGroup};

  mkHttpsBody = n: m: ''
    ${tlsDirective}
    ${securityHeaders}
    ${mkBaseConfig n m { isLocal = false; }}
  '';
  mkHttpBody = n: m: mkBaseConfig n m { isLocal = false; };
  mkLocalBody = n: m: mkBaseConfig n m { isLocal = true; };

  # RT-3: access logs are the substrate for forensics AND any future edge
  # bouncer (516 CrowdSec / fail2ban) — without logs neither can exist.
  # Reduced format: Caddy already logs Cookie/Set-Cookie/Authorization/
  # Proxy-Authorization as REDACTED; we additionally strip the full query
  # string (API keys are commonly passed as ?apikey=…) and delete the auth
  # headers outright (defense in depth against a future log_credentials).
  # Output goes to stdout → journald (factory: StandardOutput=journal).
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

  mkSite = name: body: {
    inherit name;
    body = body + "\n" + accessLogBlock;
  };
  publicNames = n: lib.unique ([ n ] ++ lib.optional (cfg.dns.hostnames ? n) cfg.dns.hostnames.${n});

  mkDomainSites =
    n: m: hostName:
    if tlsEnabled then
      [
        (mkSite "http://${hostName}.${cfg.domain}" "redir https://{host}{uri} permanent")
        (mkSite "${hostName}.${cfg.domain}" (mkHttpsBody n m))
      ]
    else
      [
        (mkSite "http://${hostName}.${cfg.domain}" (mkHttpBody n m))
      ];

  serviceSites = lib.concatLists (
    lib.mapAttrsToList (
      n: m:
      (lib.optionals (cfg.domain != null) (lib.concatMap (mkDomainSites n m) (publicNames n)))
      ++ [ (mkSite "http://${n}.local" (mkLocalBody n m)) ]
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
      Type = lib.mkDefault "exec";
      WatchdogSec = lib.mkDefault "60s";
      CPUWeight = lib.mkDefault 400;
      IOWeight = lib.mkDefault 200;
      MemoryMin = lib.mkDefault "64M";
      MemoryLow = lib.mkDefault "128M";
      MemoryHigh = lib.mkDefault "512M";
      MemoryMax = lib.mkDefault "768M";
      ManagedOOMPreference = lib.mkDefault "avoid";
      # RT-1: admin socket lives in the RuntimeDirectory — owner-only (0700),
      # so no other local service/user can connect to the admin API.
      RuntimeDirectoryMode = "0700";
      # RT-1: reload through the admin unix socket instead of a hard restart.
      # ACME (514) runs `systemctl try-reload-or-restart` on renewal — without
      # ExecReload that degraded to a full proxy restart.
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
        # RT-5: a declared vhost whose service enable flag cannot be resolved
        # is a config error, not a silent no-op (this silently killed ntfy's
        # vhost and keeps F7's customConfig-only vhosts dead).
        assertion = unresolvedVhosts == [ ];
        message = ''
          [mediNix] ingress.vhosts declares hostnames whose service enable
          flag cannot be resolved: ${lib.concatStringsSep ", " unresolvedVhosts}.
          A vhost key must match a service option: medinix.<name>.enable,
          medinix.<camelCaseName>.enable (pocket-id → pocketId) or
          medinix.observability.<name>.enable (ntfy). customConfig-only vhosts
          need their service enabled as well (F7). accessGroup = "none" opts
          a vhost out entirely.
        '';
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

    # H12b: guard the WHOLE unit, not just the value. `mkIf` on a leaf still
    # materializes the `systemd.services.caddy` option path, creating an empty
    # phantom caddy.service in standalone mode. Standalone owns caddy-media only.
    # RT-1: RuntimeDirectory hosts the admin unix socket (nixpkgs' caddy unit
    # does not create /run/caddy by itself; systemd cleans it on restart,
    # which also removes stale admin sockets).
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
