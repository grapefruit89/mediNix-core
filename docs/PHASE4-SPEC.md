# Phase 4 Implementation Spec — mediNix-core

**Stand:** 2026-08-19 | Nach Phase 1 (VPN flake-managed), Phase 2 (ACME flake-managed), Phase 3 (Guardrails, Binary-Cache, Beispiel-Configs)

Dieses Dokument beschreibt alle offenen Punkte nach dem Grok-Review der Ingress- und Security-Domain. Jeder Punkt enthält Problem, Root Cause, Zielbild und konkreten Code. Eine andere KI kann direkt damit weiterarbeiten.

---

## KRITISCHER BUG: 524-systemd-credentials silently disabled

**Datei:** `52-security/524-systemd-credentials.nix` Zeile 38

```nix
# FALSCH (immer false — cfg.services existiert nicht):
activeSecrets = lib.filterAttrs (name: path:
  path != null && (cfg.services.${name}.enable or false)
) secretMap;

# RICHTIG (flaches Options-Schema in grapefruitMedia):
activeSecrets = lib.filterAttrs (name: path:
  path != null && (cfg.${name}.enable or false)
) secretMap;
```

**Wirkung:** Alle `LoadCredentialEncrypted`-Injektionen in 524 sind dead code. Kein API-Key-Secret wird in irgendeinen Service injiziert. Das muss als allererstes gefixt werden.

**Fix:** Einen-Zeilen-Patch, dann neue Assertions dazu (siehe Item 1 unten).

---

## Item 1 — 524: Bug-Fix + Generische Credentials-Registry

### Problem
1. `cfg.services.${name}.enable` ist falsch (Bug, s.o.)
2. `secretMap` ist manuell gepflegt — neue Services müssen händisch eingetragen werden
3. `LoadCredentialEncrypted` vs. `LoadCredential` (plaintext) ist nicht unterscheidbar
4. Keine Assertion: Secret-Pfad im Nix-Store → INV-SECRET greift nicht für 524

### Zielbild
- Bug-Fix: `cfg.${name}.enable`
- Secrets-Deklaration in `lib/registry.nix` pro Service (eine Zeile)
- 524 liest die Registry generisch — kein manueller secretMap mehr
- `LoadCredential` (plaintext) bleibt als expliziter Opt-in für Dev/Migration, mit Warning
- INV-SECRET-01 und INV-SECRET-02 greifen auf alle Registry-Secrets

### Implementierung

**Schritt 1: `lib/registry.nix` — Secret pro Service deklarieren**

```nix
# In mkService erweitern um optionales secrets-Feld:
mkService = name: number: class: profile: {
  inherit name;
  num  = number;
  port = number * 10;
  uid  = number * 10;
  gid  = 5000;
  caddyClass = class;
  hardeningProfile = profile;
  # Neu: credentials die dieser Service braucht
  # Format: { name = "credential-name"; envVar = "ENV_VAR_NAME"; optional = false; }
  credentials = [];
};

# Beispiel-Einträge für bestehende Services (in services-Attrset):
sonarr  = (mkService "sonarr"  532 "internal" "dotnet") // {
  credentials = [{ name = "api-key"; envVar = "SONARR_API_KEY"; optional = true; }];
};
radarr  = (mkService "radarr"  533 "internal" "dotnet") // {
  credentials = [{ name = "api-key"; envVar = "RADARR_API_KEY"; optional = true; }];
};
prowlarr = (mkService "prowlarr" 536 "internal" "dotnet") // {
  credentials = [{ name = "api-key"; envVar = "PROWLARR_API_KEY"; optional = true; }];
};
sabnzbd = (mkService "sabnzbd" 541 "internal" "default") // {
  credentials = [
    { name = "api-key"; envVar = "SABNZBD_API_KEY"; optional = true; }
    { name = "server-creds"; envVar = "SABNZBD_SERVER_CREDS"; optional = false; }
  ];
};
jellyfin = (mkService "jellyfin" 551 "stream" "default") // {
  credentials = [{ name = "admin-password"; envVar = "JELLYFIN_ADMIN_PASSWORD"; optional = true; }];
};
```

**Schritt 2: `lib/credentials.nix` — zentraler Helper**

