/*
  51-ingress — MASTER CHANGE PLAN
  =================================

  Stand: 2026-09-01

  Zweck
  -----
  Zentrale Änderungsdatei für die komplette Ingress-/Edge-Welle.

  Betroffene Module:
    511-caddy.nix
    512-pocket-id.nix
    513-cloudflare-dns.nix
    514-acme.nix
    515-mdns.nix

  Nicht Bestandteil dieser Welle:
    518-landingpage.nix  (bereits separat umgesetzt)
    554-feishin.nix      (umgeht die 511-Engine weiterhin)
    skipPaths            (Option vorhanden, Templates nutzen sie noch nicht)
    Geo / rate_limit / Sablier / OAuth2-Proxy / CrowdSec-Caddy-Plugin
    HSTS preload

  Leitbild
  --------
  51-ingress besitzt genau EINE logische Ingress-Wahrheit.

      511 = Engine / Routing / Policy
      512 = Identity Provider
      513 = DNS-Reconciliation
      514 = Zertifikate
      515 = mDNS / Avahi

  Die Module bleiben getrennt. Die Verzahnung erfolgt ausschließlich über
  deklarative Verträge / bestehende Registry- und Ingress-Optionen.

  Chameleon:
      auto:
        services.caddy.enable == true
          -> bestehende NixOS-Caddy-Instanz verwenden
        services.caddy.enable == false
          -> hardened caddy-media-Instanz erzeugen

      global:
        -> services.caddy muss existieren; Konfiguration wird injiziert

      standalone:
        -> caddy-media wird unabhängig vom globalen Caddy erzeugt

  WICHTIGE SEMANTIK:
      Das System "findet" keinen beliebigen laufenden Caddy-Prozess.
      Es hängt sich nicht dynamisch an irgendeinen Prozess an.
      "Global" bedeutet ausdrücklich die NixOS-managed
      services.caddy-Instanz.

  Architekturregeln
  -----------------
    1. 511 bleibt alleinige Caddy-Engine.
    2. 512/513/514/515 implementieren keine parallele Caddy-Konfiguration.
    3. Eine gemeinsame allSites-Liste wird für Global und Standalone verwendet.
    4. Service-Namen kommen aus der Registry / ingress.vhosts-Welt.
    5. DNS-Ownership, HTTP-VHost-Ownership, ACME-Domain und mDNS-Name
       bleiben logisch getrennte Konzepte.
    6. Secrets werden nicht in normale Service-Gruppen vererbt.
    7. Jede Reconciliation bleibt idempotent.
    8. Keine Änderung darf die Chameleon-Eigenschaft wieder aufbrechen.
*/


