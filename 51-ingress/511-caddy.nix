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
# Stock pkgs.caddy. TLS from 514. Sites from ingress.vhosts.
# A vhost is live when the matching service is enabled, accessGroup != none,
# and it has either a registry port (reverse_proxy) or customConfig (static).
# Admin API stays on localhost so `systemctl reload` / ACME reloadServices work.
# It is not published; firewall only opens 80/443.
{ lib, pkgs, config, ... }:

let
  cfg = config.medinix;
  ing = cfg.ingress;
  ingressMode = ing.mode or "auto";
  useGlobal =
    if ingressMode == "global" then true
    else if ingressMode == "standalone" then false
    else config.services.caddy.enable;

  registry = (import ../lib/registry.nix { inherit lib; }).services;
  enabledServices = lib.filterAttrs (n: vhost:
    let
      enabled = cfg.${n}.enable or cfg.${lib.toCamelCase n}.enable or false;
      hasPort = (registry.${n}.port or null) != null;
      hasStatic = (vhost.customConfig or "") != "";
    in
      enabled && vhost.accessGroup != "none" && (hasPort || hasStatic)
  ) cfg.ingress.vhosts;

  trustedCidrs = ing.trustedCidrs or [
    "10.0.0.0/8"
    "100.64.0.0/10"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "fd00::/8"
  ];
  trustedCidrsStr = builtins.concatStringsSep " " trustedCidrs;

  tlsEnabled =
    ing.tls.acmeHost != null || ing.tls.mode == "custom" || ing.tls.mode == "internal";

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

  globalOptions = ''
    admin localhost:2019
    auto_https off
  '';

  mkProxy = n: extra:
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

  authUpstream =
    if ing.auth.forwardAuthUpstream != "" then ing.auth.forwardAuthUpstream
    else "127.0.0.1:${toString registry."pocket-id".port}";

  skipPathsOf = vhost:
    let
      local = vhost.skipPaths or [];
      global = ing.auth.skipPaths or [];
    in lib.unique (global ++ local);

  mkBaseConfig = n: vhost: { isLocal ? false }:
    let
      applyAuth =
        ing.auth.mode == "forward-auth"
        && (!isLocal || !ing.auth.localBypass);
      skipPaths = skipPathsOf vhost;
      skipMatcher = lib.optionalString (applyAuth && skipPaths != []) ''
        @needAuth not path ${lib.concatStringsSep " " skipPaths}
      '';
      authBlock = lib.optionalString applyAuth ''
        ${skipMatcher}
        forward_auth ${lib.optionalString (skipPaths != []) "@needAuth "}${authUpstream} {
          uri ${ing.auth.forwardAuthUri}
          copy_headers Remote-User Remote-Email Remote-Groups \
                       X-Auth-Request-User X-Auth-Request-Email
        }
      '';
      abortBlock = lib.optionalString (!isLocal) ''
        @blocked not remote_ip ${trustedCidrsStr}
        abort @blocked
      '';
    in {
      stream = ''
        encode off
        ${vhost.customConfig}
        ${mkProxy n streamTransport}
      '';
      internal = ''
        ${abortBlock}
        encode zstd gzip
        ${vhost.customConfig}
        ${mkProxy n ""}
      '';
      public = ''
        encode zstd gzip
        ${authBlock}
        ${vhost.customConfig}
        ${mkProxy n ""}
      '';
      idp = ''
        encode zstd gzip
        ${vhost.customConfig}
        ${mkProxy n ""}
      '';
    }.${vhost.accessGroup};

  mkHttpsBody = n: vhost: ''
    ${tlsDirective}
    ${securityHeaders}
    ${mkBaseConfig n vhost { isLocal = false; }}
  '';
  mkHttpBody = n: vhost: mkBaseConfig n vhost { isLocal = false; };
  mkLocalBody = n: vhost: mkBaseConfig n vhost { isLocal = true; };

  mkSite = name: body: { inherit name body; };

  publicNames = n:
    lib.unique ([ n ] ++ lib.optional (cfg.dns.hostnames ? n) cfg.dns.hostnames.${n});

  mkDomainSites = n: vhost: hostName:
    if tlsEnabled then [
      (mkSite "http://${hostName}.${cfg.domain}" "redir https://{host}{uri} permanent")
      (mkSite "${hostName}.${cfg.domain}" (mkHttpsBody n vhost))
    ] else [
      (mkSite "http://${hostName}.${cfg.domain}" (mkHttpBody n vhost))
    ];

  serviceSites = lib.concatLists (lib.mapAttrsToList (n: vhost:
    (lib.optionals (cfg.domain != null) (
      lib.concatMap (mkDomainSites n vhost) (publicNames n)
    ))
    ++ [ (mkSite "http://${n}.local" (mkLocalBody n vhost)) ]
  ) enabledServices);

  landingOn = ing.landing.enable && ing.landing.root != null;
  landingFiles = lib.optionalString landingOn ''
    root * ${toString ing.landing.root}
    file_server
  '';
  landingHttpsBody = ''
    ${tlsDirective}
    ${securityHeaders}
    @blocked not remote_ip ${trustedCidrsStr}
    abort @blocked
    ${landingFiles}
  '';
  landingHttpLanBody = ''
    @blocked not remote_ip ${trustedCidrsStr}
    abort @blocked
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
    ++ [ (mkSite "http://home.local" landingFiles) ]
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

  siteNameCounts = lib.foldl' (acc: e:
    acc // { ${e.name} = (acc.${e.name} or 0) + 1; }
  ) {} allSites;
  duplicateSiteNames = lib.sort builtins.lessThan (
    lib.attrNames (lib.filterAttrs (_: c: c > 1) siteNameCounts)
  );

  caddyConfigStr = ''
    {
      ${globalOptions}
    }

  '' + lib.concatMapStrings (e: ''
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
      Service = {
        Type = lib.mkDefault "notify";
        WatchdogSec = lib.mkDefault "60s";
        CPUWeight = lib.mkDefault 400;
        IOWeight = lib.mkDefault 200;
        MemoryMin = lib.mkDefault "64M";
        MemoryLow = lib.mkDefault "128M";
        MemoryHigh = lib.mkDefault "512M";
        MemoryMax = lib.mkDefault "768M";
        OOMScoreAdjust = lib.mkDefault (-500);
        ManagedOOMPreference = lib.mkDefault "avoid";
      };
    };
  };