```nix
# lib/credentials.nix
{ lib }:

{
  # Erzeugt LoadCredentialEncrypted oder LoadCredential für einen Service
  mkLoadCredential = { name, path, encrypted ? true }:
    if encrypted
    then { LoadCredentialEncrypted = [ "${name}:${path}" ]; }
    else { LoadCredential          = [ "${name}:${path}" ]; };

  # Prüft ob ein Pfad außerhalb des Nix-Stores liegt
  isValidSecretPath = path:
    path != null && !(lib.hasPrefix "/nix/store" path);

  # Credential-Laufzeitpfad (mit .service-Suffix!)
  credentialRuntime = unitName: credName:
    "/run/credentials/${unitName}.service/${credName}";
}
```

**Schritt 3: `52-security/524-systemd-credentials.nix` — generisch rewritten**

```nix
{ config, lib, ... }:

let
  cfg      = config.grapefruitMedia;
  registry = import ../lib/registry.nix { inherit lib; };
  creds    = import ../lib/credentials.nix { inherit lib; };

  # Nur Services die (a) aktiv sind UND (b) einen Secret-Pfad konfiguriert haben
  # cfg.secrets.<name>.<credentialName>  — Options müssen in default.nix vorhanden sein
  activeCredentials =
    lib.concatMap (svc:
      if !(cfg.${svc.name}.enable or false) then []
      else
        lib.concatMap (cred:
          let path = cfg.secrets.${svc.name}.${cred.name} or null;
          in if path == null then []
             else [{ service = svc.name; credName = "${svc.name}-${cred.name}"; inherit path; }]
        ) svc.credentials
    ) (lib.attrValues registry.services);

in {
  # LoadCredentialEncrypted für alle aktiven Services mit gesetztem Credential-Pfad
  config.systemd.services = lib.listToAttrs (map (c:
    lib.nameValuePair c.service {
      serviceConfig.LoadCredentialEncrypted = [ "${c.credName}:${c.path}" ];
    }
  ) activeCredentials);
}
```

**Schritt 4: `default.nix` — Option-Schema für Secrets**

Die `secrets`-Options in default.nix müssen auf das neue Schema umgestellt werden:

```nix
# Statt:
secrets.sonarrApiKeyFile = lib.mkOption { ... };
secrets.radarrApiKeyFile = lib.mkOption { ... };

# Neu (generisch, pro Service):
secrets.sonarr.api-key = lib.mkOption {
  type    = lib.types.nullOr lib.types.str;
  default = null;
  description = "Pfad zur TPM-gesiegelten .cred-Datei für den Sonarr-API-Key.";
};
# ... etc.
```

**Schritt 5: Assertions in `59-guardrails/590-registry.nix` + `592-security-guardrails.nix`**

```nix
# INV-SECRET-01: Kein Secret-Pfad im Nix-Store (bereits in Registry vorhanden)
# INV-SECRET-02 (NEU): Wenn Encrypted-Mode, darf der Pfad nicht .txt/.env enden
# (schwache Heuristik — systemd-creds Dateien enden typisch auf .cred)

# Neue Error-Einträge in 590-registry.nix:
"SECRET-001" = {
  what = "Secret-Pfad im Nix-Store — private Key wird world-readable.";
  expected = "Pfad außerhalb von /nix/store/";
  found = "Pfad beginnt mit /nix/store/";
  fix = "systemd-creds encrypt --with-key=tpm2+host ... verwenden";
  ref = "ADR-5000";
};
```

---

## Item 2 — 525+526: Generische Confinement-Liste

### Problem
Aktuell sind SABnzbd und Prowlarr in `525-usenet-confinement.nix` hardcoded. Wenn ein dritter Dienst confined werden soll (z.B. ein zukünftiger Torrent-Client), muss das Modul manuell erweitert werden.

### Zielbild
`usenet-confinement.services = [ "sabnzbd" "prowlarr" ]` als deklarative Liste in default.nix. Das Modul generiert die Kill-Switch-Instanzen daraus.

### Implementierung

**`default.nix` — neue Option:**
```nix
usenet-confinement = {
  enable = lib.mkEnableOption "Run Usenet stack isolated under WireGuard VPN";
  services = lib.mkOption {
    type    = lib.types.listOf lib.types.str;
    default = [ "sabnzbd" "prowlarr" ];
    description = ''
      Services die unter dem VPN-Kill-Switch laufen sollen.
      Jeder Name muss einem systemd-Dienst und einem users.users-Eintrag entsprechen.
      Routing-Tabellen werden ab 51820 aufsteigend vergeben.
    '';
  };
};
```