changes = {

  /*
    --------------------------------------------------------------------------
    511-caddy.nix — CHAMELEON ENGINE
    --------------------------------------------------------------------------

    STATUS:
      Hauptteil bereits als 511-caddychangelog erarbeitet.
      Nachfolgend die konsolidierte Zieldefinition inklusive offener Punkte.
  */

  "511-caddy.nix" = {

    priority = "P0/P1/P2";

    keep = [
      "stock pkgs.caddy ohne CrowdSec-Caddy-Plugin"
      "auto_https off"
      "Lego/ACME ausschließlich über 514"
      "Cloudflare bleibt DNS-only; keine trusted_proxies für Cloudflare"
      "gemeinsame allSites-Liste für Global und Standalone"
      "caddyClass/accessGroup Templates"
      ".local als bewusstes HTTP-LAN-Fallback"
      "Wildcard-Catch-all mit abort"
      "X-Real-IP / X-Forwarded-* explizit setzen"
      "TLS über vorhandene Zertifikatsdateien"
      "HTTP/3 über UDP 443 im Standalone-Firewall-Pfad"
      "ACME-Reload abhängig von der tatsächlichen Caddy-Unit"
    ];

    p0 = [
      /*
        Syntaxfehler korrigieren.

        AKTUELL:
          cfg.dns.hostnames ? ${n}

        ZIEL:
          cfg.dns.hostnames ? n

        ${n} ist hier keine gültige Nix-Variable-Interpolation.
      */
      "publicNames-Prüfung syntaktisch korrekt machen"
    ];

    p1 = [
      /*
        Forward-auth-Vertrag eindeutig machen.

        Die aktuelle Assertion akzeptiert:
          Pocket-ID ODER authProxyPresent

        mkBaseConfig fällt jedoch bei leerem forwardAuthUpstream
        auf Pocket-ID zurück.

        Ziel:
          - lokaler Pocket-ID-Provider:
              forwardAuthUpstream leer -> Pocket-ID
          - externer Provider:
              authProxyPresent true UND forwardAuthUpstream explizit gesetzt
          - keine stille Fallback-Überraschung
      */
      "forward-auth Provider-Vertrag explizit und widerspruchsfrei machen",

      /*
        Vor lib.listToAttrs global sicherstellen, dass kein Hostname doppelt
        vergeben wird. Gleiche Hostnamen aus Service, Alias, Landing und
        Catch-all dürfen nicht still gegeneinander arbeiten.
      */
      "globale Hostname-/VHost-Kollisionen vor listToAttrs validieren",

      /*
        Chameleon-Vertrag explizit dokumentieren:
        auto bezieht sich auf config.services.caddy.enable, nicht auf
        Prozess-Erkennung.
      */
      "auto/global/standalone-Semantik explizit dokumentieren",

      /*
        Pocket-ID:
        accessGroup=idp ist bewusst ohne Auth, damit forward_auth keinen
        Deadlock erzeugt. Das WAN-Exposure des IDP muss daher eine bewusste
        Policy sein und darf nicht versehentlich entstehen.
      */
      "Pocket-ID-VHost-Exposure als explizite Policy absichern/validieren"
    ];

    p2 = [
      "trustedCidrs als bewusste Policy-Grenze dokumentieren",
      "X-Forwarded-For-Semantik dokumentieren: Caddy ist im DNS-only-Modell der erste vertrauenswürdige HTTP-Proxy",
      "HSTS includeSubDomains nur unter klarer Ownership-Annahme des Parent-Namespace verwenden",
      "skipPaths entweder später an Templates anbinden oder bewusst als noch ungenutzte Option markieren",
      "Avahi-Konfiguration nicht parallel zu 515 duplizieren",
      "Runtime-Validierung für Global/Standalone/TLS/ACME durchführen"
    ];

    validation = [
      "nix flake check",
      "NixOS evaluation",
      "Global mit services.caddy.enable=true",
      "Standalone mit services.caddy.enable=false",
      "explizit global",
      "explizit standalone",
      "tls.mode=off ohne acmeHost",
      "acmeHost gesetzt bei tls.mode=off",
      "custom TLS",
      "internal TLS",
      "forward-auth mit Pocket-ID",
      "forward-auth mit externem authProxy",
      "accessGroup=none",
      "unbekannter Hostname -> abort",
      ".local -> kein TLS, kein Auth, kein Abort",
      "Caddyfile mit caddy validate prüfen"
    ];
  };


  /*
    --------------------------------------------------------------------------
    512-pocket-id.nix — IDENTITY PROVIDER
    --------------------------------------------------------------------------
  */

  "512-pocket-id.nix" = {

    priority = "P1/P2";

    keep = [
      "Pocket-ID als eigenständiges Modul"
      "lokaler Bind auf 127.0.0.1"
      "Port aus Registry"
      "systemd-Härtung über service-factory"
      "RestrictNetworkInterfaces=lo"
      "eigener Service-User"
      "Pocket-ID nicht direkt über Port 5120 ins WAN exponieren"
      "Ingress-Registrierung über medinix.ingress.vhosts"
      "accessGroup=idp"
    ];

    p1 = [
      /*
        Das ist der eigentliche Vertrag zu 511.

        512 liefert:
          Service + Port + vhost + idp-Klasse

        511 entscheidet:
          Wie dieser Dienst über Caddy veröffentlicht wird.
      */
      "Ingress-Contract zwischen Pocket-ID und 511 explizit dokumentieren",

      /*
        forward-auth aktiviert Pocket-ID derzeit indirekt über active.
        Das kann als Convenience bleiben, muss aber mit der 511-Assertion
        konsistent sein.
      */
      "Pocket-ID-Aktivierung und forward-auth-Abhängigkeit widerspruchsfrei machen",

      /*
        idp darf nicht selbst forward_auth erhalten, sonst entsteht:
          Caddy -> Pocket-ID -> Caddy forward_auth -> Pocket-ID -> ...
      */
      "accessGroup=idp ausdrücklich als Deadlock-Schutz festhalten",

      /*
        Prüfen, ob pocket-id.domain öffentlich erreichbar sein darf.
        Wenn nicht, muss die Begrenzung deklarativ im Ingress-Vertrag erfolgen,
        nicht durch einen zweiten manuellen Caddy-Block.
      */
      "Exposure des idp-VHosts ausdrücklich entscheiden und deklarieren"
    ];

    p2 = [
      "512 darf keine TLS-, DNS- oder Caddyfile-Logik übernehmen",
      "512 darf nicht selbst services.caddy.virtualHosts manipulieren",
      "Registry bleibt Quelle für Port/UID",
      "Caddy erhält ausschließlich den für Proxying nötigen Zugriff"
    ];
  };


  /*
    --------------------------------------------------------------------------
    513-cloudflare-dns.nix — DNS RECONCILIATION
    --------------------------------------------------------------------------
  */

  "513-cloudflare-dns.nix" = {

    priority = "P1/P2";

    keep = [
      "513 bleibt DNS-Organ von 511, nicht HTTP-Proxy",
      "wan.<zone> als WAN-Anker",
      "lan.<zone> als LAN-Anker",
      "*.<zone> -> wan.<zone>",
      "<zone> -> wan.<zone>",
      "proxied=false",
      "keine per-service-CNAME-Inventarliste mehr",
      "idempotente Reconciliation",
      "fremde DNS-Records nicht anfassen",
      "_acme-challenge nicht anfassen",
      "Credential-Priorität konsistent zu 514"
    ];

    p1 = [
      /*
        513 darf nicht aus einer eigenen, zweiten Service-Inventarliste
        ableiten, welche Namen existieren.

        Die Menge der mediNix-Dienste soll aus der bereits vorhandenen
        Registry-/Ingress-Welt abgeleitet werden.
      */
      "DNS-Service-Namensquelle an Registry/Ingress-Vertrag anbinden",

      /*
        Wichtig: DNS-Ownership ist nicht identisch mit VHost-Ownership.
        Ein DNS-Name kann existieren, ohne dass 511 ihn serviert.
      */
      "DNS-Ownership und HTTP-VHost-Ownership ausdrücklich getrennt halten",

      /*
        Pruning darf nur Namen entfernen, die 513 nachweislich selbst
        besitzt. Keine generische Zonenbereinigung.
      */
      "Prune-Scope hart auf mediNix-eigene Hostnamen begrenzen"
    ];

    p2 = [
      "wan/lan/wildcard/apex als deklarierte Record-Menge dokumentieren",
      "keinen Split-Horizon-Mechanismus in Cloudflare einführen",
      "Cloudflare nicht als Firewall betrachten",
      "LAN-Zugriff weiterhin über Caddy accessGroup/internal erzwingen",
      "Early-Exit darf keinen notwendigen Reconcile-Schritt überspringen",
      "Token-Fallback nur als expliziten Fallback behalten"
    ];

    invariant = [
      /*
        Diese vier Records sind das Zielmodell.
      */
      "wan.<zone> A aktuelle WAN-IP",
      "lan.<zone> A aktuelle LAN-IP",
      "*.<zone> CNAME wan.<zone>",
      "<zone> CNAME wan.<zone>"
    ];
  };


  /*
    --------------------------------------------------------------------------
    514-acme.nix — CERTIFICATE AUTHORITY / LEGO
    --------------------------------------------------------------------------
  */

  "514-acme.nix" = {

    priority = "P1/P2";

    keep = [
      "native NixOS ACME / Lego",
      "DNS-01 via Cloudflare",
      "Wildcard *.acmeHost",
      "acmeHost als zentrale Zertifikatsdomäne",
      "Caddy bekommt nur fertige Zertifikatsdateien",
      "Cloudflare Credential Priority konsistent mit 513",
      "eigene cert-Gruppe caddy",
      "LoadCredentialEncrypted für verschlüsselte Credentials",
      "Private Keys nicht in media-Gruppe",
      "Reload nach erfolgreicher Zertifikatserneuerung"
    ];

    p1 = [
      /*
        511 entscheidet, welche Caddy-Unit läuft.
        514 führt lediglich den von 511 vorgegebenen Reload-Vertrag aus.
      */
      "reloadServices als expliziten Vertrag zwischen 511 und 514 beibehalten",

      /*
        Global:
          caddy.service

        Standalone:
          caddy-media.service
      */
      "global -> caddy.service und standalone -> caddy-media.service eindeutig festlegen",

      /*
        Keine Vermischung der ACME-Zertifikatslogik mit Caddy-ACME.
      */
      "Caddy niemals wieder eigene ACME-Verantwortung geben"
    ];

    p2 = [
      "users.groups.caddy unabhängig von services.caddy.enable bereitstellen",
      "caddy-media bei acmeHost über extraGroups=[caddy] leseberechtigen",
      "group=media nicht für private TLS-Keys verwenden",
      "Plain-Token-Fallback als weniger gehärteten Fallback dokumentieren",
      "acmeHost und TLS-Modus als gemeinsame Ingress-Semantik dokumentieren"
    ];

    invariant = [
      "tls.mode=off darf acmeHost nicht deaktivieren",
      "acmeHost => TLS-Dateien für 511",
      "kein HTTP-01",
      "kein Port-80-Requirement für die Zertifikatsbeschaffung"
    ];
  };


  /*
    --------------------------------------------------------------------------
    515-mdns.nix — mDNS / AVAHI
    --------------------------------------------------------------------------
  */

  "515-mdns.nix" = {

    priority = "P2";

    keep = [
      "515 bleibt mDNS-/Avahi-Modul",
      "{service}.local",
      "home.local",
      "IPv4-LAN-IP-Ermittlung",
      "Registry als Quelle für aktivierte Services"
    ];

    p2 = [
      /*
        Zielarchitektur:
          511 bestimmt die logische Menge der erreichbaren Service-Namen.
          515 bestimmt ausschließlich die mDNS-Veröffentlichung.
      */
      "mDNS-Namensmenge aus dem gemeinsamen Ingress-/Registry-Vertrag ableiten",

      /*
        Aktuell konfigurieren 511 und 515 teilweise beide Avahi.
        Funktional ist das durch Nix-Merge möglich, architektonisch aber
        doppelte Ownership.
      */
      "Avahi-Ownership eindeutig bei 515 bündeln",

      /*
        511 darf nicht selbst zum zweiten mDNS-Modul werden.
      */
      "511 auf die Ingress-Seite beschränken; 515 veröffentlicht mDNS",

      "IPv4-first-Verhalten bewusst dokumentieren"
    ];

    invariant = [
      ".local bleibt HTTP",
      ".local erhält keinen HSTS-Header",
      ".local erhält standardmäßig keinen forward_auth",
      ".local erhält keinen WAN-abort",
      "home.local zeigt auf dieselbe Landingpage wie der Apex, sofern 518 aktiv ist"
    ];
  };


  /*
    --------------------------------------------------------------------------
    MODULÜBERGREIFENDE VERTRÄGE
    --------------------------------------------------------------------------
  */

  "contracts" = {

    chameleon = {
      owner = "511-caddy.nix";

      auto = [
        "services.caddy.enable=true -> globale NixOS-Caddy-Instanz",
        "services.caddy.enable=false -> caddy-media"
      ];

      explicit = [
        "mode=global -> services.caddy muss aktiviert sein",
        "mode=standalone -> caddy-media wird erzeugt"
      ];

      prohibition = [
        "Keine Runtime-Erkennung beliebiger Caddy-Prozesse",
        "Keine zweite Caddy-Instanz neben dem gewählten Chameleon-Pfad"
      ];
    };

    serviceDiscovery = {
      source = "Registry / medinix.ingress.vhosts";

      consumers = [
        "511 Caddy"
        "513 DNS"
        "515 mDNS"
        "518 Landingpage"
      ];

      rule = [
        "Keine parallelen, hart codierten Service-Inventare"
      ];
    };

    hostnameOwnership = {
      dns = "513";
      http = "511";
      certificate = "514";
      mdns = "515";
      content = "518";

      rule = [
        "Jede Schicht besitzt nur ihre eigene Verantwortung"
      ];
    };

    authentication = {
      idp = "512";
      enforcement = "511";

      rule = [
        "512 stellt Pocket-ID bereit",
        "511 entscheidet wann forward_auth angewendet wird",
        "idp selbst darf nicht durch dieselbe forward_auth-Kette geschützt werden"
      ];
    };

    certificates = {
      provider = "514";
      consumer = "511";

      rule = [
        "514 beschafft und erneuert",
        "511 liest",
        "511 startet keinen ACME-Client"
      ];
    };

    dns = {
      provider = "513";
      policy = "511";

      rule = [
        "513 sorgt für Erreichbarkeit der Namen",
        "511 entscheidet über tatsächlichen Zugriff",
        "Cloudflare proxied=false"
      ];
    };

    mdns = {
      publisher = "515";
      source = "Registry / Ingress";

      rule = [
        "515 publiziert Namen",
        "511 verarbeitet HTTP"
      ];
    };
  };


  /*
    --------------------------------------------------------------------------
    AUSDRÜCKLICH NICHT ZUSAMMENLEGEN
    --------------------------------------------------------------------------
  */

  "do_not_merge" = [

    "511 + 512: getrennt lassen; Engine und IdP sind unterschiedliche Verantwortungen"
    "511 + 513: DNS ist nicht Reverse Proxy"
    "511 + 514: Zertifikatsbeschaffung ist nicht Caddy"
    "511 + 515: mDNS ist nicht HTTP-Ingress"
    "513 + 514: DNS-Reconciliation und ACME bleiben getrennte Lebenszyklen"
    "514 + 515: Zertifikate und mDNS haben keine gemeinsame Ownership"
  ];


  /*
    --------------------------------------------------------------------------
    ZIELZUSTAND
    --------------------------------------------------------------------------
  */

  "target_state" = {

    flow = ''
      Client
        |
        v
      DNS (513)
        |
        v
      Caddy (511 / Chameleon)
        |
        +--> TLS certs from ACME/Lego (514)
        |
        +--> forward_auth --> Pocket-ID (512)
        |
        +--> service registry targets
        |
        +--> .local / mDNS names published by 515
    '';

    properties = [
      "Eine Caddy-Engine",
      "Eine Site-Liste",
      "Eine Registry als Service-Wahrheit",
      "Keine Caddy-Plugins",
      "ACME außerhalb von Caddy",
      "DNS-only Cloudflare",
      "LAN-HTTPS über echtes öffentlich signiertes Wildcard-Zertifikat",
      ".local nur als HTTP-LAN-Fallback",
      "idempotente DNS-Reconciliation",
      "expliziter Auth-Contract",
      "expliziter Chameleon-Contract",
      "klar getrennte Ownership"
    ];
  };


  /*
    --------------------------------------------------------------------------
    ABNAHME / TESTMATRIX
    --------------------------------------------------------------------------
  */

  "acceptance_tests" = [

    /*
      Build / Evaluation
    */
    "nix flake check",
    "NixOS evaluation ohne warnings/errors durch neue Contracts",

    /*
      Chameleon
    */
    "global + services.caddy.enable=true",
    "standalone + services.caddy.enable=false",
    "auto mit globalem Caddy",
    "auto ohne globalen Caddy",
    "explizit global",
    "explizit standalone",

    /*
      TLS
    */
    "acmeHost gesetzt + tls.mode=off",
    "custom TLS",
    "internal TLS",
    "TLS aus ohne acmeHost",

    /*
      Auth
    */
    "forward-auth + Pocket-ID",
    "forward-auth + externer authProxy",
    "idp bleibt ohne eigene forward_auth-Kette",
    "localBypass funktioniert",

    /*
      Routing
    */
    "stream",
    "internal",
    "public",
    "idp",
    "none",
    "Alias",
    "zweiter dns.hostname",
    "unbekannter Hostname -> abort",

    /*
      DNS
    */
    "wan/lan/wildcard/apex korrekt",
    "Reconcile bei unveränderter IP",
    "Reconcile nach WAN-IP-Wechsel",
    "Reconcile nach LAN-IP-Wechsel",
    "fremde Records bleiben unangetastet",
    "mediNix-Service-CNAMEs werden sauber entfernt",

    /*
      ACME
    */
    "Wildcard-Zertifikat wird erneuert",
    "globaler Reload -> caddy.service",
    "standalone Reload -> caddy-media.service",
    "caddy-media kann Private Key lesen",

    /*
      mDNS
    */
    "service.local wird publiziert",
    "home.local wird publiziert",
    "keine doppelte Avahi-Ownership",

    /*
      Runtime
    */
    "caddy validate für generiertes Standalone-Caddyfile",
    "LAN HTTPS liefert Lego-Wildcard",
    "WAN -> internal VHost wird vor Backend-Zugriff abgebrochen",
    ".local bleibt HTTP",
    "HTTP -> HTTPS Redirect bei TLS",
    "HTTP/3 UDP 443 im Standalone-Modus"
  ];
};


/*
  ENTSCHEIDUNG
  -----------
  Diese Datei ist ein MASTER-PLAN, keine direkte Ersatzdatei für die Module.

  Reihenfolge der Umsetzung:
    1. 511 P0
    2. 511 P1 + 512 Contract
    3. 513 Ownership/Prune-Contract
    4. 514 Reload/Credential-Contract
    5. 515 Avahi-Ownership
    6. komplette Acceptance-Matrix
    7. erst danach P2-Härtung / Aufräumarbeiten

  Wichtig:
    Keine der Änderungen soll 518 oder das bestehende Chameleon-Modell
    unnötig neu erfinden. Die vorhandene Architektur wird konsolidiert,
    nicht ersetzt.
*/
