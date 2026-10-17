# ---
# id: "511-caddy"
# title: "Caddy Chameleon Ingress — Manifest-driven Reverse Proxy (Dual-Mode & Split-Horizon)"
# domain: 51
# folder: 51-ingress
# status: active
# last_reviewed: 2026-10-13
# provides: ["caddy", "ingress"]
# requires: ["lib/derive", "lib/ingress-access", "lib/service-factory"]
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
  ia = import ../lib/ingress-access.nix { inherit lib; };

  # Global (Host-Caddy) oder standalone (caddy-media)? Die Logik lebt in
  # lib/ingress-access.nix, weil 516 daraus die Journal-Unit ableitet.
  useGlobal = ia.useGlobalOf ing.mode config.services.caddy.enable;

  # EIN Produzent für die Exposure — jetzt wirklich geteilt: die Aufloesung lebt
  # in lib/ingress-access.nix und wird von 511 (Rendering), 513 (DNS) und 518
  # (Tiles) importiert. Vorher stand sie nur hier, waehrend 513/518 das Manifest
  # direkt lasen — der Override divergierte still (F2: LAN-Client spooft
  # Host-Header und kommt ohne Login rein; 513 publizierte sogar fuer
  # accessGroup = "none" einen Record).
  accessGroupOf = ia.accessGroupOf cfg;

  # Ack fuer einen bewusst unauthentifizierten public-vHost. Aufloesung wie
  # `accessGroup` und `landing`: der Vhost-Override GEWINNT, `null` = das
  # Manifest entscheidet.
  # Vorher war es ein ODER aus Manifest und Vhost. Das war monoton in die
  # falsche Richtung: eine Manifest-Ack liess sich vom Host nicht widerrufen
  # (`vhosts.<n>.allowUnauthenticated = false` war ein No-op), eine geerbte Ack
  # oeffnete also still. Jetzt gilt: eine verlorene Ack bricht den Build
  # (fail-closed), ein explizites `false` widerruft das Manifest. Ref: Review 2026-10-17.
  allowUnauthenticatedOf =
    n: m:
    let
      override = cfg.ingress.vhosts.${n}.allowUnauthenticated or null;
    in
    if override != null then override else (m.allowUnauthenticated or false);

  enabledServices = lib.filterAttrs (n: m: m.enable && accessGroupOf n m != "none") (
    config.medinix.manifest or { }
  );

  # Enabled public vhosts that would be WAN-reachable without forward_auth and
  # without an explicit acknowledgement (see assertion below).
  publicWithoutAuth = lib.filterAttrs (
    n: m: accessGroupOf n m == "public" && !allowUnauthenticatedOf n m
  ) enabledServices;

  # Enabled public vhosts that carry an auth-bypass path list.
  publicBypassPaths = lib.filterAttrs (
    n: m:
    accessGroupOf n m == "public"
    && (m.unauthenticatedPaths or [ ]) != [ ]
    && !allowUnauthenticatedOf n m
  ) enabledServices;

  # Declared-but-unresolvable vhosts in ingress.vhosts (RT-5/F7 loud instead of silently dead)
  unresolvedVhosts = lib.filter (n: !(enabledServices ? ${n})) (
    lib.attrNames (
      lib.filterAttrs (n: _: accessGroupOf n (config.medinix.manifest.${n} or { }) != "none") (
        cfg.ingress.vhosts or { }
      )
    )
  );

  inherit (ing) trustedCidrs;
  trustedCidrsStr = builtins.concatStringsSep " " trustedCidrs;

  # Definition in lib/ingress-access.nix (Duplikat mit 518 aufgeloest).
  tlsEnabled = ia.tlsEnabledOf ing;

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

  # request_header: Strip client-supplied identity headers on EVERY route.
  # R19: die Liste MUSS ein Superset von copy_headers sein — Caddy reicht sonst
  # ALLE uebrigen Client-Header an den Upstream durch, und ein Dienst, der z. B.
  # X-Forwarded-User oder X-WEBAUTH-USER vertraut, waere aus dem WAN spoofbar.
  # Der Check mediNix-ingress-header-strip-superset haelt beide Listen gleich.
  #
  # Scope: der Strip steht seit Review 2026-10-17 am ANFANG jedes `route`-Blocks,
  # nicht mehr nur im `authBlock`. Vorher bekamen stream/idp/.lan und
  # public+allowUnauthenticated KEINEN Strip — ein Dienst, der dort einem
  # Identitaets-Header vertraut (genau das Bedrohungsmodell unten), war aus dem
  # WAN spoofbar. Die Reihenfolge request_header < forward_auth bleibt erhalten
  # (Check mediNix-ingress-header-strip prueft sie per Zeilennummer).
  stripAuthHeaders = lib.concatMapStrings (h: "request_header -${h}\n") [
    "Remote-User"
    "Remote-Email"
    "Remote-Groups"
    "X-Auth-Request-User"
    "X-Auth-Request-Email"
    "X-Auth-Request-Groups"
    "X-Auth-Request-Preferred-Username"
    "X-Auth-Request-Access-Token"
    "X-Forwarded-User"
    "X-Forwarded-Email"
    "X-Forwarded-Groups"
    "X-Forwarded-Preferred-Username"
    "X-Forwarded-Access-Token"
    "X-Remote-User"
    "X-WEBAUTH-USER"
    "Proxy-Authorization"
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
        && !allowUnauthenticatedOf name m;
      skipPaths = unauthenticatedPathsOf m;
      skipMatcher = lib.optionalString (needsAuth && skipPaths != [ ]) ''
        @needAuth not path ${lib.concatStringsSep " " skipPaths}
      '';
      authBlock = lib.optionalString needsAuth ''
        ${skipMatcher}
        forward_auth ${lib.optionalString (skipPaths != [ ]) "@needAuth "}${ing.auth.forwardAuthUpstream} {
          uri ${ing.auth.forwardAuthUri}
          copy_headers Remote-User Remote-Email Remote-Groups \
                       X-Auth-Request-User X-Auth-Request-Email
        }
      '';
      # ADR-517: der Login-/Callback-Endpunkt des Auth-Proxy muss VOR jedem
      # `forward_auth` erreichbar sein, sonst kann der Browser nie einloggen
      # (Deadlock: ohne Login kein /oauth2/*, ohne /oauth2/* kein Login).
      # Caddy sortiert `handle` vor `route` ein; der Pfad wird NICHT gestrippt -
      # oauth2-proxy erwartet seinen eigenen `proxyPrefix` (/oauth2).
      oauth2Block = lib.optionalString (needsAuth && ing.auth.forwardAuthUpstream != "") ''
        handle /oauth2/* {
          reverse_proxy ${ing.auth.forwardAuthUpstream}
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
      ${oauth2Block}
      route {
        ${stripAuthHeaders}
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

  # 2. Externe WAN-VHosts: public, stream und idp.
  wanServices = lib.filterAttrs (n: m: ia.isWan (accessGroupOf n m)) enabledServices;

  # 2b. `internal`: KEIN WAN-Dienst, aber ein TLS-Hostname mit CIDR-Abort.
  # Vorher blieb `internal` rein auf `.lan` — damit war der dokumentierte
  # Pocket-ID-Bootstrap unmoeglich: Passkey-Registrierung braucht einen Secure
  # Context, und `http://pocket-id.lan` ist keiner (510-ingress-SERVICE.md und
  # 512-pocket-id.nix versprechen beide HTTPS auf {name}.{domain} + Abort).
  # Der Guard in 512 (setupCompleted) haette den Admin sonst in eine Sackgasse
  # geschickt. `mkServiceBlock … { isLocal = true; }` liefert genau das:
  # lanAbort (trustedCidrs) statt forward_auth, kein Strip-Bypass.
  # Nur mit tlsEnabled — ohne TLS gibt es keinen Secure Context, dann bleibt
  # `internal` bewusst auf `.lan`. Ref: Review 2026-10-17, Finding 14.
  internalServices = lib.filterAttrs (n: m: accessGroupOf n m == "internal") enabledServices;

  internalSites = lib.optionals (domain != null && tlsEnabled) (
    lib.concatLists (
      lib.mapAttrsToList (
        n: m:
        lib.concatMap (hostName: [
          (mkSite "http://${hostName}.${domain}" "redir https://{host}{uri} permanent")
          (mkSite "${hostName}.${domain}" ''
            ${tlsDirective}
            ${securityHeaders}
            ${mkServiceBlock n m { isLocal = true; }}
          '')
        ]) (publicNames n)
      ) internalServices
    )
  );

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
    # WAN-Apex-Landing nur auf ausdruecklichen Wunsch (Review Finding 10): sie ist
    # unauthentifiziert und ohne CIDR-Abort und listet jeden stream-/public-Dienst
    # mit Hostnamen. `dashboard.lan` oben (LAN, lanAbort) bleibt unabhaengig davon.
    ++ lib.optionals (ing.landing.wanPublic && domain != null && tlsEnabled) [
      (mkSite "http://${domain}" "redir https://{host}{uri} permanent")
      (mkSite domain ''
        ${tlsDirective}
        ${securityHeaders}
        ${landingFiles}
      '')
    ]
    ++ lib.optionals (ing.landing.wanPublic && domain != null && !tlsEnabled) [
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

  allSites = lanSites ++ wanSites ++ internalSites ++ landingSites ++ catchAllSites;

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
    # KEIN mediaGroup: ADR-0000 §4 ist explizit — "Edge ingress (511) and
    # identity (512) never receive GID 5000". 511 serviert keine Medienablage:
    # der Landing-Root kommt aus 518 (pkgs.runCommand -> Nix-Store-Pfad, fuer
    # alle lesbar), alles andere geht per reverse_proxy an den Dienst. Vorher
    # stand hier mediaGroup = true mit einem Kommentar, der §4 als Begruendung
    # zitierte, obwohl §4 genau das verbietet (Review 2026-10-17, Finding 6).
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
        assertion = ing.mode != "global" || config.services.caddy.enable;
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
        # Den Zeichensatz + `/0` + fuehrende Nullen erzwingt bereits der Optionstyp
        # (default.nix). Hier bleibt die SEMANTIK: privates Netz UND sinnvolle
        # Prefix-Grenzen. Vorher pruefte nur ein Praefix-Match (`10\.` …) plus
        # `hasSuffix "/0"` — `10.0.0.0/1` kam damit durch, und `lanAbort`
        # (`not remote_ip …`) haette halb IPv4 in Richtung WAN geoeffnet.
        # Ref: Review 2026-10-17, Finding 4.
        assertion = lib.all (
          c:
          let
            prefix = lib.toInt (lib.last (lib.splitString "/" c));
            # v4: /8 ist das weiteste legitime private Netz (10.0.0.0/8).
            # v6: /7 fuer fc00::/7 (ULA), fe80::/10 und fd00::/8 sind enger.
            minPrefix = if lib.hasInfix ":" c then 7 else 8;
            maxPrefix = if lib.hasInfix ":" c then 128 else 32;
          in
          builtins.match "(10\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|127\\.|169\\.254\\.|100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.|[fF][cCdD][0-9A-Fa-f]{2}:|[fF][eE]80:|::1/).*" c
          != null
          && prefix >= minPrefix
          && prefix <= maxPrefix
        ) trustedCidrs;
        message = "[mediNix/511] trustedCidrs enthält Nicht-Private-Netze oder einen zu weiten Prefix (z. B. /1) — Gefahr der WAN-Freischaltung.";
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
    ]
    ++ (
      let
        # Finding 20 (Review 2026-10-17): `idp` und `stream` sind WAN-offen OHNE
        # Ingress-Auth. `idp` gehoert dem IdP selbst; `stream` nur Diensten, deren
        # Manifest-Eintrag stream deklariert - jede Abweichung braucht die
        # ausdrueckliche Ack `ingress.streamAck`. Geprueft wird die WIRKSAME
        # Zugriffsgruppe (Vhost-Override gewinnt), ueber Manifest UND vhosts.
        names = lib.unique (
          lib.attrNames (config.medinix.manifest or { }) ++ lib.attrNames (cfg.ingress.vhosts or { })
        );
        groupOf = n: accessGroupOf n (config.medinix.manifest.${n} or { });
        declaredOf = n: config.medinix.manifest.${n}.accessGroup or "none";
        idpNames = lib.filter (n: groupOf n == "idp") names;
        unackedStream = lib.filter (
          n: groupOf n == "stream" && declaredOf n != "stream" && !(lib.elem n ing.streamAck)
        ) names;
      in
      [
        {
          assertion = lib.all (n: n == "pocket-id") idpNames;
          message = "[mediNix] accessGroup = \"idp\" is reserved for the IdP itself: ${lib.concatStringsSep ", " idpNames}. Use \"stream\" (app login) or \"public\" + forward_auth.";
        }
        {
          assertion = unackedStream == [ ];
          message = "[mediNix] accessGroup = \"stream\" deviates from the manifest declaration for: ${lib.concatStringsSep ", " unackedStream}. stream is WAN-visible without ingress auth - acknowledge with medinix.ingress.streamAck = [ \"<service>\" ].";
        }
      ]
    );

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

    # Finding 7 (Review 2026-10-17): im Global-Modus haengen wir uns an die
    # HOST-Caddy. Was der Host ueberschreiben koennen muss, steht auf mkDefault.
    # `RuntimeDirectory` bleibt hart: unser Admin-Endpoint zeigt auf
    # `unix//run/caddy/admin.sock` (siehe `adminEndpoint` oben) - biegt der Host
    # das um, laeuft der Socket ins Leere. `auto_https off` in der globalConfig
    # ist ebenfalls funktional (TLS kommt aus 514/ACME), siehe `ingress.mode`.
    systemd.services.caddy = lib.mkIf useGlobal {
      serviceConfig = {
        OOMScoreAdjust = lib.mkDefault (-900);
        RuntimeDirectory = "caddy";
        RuntimeDirectoryMode = lib.mkDefault "0700";
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