**`525-usenet-confinement.nix` — generisch:**
```nix
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;

  # Routing-Tabellen ab 51820 aufsteigend (eine pro Service)
  serviceWithTable = lib.imap0 (i: name: {
    inherit name;
    table    = 51820 + i;
    priority = 100 + i;
  }) cfg.usenet-confinement.services;

in
lib.mkIf (cfg.enable && cfg.usenet-confinement.enable) {
  imports = [ ./526-vpn-killswitch.nix ];

  services.vpnKillSwitch.instances =
    lib.listToAttrs (map (svc:
      lib.nameValuePair svc.name {
        enable = cfg.${svc.name}.enable or false;

        vpnInterface    = cfg.vpn.interface;
        routingTable    = svc.table;
        routingPriority = svc.priority;

        blockedSocketPaths = [
          "/run/medinix"
          "/run/systemd/resolve"
          "/run/dbus/system_bus_socket"
        ];

        dnsServers = cfg.vpn.dnsServers;
      }
    ) serviceWithTable);
}
```

**Neue Assertions in `599-cross-domain.nix`:**
```nix
# VPN-012: Jeder Service in usenet-confinement.services muss in der Registry bekannt sein
(reg.mkErrorDoc "VPN-012"
  (lib.all (n: svcReg.services ? n) cfg.usenet-confinement.services)
  "5410")

# VPN-013: Jeder confined Service muss auch enabled sein (sonst sinnlose Instanz)
(reg.mkErrorDoc "VPN-013"
  (lib.all (n: cfg.${n}.enable or false) cfg.usenet-confinement.services)
  "5410")
```

---

## Item 3 — 513-cloudflare-dns: WAN-IP-Erkennung + caddyClass als SSoT

### Problem
- WAN-IP kommt von externen Services (ifconfig.me, ipify) — externe Abhängigkeit zur Laufzeit
- Für caddyClass=internal ist die RFC1918-LAN-IP gewünscht — kann vollständig lokal ermittelt werden
- Kein statischer WAN-IP-Fallback für Nutzer mit festem Anschluss
- WAN-IP-Erkennung und caddyClass-Logik sind vermischt im Bash-Script

### Sicherheitsmodell (Mo's Ansatz — korrekt)
- `caddyClass = "internal"` → RFC1918-IP in Cloudflare → aus dem Internet nicht routbar → fail-closed
- `caddyClass = "stream"/"public"` → öffentliche WAN-IP → bewusst exponierende Dienste
- Alle Services binden auf 127.0.0.1 → WAN-Zugriff nur durch Caddy möglich

### Neue Option in `default.nix`
```nix
dns.ddns = {
  # ... bestehende Optionen ...

  wanIp = lib.mkOption {
    type    = lib.types.nullOr lib.types.str;
    default = null;
    example = "203.0.113.42";
    description = ''
      Statische öffentliche WAN-IP. Wenn gesetzt, wird kein externer
      IP-Erkennungs-Dienst kontaktiert.
      Empfohlen für Anschlüsse mit fester IP.
      null = dynamische Erkennung via wanIpCommand.
    '';
  };

  wanIpCommand = lib.mkOption {
    type    = lib.types.str;
    default = "${pkgs.curl}/bin/curl -s4 --max-time 10 --fail https://ifconfig.me";
    description = ''
      Shell-Kommando zur dynamischen WAN-IP-Erkennung.
      Nur relevant wenn wanIp = null UND WAN-Services (stream/public) aktiv sind.
      Für rein interne Setups (nur caddyClass=internal) wird dieser Befehl nie ausgeführt.
    '';
  };

  requireWanIp = lib.mkOption {
    type    = lib.types.bool;
    default = false;
    description = ''
      true: Build bricht wenn kein wanIp gesetzt UND WAN-Services aktiv sind.
      Verhindert, dass man im WAN-Service-Modus auf externe IP-Erkennung angewiesen ist.
    '';
  };
};
```

### Script-Refactoring: Logik nach Nix, Script dünn halten

Die Nix-Seite berechnet, welche Domains welche IP bekommen:

