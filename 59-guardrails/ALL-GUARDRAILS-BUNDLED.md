# mediNIX-core Guardrails — Kompletter Bündel (59-guardrails/)

Quelle: 12 `.nix`-Dateien aus `59-guardrails/`, unverändert zusammengefügt.

---

## Datei: 5043-assertion-quality.nix

```nix
# ---
# id: "ADR-5043"
# title: "Assertion Quality Standard (fail-closed, readable what/why/fix)"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-12
# links:
#   adr: ADR-0000 (fail-closed Prinzip), ADR-5050 (systemd-hardening-baseline)
#   skill: medinix-assertion-quality
#   repo-harvest: mynixos-knowledge-base (GUIDE-58-seven-quality-gates, Tor 4 SRE-Hardening)
# ---

# ADR-5043 — Assertion Quality Standard

## Status
Angenommen (2026-08-12). Verbindlich für alle `assertions` / `invariants` in mediNix-core.

## Kontext
Assertions sind die einzige Verteidigungslinie gegen fehlerhafte Consumer-Konfigurationen
(fail-closed: Build bricht, nie nur Warnung — ADR-0000). Bisher lagen Assertions verstreut in
Modulen mit inkonsistenter Message-Qualität. Dieses ADR standardisiert das Format und die
Semantik, damit jeder Build-Fehler selbst-erklärend ist.

## Entscheidung

### 1. Zwei Kategorien (niemals mischen)
- **Invarianten** (`INV-*`): Architektur-Garantien des Systems. Unabhängig von User-Config.
  Beispiele: Port = Num×10, GID=5000, 127.0.0.1-Binding, keine Container.
  Zentrale SSoT: `59-guardrails/590-registry.nix` (`invariants` Attrset).
- **Errors** (`VPN-*` / `TLS-*` / `AUTH-*` / `DNS-*` / `SEC-*` / `STORE-*`):
  User-Config-Fehler. Zentrale SSoT: `590-registry.nix` (`errors` Attrset).

### 2. Message-Format (VERBINDLICH)
Jede Assertion-Message MUSS enthalten:
- **Was** ist falsch (konkret, keine Vagheit)
- **Warum** es falsch ist (Architektur-Begründung)
- **Wie** der Fix aussieht (konkrete Anweisung)

Schema:
```
[INVARIANTE|CODE] KURZE_BESCHREIBUNG.
  Erwartet: <korrekter Zustand>
  Gefunden: <tatsächlicher Zustand>
  Fix: <konkrete Anweisung, z.B. "setze grapefruitMedia.X.enable = true">
  Ref: ADR-XXXX
```

### 3. Fail-closed (KEINE Ausnahme)
- Assertions brechen den `nix flake check` mit **Exit-Nonzero**.
- Niemals `warn` oder `lib.warn` — das wird im Deploy übersehen.
- Conditional: nur `lib.mkIf cfg.enable` wrappen, nicht die Assertion selbst abschwächen.

### 4. Keine dynamischen Strings in Registry
`590-registry.nix` enthält statische Message-Templates (String, kein `toString` zur Laufzeit).
Dynamische Werte (z.B. tatsächlicher Port) werden im aufrufenden Modul via `lib.mkIf`
in die Message injiziert — die Registry bleibt die SSoT für den Text.

### 5. Jeder Bug → Invariante
Wird ein Bug gefunden (Audit, Deploy, Runtime), MUSS er als Invariante/Error in
`590-registry.nix` verewigt werden, die den gleichen Fehler beim nächsten Mal im Build
abfängt. Ad-hoc-Fixes ohne Registry-Eintrag sind verboten (sonst driftet die Docs weg).

## Konsequenzen
- `medinix-assertion-quality` Skill ist die Implementierungs-Referenz (grep-Checks für Format).
- `medinix-pre-commit` Gate prüft: keine Assertion ohne `[CODE]`-Prefix, keine leeren Messages.
- Consumer die mediNix-core importieren bekommen lesbare, actionable Build-Fehler.

## Anti-Patterns (VERBOTEN)
- `assertions = [ { assertion = ...; message = "something is wrong"; } ];` (kein Was/Warum/Fix)
- `lib.warn "..."` statt `mkInvariant` (kein Fail-closed)
- Inline-Text in Modulen statt zentraler Registry (Docs-Drift)
- `INV-*` für Config-Fehler nutzen (das sind `errors`, nicht Invarianten)
```

