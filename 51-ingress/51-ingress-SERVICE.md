# Neuen Dienst an Caddy, Pocket ID und die Landingpage hängen

511, 513, 515 und 518 kennen keine Programmnamen. Alles, was ein Dienst braucht, steht in **seiner** Moduldatei plus einem Eintrag in `lib/registry.nix`.

Vorlage: [`55x-service.example.nix`](55x-service.example.nix)

## Checkliste

1. Dienst in `lib/registry.nix` anlegen (`port`, `uid`, `stateDir`, `caddyClass`).
2. Service-Modul kopieren, `enable`-Option existiert bereits oder wird im Options-Modul ergänzt.
3. Im Modul unter `lib.mkIf cfg.enable`:
   - Prozess auf `127.0.0.1:<port>` binden
   - `medinix.ingress.vhosts."<name>"` setzen
4. Auf dem Host: `medinix.<name>.enable = true;`
5. **Nicht** 511/513/515/518 anfassen.

## vHost-Felder

```nix
medinix.ingress.vhosts."seerr" = {
  accessGroup = "public";   # stream | internal | public | idp | none
  landing     = true;
  iconSvg     = ''<svg …></svg>'';
};
```

| Feld | Wirkung |
| --- | --- |
| `accessGroup` | 511-Template (siehe unten) |
| `landing = true` und `iconSvg != ""` | Kachel auf `https://{domain}` und `http://home.local` |
| sonst | keine Kachel, kein Fallback-Icon |
| `dns.hostnames.<name>` | öffentlicher Label, Default = Registry-Name |

## accessGroup

| Gruppe | HTTPS `{name}.{domain}` | Auth | `.local` |
| --- | --- | --- | --- |
| `stream` | ja, ohne Compress | nie | HTTP, kein Auth, kein Abort |
| `internal` | ja, Abort außerhalb `trustedCidrs` | nie | wie oben |
| `public` | ja, Compress | `forward_auth`, wenn Host-weit an | wie oben |
| `idp` | ja, kein Abort | nie (Deadlock-Schutz) | wie oben |
| `none` | kein vHost | — | kein vHost |

`.local` bekommt **niemals** TLS, forward-auth oder WAN-Abort.

## Pocket ID — einmal pro Host, nicht pro Dienst

```nix
medinix.pocketId.enable = true;
medinix.pocketId.exposure = "idp";          # Login unter pocket-id.{domain}
medinix.ingress.auth.mode = "forward-auth";
# forwardAuthUpstream leer → 127.0.0.1:<pocket-id-port>
```

Dann hängt 511 **nur** an `accessGroup = "public"` die Auth-Wand. `stream` / `internal` / `idp` / `.local` bleiben ohne.

Externes Proxy statt Pocket ID:

```nix
medinix.ingress.auth.mode = "forward-auth";
medinix.ingress.authProxyPresent = true;
medinix.ingress.auth.forwardAuthUpstream = "127.0.0.1:4180";
# pocketId.enable bleibt false
```

`skipPaths` (Healthchecks ohne Login) am vHost oder unter `ingress.auth.skipPaths`.

## Landingpage

518 liest nur die vHosts. Ein Tile entsteht genau dann, wenn das Dienstmodul `landing = true` und ein SVG setzt — siehe `555-seerr.nix`.

```nix
medinix.ingress.landing.enable = true;   # Default
```

Kein Eintrag in 518, keine Icon-Map, keine `preferred`-Liste.

## Was der Host sonst noch braucht (einmal)

```nix
medinix.enable = true;
medinix.domain = "example.tld";
medinix.ingress.enable = true;
medinix.ingress.tls.acmeHost = "example.tld";
medinix.ingress.tls.acmeCredential = "/path/to/cf.cred";  # systemd credential, KEY=value
```

DNS (513) und mDNS (515) ziehen die Namen aus derselben vHost-Registry. Neues Programm = neuer vHost, kein Edit an 513/515.

## Gegenbeispiel

Nicht tun:

```nix
services.caddy.virtualHosts."foo.example.tld".extraConfig = "…";
```

Das umgeht die Engine (so wie 554-Feishin heute). Stattdessen vHost registrieren und 511 rendern lassen. Feishin braucht später ein `static`-Template, weil es kein `reverse_proxy` ist.