```nix
# In 513-cloudflare-dns.nix:
wanDomains = streamDomains ++ publicDomains;
lanDomains = lanDomains;

# Env-Variablen für das Script:
environment = {
  ZONE          = zone;
  WAN_DOMAINS   = builtins.concatStringsSep " " wanDomains;
  LAN_DOMAINS   = builtins.concatStringsSep " " lanDomains;
  HAS_WAN_SVCS  = if wanDomains != [] then "1" else "0";
  STATIC_WAN_IP = if ddns.wanIp != null then ddns.wanIp else "";
  WAN_IP_CMD    = ddns.wanIpCommand;  # nur als Escape-Hatch
};
```

Das Script wird dann:
```bash
set -euo pipefail

# Token auflösen (unverändert)
if [ -f "$CREDENTIALS_DIRECTORY/cf-ddns-token" ]; then
  TOKEN_FILE="$CREDENTIALS_DIRECTORY/cf-ddns-token"
elif [ -n "${CF_API_TOKEN_FILE:-}" ] && [ -f "$CF_API_TOKEN_FILE" ]; then
  TOKEN_FILE="$CF_API_TOKEN_FILE"
else
  echo "FATAL: Cloudflare API token not found." >&2; exit 1
fi
# Token parsen (CF_DNS_API_TOKEN=... oder reiner Token)
if grep -q "^CF_DNS_API_TOKEN=" "$TOKEN_FILE"; then
  TOKEN=$(grep "^CF_DNS_API_TOKEN=" "$TOKEN_FILE" | cut -d'=' -f2-)
else
  TOKEN=$(cat "$TOKEN_FILE")
fi

# LAN-IP (immer lokal — für internal Services)
LAN_IP=$(ip -4 route get 8.8.8.8 | grep -oP 'src \K\S+')
[ -z "$LAN_IP" ] && { echo "FATAL: LAN IP nicht ermittelbar." >&2; exit 1; }

# WAN-IP (nur wenn WAN-Services aktiv)
if [ "$HAS_WAN_SVCS" = "1" ]; then
  if [ -n "$STATIC_WAN_IP" ]; then
    WAN_IP="$STATIC_WAN_IP"
  else
    WAN_IP=$(eval "$WAN_IP_CMD") || true
    [ -z "$WAN_IP" ] && { echo "FATAL: WAN IP nicht ermittelbar." >&2; exit 1; }
  fi
fi

echo "LAN: $LAN_IP | WAN: ${WAN_IP:-n/a}"

# Zone-ID holen (unverändert)
ZONE_ID=$(curl -sf --fail-with-body -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  | jq -e -r '.result[0].id')
[ -z "$ZONE_ID" ] && { echo "FATAL: Zone $ZONE nicht gefunden." >&2; exit 1; }

# update_record Funktion (unverändert)
update_record() { ... }  # wie gehabt

# WAN-Records (stream/public)
for domain in $WAN_DOMAINS; do update_record "$domain" "$WAN_IP" "false"; done

# LAN-Records (internal → RFC1918)
for domain in $LAN_DOMAINS; do update_record "$domain" "$LAN_IP" "false"; done
```

### Neue Assertion: EXPOSE-001
```nix
# In 591-ingress-guardrails.nix:
# EXPOSE-001: caddyClass=internal → DDNS darf keine WAN-IP eintragen
# (Prüfung: wenn requireWanIp=true und nur interne Services → Fehler)
(reg.mkErrorDoc "EXPOSE-001"
  (!ddns.enable ||
   !(wanDomains == [] && ddns.wanIp != null))  # wanIp gesetzt aber keine WAN-Services → unnötig aber kein Fehler
  "5130")

# EXPOSE-002 (NEU): WAN-Services aktiv + requireWanIp=true → wanIp muss gesetzt sein
(reg.mkErrorDoc "EXPOSE-002"
  (!ddns.requireWanIp || wanDomains == [] || ddns.wanIp != null)
  "5130")
```

---

## Item 4 — Token-Unifikation: lib/credentials.nix + 513/514 angleichen

### Problem
- 513 nutzt `dns.ddns.tokenCredential` mit Credential-Name `cf-ddns-token`
- 514 nutzt Prioritätskette (acmeCredential > cloudflareTokenCredential > tokenCredential > tokenFile) mit Credential-Name `cf-acme-token`
- Zwei leicht unterschiedliche Patterns, kein gemeinsamer Helper

### Zielbild
Ein einziger `lib/credentials.nix` Helper. Beide Module nutzen ihn. Der Host trägt nur einmal einen Cloudflare-Token ein, beide Module teilen sich denselben.