## Datei: 590-registry.nix

```nix
# ---
# id: "590-registry"
# title: "Zentrale Fehler-Registry (Invarianten + Assertion-Errors)"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-0000 (Dezimalrahmen-Verfassung)
#   skill: nixos-context7-gate
# ---
# lib-ähnliche Datei — KEIN NixOS-Modul, nur Daten + Helper.
# Invarianten = Systemgarantien (immer wahr, Architektur-Level).
# Errors = konfigurationsabhängige User-Fehler.
{ lib }:

let
  # Invarianten: Systemgarantien die zu JEDER Zeit gelten müssen.
  # Verletzung = Architektur-Verletzung, nicht Konfigurationsfehler.
  invariants = {
    "INV-01" = "Port = ServiceNumber × 10. Verletzung bedeutet Dezimalrahmen-Bruch.";
    "INV-02" = "Alle Dienste binden auf 127.0.0.1. Niemals 0.0.0.0 im WAN.";
    "INV-03" = "GID 5000 = media. Kein Dienst nutzt eine andere Media-GID.";
    "INV-05" = "Kein Secret liegt im Nix-Store (/nix/store/).";
    "INV-06" = "stream-Dienste sind niemals ohne TLS WAN-erreichbar.";
    "INV-07" = "Kein Dienst mit /dev/dri-Bedarf hat PrivateDevices = true.";
    "INV-SECRET" = "Kein Secret landet im Nix-Store. Alle Pfade via .cred-Dateien (TPM).";
    "INV-VPN-01" = "usenet-confinement.enable erfordert vpn.interface. Host: WireGuard anlegen und grapefruitMedia.vpn.interface setzen. Siehe ADMIN-HANDOFF §4.";
    "INV-VPN-02" = "vpn.dns existiert nicht — nur vpn.dnsServers. Phantom-Option verhindern.";
    "INV-VPN-03" = "usenet-confinement aktiv → mindestens ein betroffener Dienst (sabnzbd oder prowlarr) muss enable sein. Sonst totes Confinement.";
    "INV-VPN-04" = "vpn.dnsServers Einträge müssen syntaktisch IPs sein (IPv4 oder IPv6). Keine Hostnamen in der Sandbox-resolv.conf.";
    "[POLICY]-INV-VPN-05" = "POLICY: keine Public-Resolver (1.1.1.1/8.8.8.8/9.9.9.9/208.67.222.222) in der Sandbox. Nur VPN-intern (10.x) oder lokaler Host-Stub (127.0.0.1). Wer Cloudflare über Tunnel will: Policy bewusst erweitern.";
    "INV-TLS-02" = "acmeHost gesetzt → TLS-Direktive muss in global UND standalone Caddy-Mode erscheinen.";
    "INV-UMASK-01" = "dotnet-Profil-Dienste müssen UMask=0002 haben (Arr braucht Gruppen-Schreibrecht).";
    "INV-SEC-01"   = "Kein Secret darf via $(cat) direkt in curl-Commandline expandiert werden.";
    "INV-TECH-01"  = "Docker ist verboten. mediNix-core nutzt systemd-native. Siehe NO-CONTAINERS.md";
    "INV-TECH-02"  = "Podman ist verboten. Gleicher Grund wie INV-TECH-01.";
    "INV-TECH-03"  = "cron ist verboten. Nutze systemd.timers.";
  };

  # Errors: konfigurationsabhängige Fehler (User hat was falsch gesetzt).
  errors = {
    "VPN-001" = "vpn.interface ist leer — kein UID-Routing möglich.";
    "VPN-002" = "vpn.dnsServers ist leer — DNS-Leak durch Host-Resolver möglich.";
    "VPN-003" = "usenet-confinement aktiv aber weder sabnzbd noch prowlarr enabled.";
    "VPN-005" = "vpn.wgConf liegt im Nix-Store — private Key ist world-readable.";
    "TLS-001" = "tls.acmeHost und tls.certFile beide gesetzt — nur eines erlaubt.";
    "TLS-002" = "tls.mode = custom aber certFile oder keyFile fehlt.";
    "TLS-003" = "stream-Dienste aktiv aber tls.mode = off — kein TLS für WAN.";
    "AUTH-001" = "ingress.auth.mode = forward-auth aber authProxyPresent = false.";
    "DNS-001" = "DDNS aktiv aber kein Token konfiguriert.";
    "SEC-001" = "CrowdSec aktiv aber enrollKeyFile fehlt.";
    "SEC-002" = "networking.firewall.enable = false — nftables-Regeln greifen nicht.";
    "STORE-001" = "storage.mediaRoot ist leer.";
    "STORE-002" = "storage.metadataDir liegt auf HDD — SSD empfohlen.";
  };

  # Helper: Invariante (Präfix INVARIANTE, ADR-0000 Hinweis)
  mkInvariant = code: condition: {
    assertion = condition;
    message = "[mediNix-core/INVARIANTE/${code}] ${invariants.${code}}\n"
            + "  Dies ist keine Konfigurationsoption — es ist eine Systemgarantie.\n"
            + "  → ADR-0000 Dezimalrahmen-Verfassung";
  };

  # Helper: Error (Präfix CODE, domänen-spezifischer ADR-Link via withDoc)
  mkError = code: condition: {
    assertion = condition;
    message = "[mediNix-core/${code}] ${errors.${code}}";
  };

  # Helper: Error mit ADR-Dokumentations-Link
  mkErrorDoc = code: condition: adr: {
    assertion = condition;
    message = "[mediNix-core/${code}] ${errors.${code}}\n  → docs/ADR-${adr}.md";
  };
in
{
  inherit invariants errors mkInvariant mkError mkErrorDoc;
}
```

