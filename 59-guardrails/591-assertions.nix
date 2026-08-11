# ---
# id: "591-assertions"
# title: "mediNix-core Config Assertions (fail-closed + soft warnings)"
# domain: 50
# folder: 59-guardrails
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-0000, ADR-5043, ADR-5110
# provides: ["assertions"]
# requires: []
# ports: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia;
  ing = cfg.ingress;
  must = assertion: message: { inherit assertion message; };
  warn = assertion: message: { assertion = true; message = "WARN: ${message}"; };
in
{
  config.assertions =
    # ════════════════════════════════════════════════════════════════
    # FAIL-CLOSED: Build bricht ab (assertion = false)
    # ════════════════════════════════════════════════════════════════
    [
      # forward-auth ohne Proxy → Fail-Open-Risk
      (must (!(cfg.authProxyPresent && ing.auth.mode != "forward-auth"))
        "[mediNix-core/AUTH] authProxyPresent=true aber ingress.auth.mode != 'forward-auth'. Setze auth.mode='forward-auth' oder authProxyPresent=false.")

      # usenet-confinement ohne vpn.dns → kein DNS im Tunnel
      (must (!(cfg.services.sabnzbd.usenet-confinement.enable && cfg.vpn.dns == [ ]))
        "[mediNix-core/VPN] usenet-confinement.enable=true aber vpn.dns ist leer. Setze cfg.vpn.dns (z.B. [\"10.8.0.1\"]).")

      # tls.mode=custom ohne certFile/keyFile
      (must (!(ing.tls.mode == "custom" && (ing.tls.certFile == null || ing.tls.keyFile == null)))
        "[mediNix-core/TLS] tls.mode='custom' erfordert certFile UND keyFile.")

      # acmeHost UND certFile → doppelte Quelle
      (must (!(ing.tls.acmeHost != null && ing.tls.certFile != null))
        "[mediNix-core/TLS] Entweder ingress.tls.acmeHost ODER ingress.tls.certFile setzen, nicht beides.")

      # acmeHost aber Host hat security.acme nicht konfiguriert
      (must (!(ing.tls.acmeHost != null && !config.security.acme.certs ? ${ing.tls.acmeHost or ""}))
        "[mediNix-core/TLS] acmeHost='${ing.tls.acmeHost or "null"}' gesetzt, aber security.acme hat kein Zertifikat. Host muss security.acme (DNS-01 via Cloudflare) konfigurieren.")

      # DDNS aktiv ohne Token
      (must (!(cfg.services.cloudflare-dns.enable && cfg.secrets.cloudflareTokenFile == null))
        "[mediNix-core/DDNS] cloudflare-dns.enable=true aber secrets.cloudflareTokenFile ist null. Token-Pfad setzen.")

      # internal-Klasse darf nicht WAN-exposed sein
      (must (!(cfg.caddyClassInternalWan or false))
        "[mediNix-core/INGRESS] Internal-Dienste dürfen nicht WAN-exposed sein (ADR-5110).")
    ]
    # ════════════════════════════════════════════════════════════════
    # SOFT WARNINGS: Build läuft, nur Hinweis (assertion = true, message=WARN)
    # ════════════════════════════════════════════════════════════════
    ++ lib.optionals (cfg.services.jellyfin.enable && ing.tls.mode == "off") [
      (warn true "[mediNix-core/TLS] stream-Dienst Jellyfin aktiv aber tls.mode='off' — kein HTTPS. Empfohlen: acmeHost oder custom setzen.")
    ]
    ++ lib.optionals cfg.services.sonarr.enable [
      # .NET-EOL: nixpkgs liefert EOL-.NET → Host muss permittedInsecurePackages setzen
      (warn (lib.versionAtLeast (lib.getVersion pkgs.dotnetRuntime or "0") "8.0"
              || config.nixpkgs.config.permittedInsecurePackages or [] != [])
        "[mediNix-core/SONARR] Sonarr/Radarr laufen auf .NET. Bei EOL-.NET (6.0.x) in nixpkgs: nixpkgs.config.permittedInsecurePackages = [\"aspnetcore-runtime-wrapped-6.0.x\"] setzen (Host-Entscheidung).")
    ];
}