### `lib/credentials.nix` (vollständig)
```nix
# lib/credentials.nix — Zentrale Credential-Helfer für mediNix-core
# Alle Secret-Operationen (LoadCredential, LoadCredentialEncrypted, Laufzeitpfad) hier.
{ lib }:

{
  # Erzeugt serviceConfig-Fragment für einen verschlüsselten Credential
  mkEncryptedCredential = { credName, credPath }:
    lib.mkIf (credPath != null) {
      serviceConfig.LoadCredentialEncrypted = [ "${credName}:${credPath}" ];
    };

  # Laufzeitpfad — MUSS .service-Suffix enthalten!
  credPath = unitName: credName:
    "/run/credentials/${unitName}.service/${credName}";

  # Ersten nicht-null Pfad aus einer Liste wählen (Prioritätskette)
  firstCredential = paths:
    lib.findFirst (p: p != null) null paths;

  # Prüft ob ein Pfad ein gültiger Secret-Pfad ist (nicht im Store)
  isValidPath = path:
    path != null && !(lib.hasPrefix "/nix/store" path);
}
```

### Unified Cloudflare-Token-Option in `default.nix`
```nix
# Ein kanonischer Cloudflare-Token für ACME + DDNS:
ingress.tls.acmeCredential = ...;    # bereits vorhanden — für ACME
dns.ddns.cloudflareTokenCredential = ...;  # bereits vorhanden — DDNS nutzt dies als Fallback

# In 513: wenn cloudflareTokenCredential gesetzt → verwendet, Credential-Name "cf-ddns-token"
# In 514: Priorität acmeCredential > cloudflareTokenCredential > tokenCredential > tokenFile
# → Ein Token kann von beiden geteilt werden (cloudflareTokenCredential)
```

---

## Item 5 — 511-caddy: lib.fakeHash entfernen

### Problem
`51-ingress/511-caddy.nix` Zeile ~139:
```nix
hash = lib.fakeHash;
```
Das ist der Hash für das CrowdSec-Plugin. Sobald `observability.crowdsec.enable = true`, schlägt der Build fehl.

### Fix
```bash
# Einmalig auf einem Rechner mit Internet-Zugang:
nix-prefetch-url --type sha256 \
  "https://github.com/hslatman/caddy-crowdsec-bouncer/archive/<commit>.tar.gz"
# oder
nix build --no-link .#checks.x86_64-linux.crowdsec-hash 2>&1 | grep "got:"
```

Den echten Hash in `511-caddy.nix` eintragen und `lib.fakeHash` entfernen. Dokumentiert in `docs/CROWDSEC-HASH.md`.

---

## Item 6 — nftables Koexistenz: 521 vs. 526 dokumentieren + absichern

### Situation
- `521-nftables.nix`: aktiviert `networking.firewall` (inet filter Tabelle via nixos-firewall-tool)
- `526-vpn-killswitch.nix`: eigene Tabelle `vpn-killswitch` mit `hook output priority -50`

Das ist korrekt additiv. Risiken:
- `oifname`-Matching in Canary-Regel (526) und Firewall-Regeln (521) könnten interagieren
- Priority -50 = vor den normalen Filter-Regeln → gewollt (kill-switch greift zuerst)

### Assertion hinzufügen
```nix
# In 592-security-guardrails.nix:
# INV-FW-02: Wenn Kill-Switch aktiv, muss nftables enable=true sein
(reg.mkInvariant "INV-FW-02"
  (config.services.vpnKillSwitch.instances == {} ||
   config.networking.nftables.enable))

# INV-FW-03: networking.firewall UND nftables gleichzeitig enable
# Das ist OK in NixOS (nftables.enable aktiviert die nftables-Backend-Implementierung
# des Firewall-Moduls). Assertion: Beide dürfen gleichzeitig aktiv sein.
```

### Dokumentations-Kommentar in 526-vpn-killswitch.nix (oben einfügen):
```nix
# nftables-Koexistenz:
# 521-nftables.nix aktiviert networking.nftables.enable + networking.firewall.enable.
# Diese Datei fügt eine EIGENE Tabelle "vpn-killswitch" hinzu (additiv, kein Konflikt).
# Die Canary-Regel hat priority -50 (vor normalen filter-Regeln) — das ist gewollt:
# Der Kill-Switch muss VOR der normalen Firewall greifen.
# Beides zusammen funktioniert in NixOS korrekt (getestet: nixos-test smoke-test).
```

---

## Item 7 — Binding-Generalisierung: INV-02 für alle Services