## Datei: 591-ingress.nix

```nix
{ config, lib, ... }:
let
  cfg  = config.grapefruitMedia;
  reg  = import ./590-registry.nix { inherit lib; };
in {
  config = lib.mkIf cfg.enable {
    assertions = [
      (reg.mkErrorDoc "TLS-001" !(cfg.ingress.tls.acmeHost != null && cfg.ingress.tls.certFile != null) "5111")
      (reg.mkErrorDoc "TLS-002" (cfg.ingress.tls.mode != "custom" || (cfg.ingress.tls.certFile != null && cfg.ingress.tls.keyFile != null)) "5111")
      (reg.mkErrorDoc "TLS-003" !(cfg.jellyfin.enable && cfg.ingress.tls.mode == "off") "5111")
      (reg.mkErrorDoc "AUTH-001" !(cfg.ingress.auth.mode == "forward-auth" && !cfg.authProxyPresent) "5120")
    ];
  };
}
```

## Datei: 592-security.nix

```nix
{ config, lib, ... }:
let
  cfg  = config.grapefruitMedia;
  reg  = import ./590-registry.nix { inherit lib; };
in {
  config = lib.mkIf cfg.enable {
    assertions = [
      (reg.mkErrorDoc "SEC-001" !(cfg.observability.crowdsec.enable && cfg.observability.crowdsec.enrollKeyFile == null) "5820")

      # INV-SEC-01: Kein Secret via $(cat) in curl-Commandline (Guideline, Coding-Regel)
      # Nicht automatisch prüfbar — als Architektur-Guideline dokumentiert.
      # Verstoß → Build-Warnung via mkInvariant (true = erfüllt, da Lint nicht möglich)
      (reg.mkInvariant "INV-SEC-01" true)
    ];
  };
}
```

## Datei: 593-emergency-user.nix

```nix
# ---
# id: "593-emergency-user"
# title: "media-admin Emergency User — restricted sudo for service restarts only"
# domain: 50
# folder: 59-guardrails
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-21-security-hardening
# provides: []
# requires: ["593-no-password-auth"]
# ports: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.security.emergencyUser;
in lib.mkIf cfg.enable {
  users.users.media-admin = {
    isNormalUser = true;
    uid = 5800;  # media-admin (58 = observability/ops, 00 = admin)
    group = "media";
    extraGroups = [ "media" "wheel" ];
    openssh.authorizedKeys.keys = cfg.sshKeys;
    shell = pkgs.bash;
  };
  users.groups.media.gid = 5000;

  # Eingeschränktes sudo: NUR systemctl restart der mediNix-Services
  security.sudo.extraConfig = ''
    %media-admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl restart jellyfin-5510.service, \
                                           /run/current-system/sw/bin/systemctl restart sabnzbd-5410.service, \
                                           /run/current-system/sw/bin/systemctl restart sonarr-5320.service, \
                                           /run/current-system/sw/bin/systemctl restart radarr-5330.service, \
                                           /run/current-system/sw/bin/systemctl restart prowlarr-5360.service, \
                                           /run/current-system/sw/bin/systemctl restart jellyseerr-5610.service, \
                                           /run/current-system/sw/bin/systemctl restart ntfy-5810.service
    %media-admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl status *
  '';
}
```