in lib.mkMerge [
  (lib.mkIf (cfg.enable && ing.enable) {
    assertions = [
      {
        assertion = !(cfg.ingress.tls.acmeHost != null && cfg.ingress.tls.certFile != null);
        message = "[mediNix] Do not set both acmeHost and certFile.";
      }
      {
        assertion = cfg.ingress.tls.mode != "custom" || (cfg.ingress.tls.certFile != null && cfg.ingress.tls.keyFile != null);
        message = "[mediNix] Custom TLS needs certFile and keyFile.";
      }
      {
        assertion =
          cfg.ingress.auth.mode != "forward-auth"
          || cfg.pocketId.enable
          || (cfg.ingress.authProxyPresent && cfg.ingress.auth.forwardAuthUpstream != "");
        message = "[mediNix] forward-auth needs Pocket ID or a non-empty forwardAuthUpstream.";
      }
      {
        assertion = ingressMode != "global" || config.services.caddy.enable;
        message = "[mediNix] ingress.mode = global requires services.caddy.enable.";
      }
      {
        assertion = duplicateSiteNames == [];
        message = "[mediNix] Duplicate Caddy site hostnames: ${lib.concatStringsSep ", " duplicateSiteNames}";
      }
    ];

    services.caddy.globalConfig = lib.mkIf useGlobal globalOptions;

    services.caddy.virtualHosts = lib.mkIf useGlobal (
      lib.listToAttrs (map (e: {
        name = e.name;
        value = { extraConfig = e.body; };
      }) allSites)
    );

    environment.etc."caddy-media/Caddyfile" = lib.mkIf (!useGlobal) {
      text = caddyConfigStr;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf (!useGlobal && cfg.hostIntegration.firewall == "managed")
      (if tlsEnabled then [ 80 443 ] else [ 80 ]);
    networking.firewall.allowedUDPPorts = lib.mkIf (!useGlobal && cfg.hostIntegration.firewall == "managed" && tlsEnabled)
      [ 443 ];
  })

  (lib.mkIf (cfg.enable && ing.enable && !useGlobal) caddyStandalone)

  (lib.mkIf (cfg.enable && ing.enable && ing.tls.acmeHost != null) {
    users.groups.caddy = {};
    security.acme.certs.${ing.tls.acmeHost}.reloadServices =
      if useGlobal then [ "caddy.service" ] else [ "caddy-media.service" ];
  })

  (lib.mkIf (cfg.enable && ing.enable && !useGlobal && ing.tls.acmeHost != null) {
    users.users.caddy-media.extraGroups = [ "caddy" ];
  })
]