### Problem
`590-core-guardrails.nix` prüft 127.0.0.1-Binding nur für Jellyfin (INV-02). Alle anderen Services werden nicht geprüft.

### Zielbild
Alle Services in der Registry, die `listenAddress` oder äquivalente Umgebungsvariablen haben, werden geprüft.

### Implementierung
Registry um `bindEnvVar` erweitern (wenn bekannt):
```nix
jellyfin = (mkService ...) // {
  bindEnvVar = "JELLYFIN_NetworkConfiguration__LocalNetworkAddresses";
};
sonarr = (mkService ...) // {
  bindEnvVar = "SONARR_BIND_ADDRESS";  # falls vorhanden
};
```

Dann in `590-core-guardrails.nix`:
```nix
(reg.mkInvariant "INV-02"
  (lib.all (svc:
    !((cfg.${svc.name}.enable or false) && svc.bindEnvVar != null) ||
    (config.systemd.services ? svc.unitName &&
     config.systemd.services.${svc.unitName}.environment.${svc.bindEnvVar} or "" == "127.0.0.1")
  ) (lib.attrValues (import ../lib/registry.nix { inherit lib; }).services)))
```

---

## Prioritäten und Reihenfolge

| # | Item | Sicherheitswirkung | Aufwand |
|---|------|-------------------|---------|
| 1 | **524 Bug-Fix** `cfg.services.${n}` → `cfg.${n}` | **KRITISCH** — alle API-Keys ungeschützt | minimal (1 Zeile) |
| 2 | **fakeHash entfernen** (511) | Hoch — kein CrowdSec ohne Fix | minimal |
| 3 | **513 WAN-IP-Option** + statische IP | Hoch — externe Abhängigkeit entfernen | mittel |
| 4 | **524 generisch** + lib/credentials.nix | Mittel — Wartbarkeit + neue Services | mittel |
| 5 | **525 generische Liste** | Mittel — neue confined Services möglich | mittel |
| 6 | **EXPOSE-001/002** Assertions | Mittel — DNS-Misconfiguration verhindern | klein |
| 7 | **INV-02 generalisieren** | Mittel — 127.0.0.1-Garantie auf alle Services | mittel |
| 8 | **Token-Unifikation** lib/credentials.nix | Niedrig — bereits funktional | mittel |
| 9 | **nftables Dokumentation** + INV-FW-02 | Niedrig — Architektur klar, nur Doku fehlt | klein |

---

## Was bereits abgeschlossen ist (Phase 1–3)

- ✅ VPN flake-managed (`52-security/526-vpn-interface.nix`)
- ✅ WireGuard-Killswitch fail-closed (`526-vpn-killswitch.nix`)
- ✅ ACME flake-managed (`51-ingress/514-acme.nix`) — `.service`-Suffix korrekt
- ✅ Binary-Cache defaults in `default.nix` (via `nix.settings.substituters`)
- ✅ Prowlarr-Kill-Switch-Instanz (`525-usenet-confinement.nix`)
- ✅ `BIND-001`: kein mediNix-Port in allowedTCPPorts
- ✅ `VPN-010/011`: Kill-Switch-Instanz-Checks
- ✅ `AUTH-001`: schärfer — `pocketId.enable || authProxyPresent`
- ✅ `ADMIN-HANDOFF.md`: §5 auf flake-managed ACME aktualisiert
- ✅ `docs/examples/`: simple, vpn-confinement, mergerfs-tiering

---

## Architektur-Konstanten (nicht ändern)

- **GID 5000** = media — alle Services
- **Port = UID = serviceNumber × 10** — ADR-5043 Dezimalrahmen
- **Alle Apps binden auf 127.0.0.1** — Caddy ist der einzige Eingang
- **sops-nix ist VERBOTEN** — ADR-5000 / ARCHIVE-sops-nix-deprecated.md
- **Docker/Podman/cron sind VERBOTEN** — NO-CONTAINERS.md
- **Alle Secrets via systemd-credentials** (`LoadCredential` / `LoadCredentialEncrypted`)
- **Credential-Laufzeitpfad**: `/run/credentials/<unit>.service/<name>` — `.service`-Suffix IMMER erforderlich
- **caddyClass** ist SSoT für Exposition: `stream` (WAN+Streaming), `internal` (LAN/RFC1918), `public` (WAN+Proxy), `none` (kein vHost)