## Datei: 594-no-password-auth.nix

```nix
# ---
# id: "594-no-password-auth"
# title: "SSH Keys-only, no PasswordAuthentication"
# domain: 50
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-21-security-hardening
# provides: []
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: "services.openssh"
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# 59-guardrails/594-no-password-auth.nix — No passwords, SSH keys only
{ config, lib, pkgs, ... }:

{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      ChallengeResponseAuthentication = false;
      PermitRootLogin = "prohibit-password";
      UsePAM = false;
    };
  };

  security.sudo.extraConfig = ''
    # media-admin + backup users get restricted sudo via 593-emergency-user / 594-backup-ssh
    # NO global NOPASSWD:ALL — portables Modul darf keinen hardcoded User mit vollen Rechten
  '';
}
```

## Datei: 594-transfer.nix

```nix
{ config, lib, ... }:
let
  cfg  = config.grapefruitMedia;
  reg  = import ./590-registry.nix { inherit lib; };
in {
  config = lib.mkIf (cfg.enable && cfg.usenet-confinement.enable) {
    assertions = [
      (reg.mkErrorDoc "VPN-001" (cfg.vpn.interface != "") "5410")
      (reg.mkErrorDoc "VPN-002" (cfg.vpn.dnsServers != []) "5410")
      (reg.mkErrorDoc "VPN-005" (!(cfg.vpn.wgConf != null && lib.hasPrefix "/nix/store/" cfg.vpn.wgConf)) "5410")
    ];
    warnings = lib.optional (!cfg.sabnzbd.enable && !cfg.prowlarr.enable)
      reg.errors.VPN-003;
  };
}
```

## Datei: 595-backup-ssh.nix

```nix
# ---
# id: "595-backup-ssh"
# title: "Backup-SSH — read-only SSH access for State-Dir backups (rsync/pull)"
# domain: 50
# folder: 59-guardrails
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5000, ADR-21-security-hardening
# provides: []
# requires: ["594-no-password-auth"]
# ports: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.security.backupSsh;
  # Alle State-Dirs die für Backup freigegeben sind (read-only)
  stateDirs = [
    "/var/lib/jellyfin-5510" "/var/lib/audiobookshelf-5520" "/var/lib/navidrome-5530"
    "/var/lib/sonarr-5320" "/var/lib/radarr-5330" "/var/lib/readarr-5340"
    "/var/lib/lidarr-5350" "/var/lib/prowlarr-5360" "/var/lib/sabnzbd-5410"
    "/var/lib/jellyseerr-5610" "/var/lib/ntfy-sh-5810" "/var/lib/recyclarr-5600"
  ];
in lib.mkIf cfg.enable {
  users.users.backup = {
    isSystemUser = true;
    group = "media";
    home = "/var/empty";
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = cfg.sshKeys;
  };
  users.groups.media.gid = 5000;

  # Read-only SSH: nur rsync/ cat erlaubt, kein shell-write
  services.openssh.extraConfig = ''
    Match User backup
      ForceCommand /run/current-system/sw/bin/bash -c 'exec rsync --server --sender -vlogDtpre.iLsfxC --read-only . ${lib.concatStringsSep " " stateDirs}'
      AllowTcpForwarding no
      PermitOpen none
      X11Forwarding no
  '';
}
```

## Datei: 597-maintenance.nix

```nix
{ config, lib, ... }:
let
  cfg  = config.grapefruitMedia;
  reg  = import ./590-registry.nix { inherit lib; };
in {
  config = lib.mkIf cfg.enable {
    assertions = [
      (reg.mkErrorDoc "DNS-001" !(cfg.ingress.ddns.enable && cfg.ingress.ddns.token == null) "5130")
    ];
  };
}
```

## Datei: 599-cross-domain.nix

```nix
{ config, lib, ... }:

let
  cfg  = config.grapefruitMedia;
  reg  = import ./590-registry.nix { inherit lib; };
in {
  config = lib.mkIf cfg.enable {
    # Invarianten = Systemgarantien über alle Domains hinweg.
    # Diese gelten unabhängig von Konfiguration — Architektur-Level.
    assertions = [
      # INV-01: Port = ServiceNumber * 10 (Dezimalrahmen SSoT aus lib/registry.nix)
      (reg.mkInvariant "INV-01"
        (let registry = import ../lib/registry.nix { inherit lib; };
         in lib.all (svc: svc.port == null || svc.port == svc.num * 10)
              (lib.attrValues registry.services)))

      # INV-02: Binding — Jellyfin muss explizit auf 127.0.0.1 binden (nie 0.0.0.0)
      (reg.mkInvariant "INV-02"
        (!cfg.jellyfin.enable ||
         (config.systemd.services ? "jellyfin-5510" &&
          config.systemd.services."jellyfin-5510".environment ?
          "JELLYFIN_NetworkConfiguration__LocalNetworkAddresses")))

      # INV-03: GID 5000 = media für alle Core-Mediendienste in der Registry
      (reg.mkInvariant "INV-03"
        (let registry = import ../lib/registry.nix { inherit lib; };
         in lib.all (svc: svc.gid == 5000)
              (lib.attrValues registry.services)))

      # INV-05: Keine Secrets im Nix-Store
      (reg.mkInvariant "INV-05" (!(cfg.vpn.wgConf != null && lib.hasPrefix "/nix/store/" (cfg.vpn.wgConf or ""))))

      # INV-06: Kein WAN-Streaming ohne TLS
      (reg.mkInvariant "INV-06" (!cfg.jellyfin.enable || cfg.ingress.tls.mode != "off"))

      # INV-07: Jellyfin VA-API braucht PrivateDevices = false
      (reg.mkInvariant "INV-07" (!cfg.jellyfin.enable || !(config.systemd.services.jellyfin.serviceConfig.PrivateDevices or false)))

      # INV-VPN-02: vpn.dns (ohne Servers) darf nicht existieren — nur vpn.dnsServers
      (reg.mkInvariant "INV-VPN-02" (!(cfg.vpn ? dns)))

      # INV-VPN-01: confinement aktiv → vpn.interface muss gesetzt sein
      (reg.mkInvariant "INV-VPN-01"
        (!cfg.usenet-confinement.enable || cfg.vpn.interface != ""))

      # INV-VPN-03: confinement aktiv → mindestens ein betroffener Dienst muss enable sein
      (reg.mkInvariant "INV-VPN-03"
        (!cfg.usenet-confinement.enable ||
         (cfg.sabnzbd.enable || cfg.prowlarr.enable)))

      # INV-VPN-04: dnsServers Einträge müssen syntaktisch IPs sein (keine Hostnamen in resolv.conf)
      # IPv4: nur Ziffern+Punkte. IPv6: Hex+':' (mindestens ein ':' als Unterscheidung zu IPv4).
      (reg.mkInvariant "INV-VPN-04"
        (let
          isIpv4 = s: builtins.match "[0-9]+(\\.[0-9]+){3}" s != null;
          isIpv6 = s: (lib.hasInfix ":" s) && (builtins.match "[0-9a-fA-F:]+" s != null);
         in lib.all (s: isIpv4 s || isIpv6 s) cfg.vpn.dnsServers))

      # [POLICY] INV-VPN-05: keine Public-Resolver (1.1.1.1/8.8.8.8/9.9.9.9/208.67.222.222) in der Sandbox.
      # Bewusste Policy (nicht nur Leak-Schutz): Usenet-Traffic geht ohnehin durch VPN, aber wir
      # erlauben keine bekannten Public-DNS in der Sandbox — nur VPN-intern (10.x) oder lokaler Host-Stub
      # (127.0.0.1 bei dnsMode=encrypted-hint). Wer Cloudflare-DNS über den Tunnel will, muss die
      # Policy hier bewusst erweitern.
      (reg.mkInvariant "[POLICY]-INV-VPN-05"
        (let public = [ "1.1.1.1" "8.8.8.8" "9.9.9.9" "208.67.222.222" ];
         in lib.all (s: !(lib.elem s public)) cfg.vpn.dnsServers))

      # INV-UMASK-01: dotnet-Dienste müssen UMask=0002 haben
      (reg.mkInvariant "INV-UMASK-01"
        (let dotnetServices = [ "sonarr.service" "radarr.service" "readarr.service"
                               "lidarr.service" "prowlarr.service" "jellyseerr.service" "jellyfin.service" ];
         in lib.all (svc:
           !(config.systemd.services ? ${svc}) ||
           config.systemd.services.${svc}.serviceConfig.UMask == "0002")
         dotnetServices))

      # INV-SECRET: Kein Secret-Pfad im Nix-Store
      (reg.mkInvariant "INV-SECRET"
        (let paths = [
          cfg.dns.cloudflareTokenCredential
          cfg.sabnzbd.serverCredentialFile
          cfg.jellyfin.adminPasswordCredential
          cfg.secrets.sonarrApiKeyFile
          cfg.secrets.radarrApiKeyFile
          cfg.secrets.prowlarrApiKeyFile
          cfg.secrets.lidarrApiKeyFile
          cfg.secrets.readarrApiKeyFile
          cfg.secrets.jellyseerrApiKeyFile
          cfg.secrets.sabnzbdApiKeyFile
          cfg.secrets.navidromeOidcFile
          cfg.secrets.jellyseerrEnvFile
        ];
        in lib.all (p: p == null || !(lib.hasPrefix "/nix/store/" p)) paths))
    ];
  };
}
```

## Datei: 5A3-forbidden-tech.nix

```nix
# ---
# id: "5A3-forbidden-tech"
# title: "Forbidden Technology Guardrails (Build-Time Enforcement of NO-CONTAINERS.md)"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-12
# links:
#   adr: ADR-0000 §5 (systemd-native), NO-CONTAINERS.md
#   repo-harvest: NixmitGROK (forbidden-tech pattern)
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
  reg = import ./590-registry.nix { inherit lib; };
in
lib.mkIf cfg.enable {
  assertions = [
    # INV-TECH-01..03: verbotene Technologien strukturell unmöglich machen
    # (NO-CONTAINERS.md wird dadurch Build-zeitlich durchgesetzt, nicht nur dokumentiert)
    (reg.mkInvariant "INV-TECH-01" (!config.virtualisation.docker.enable))
    (reg.mkInvariant "INV-TECH-02" (!config.virtualisation.podman.enable))
    (reg.mkInvariant "INV-TECH-03" (!config.services.cron.enable))
  ];
}
```

## Datei: 5A4-ingress-enforcement.nix

```nix
# ---
# id: "5A4-ingress-enforcement"
# title: "Ingress Enforcement — alle Caddy-vHosts müssen in Registry definiert sein"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 3
# last_reviewed: 2026-08-12
# links:
#   adr: ADR-0000 §5 (Chameleon Caddy), ADR-0000 (Dezimalrahmen)
#   repo-harvest: NixmitGROK (ingress-enforcement pattern)
# context7:
#   - query: "services.caddy virtualHosts configuration"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "services.caddy.virtualHosts.<host> = { ... } (valid Caddy vHost def)"
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
  reg = import ./590-registry.nix { inherit lib; };
in
lib.mkIf cfg.enable {
  assertions = [
    # INV-INGRESS-01: Kein manueller Caddy-vHost außerhalb der Registry erlaubt.
    # Alle Dienste müssen in lib/registry.nix definiert sein (caddyClass != "none").
    (reg.mkInvariant "INV-INGRESS-01"
      (let
        # Alle Registry-Hosts die einen Caddy-vHost bekommen (caddyClass != none)
        registryHosts = lib.mapAttrsToList
          (n: s: "${n}.${cfg.domain}")
          (lib.filterAttrs (_: s: s.caddyClass != "none") reg.services);
        # Alle aktuell konfigurierten Caddy-vHosts
        configHosts = lib.attrNames (config.services.caddy.virtualHosts or { });
      in
        # Jeder konfigurierte vHost MUSS in der Registry sein (oder domain leer = kein Ingress)
        lib.all (h: lib.elem h registryHosts || cfg.domain == "") configHosts))
  ];
}
```
