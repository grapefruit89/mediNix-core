# Review 51-ingress — Verifikation und Fixes

**Datum:** 2026-10-17
**Basis:** externer Review mit 26 Findings (Teil 2 des Reviews)
**Methode:** jedes Finding gegen den echten Code geprüft, dann gefixt oder als
Entscheidung markiert. Kein `nix eval` lokal verfügbar (Termux/aarch64) —
Fixture-Wirkung deshalb per Code-Inspektion, CI-Prüfung ausstehend.

## Was der Review nicht sehen konnte

Der Review hatte 11 Dateien. Nicht vorlagen: `lib/ingress-access.nix`, die
Options-Deklarationen in `default.nix`, `lib/service-contract.nix`,
`50-core/502-host-settings.nix`, `flake.nix` und `tests/`. Genau diese Dateien
entscheiden über die Schwere mehrerer Findings.

**Zentrale Korrektur:** `medinix.domain` ist ein **Alias** für
`medinix.host.domain` (`50-core/502-host-settings.nix:22-24`,
`lib.mkAliasOptionModule`). Es gibt also keine drei divergierenden
Domain-Quellen — es ist eine Option mit drei Schreibweisen.

## Ergebnis je Finding

| # | Urteil | Aktion |
|---|---|---|
| 1 `allowUnauthenticated` ODER statt Override | **BESTÄTIGT** | **gefixt**: Option `nullOr bool` (default `null`), Vhost gewinnt — symmetrisch zu `accessGroup`/`landing` |
| 2 `/setup`-Guard liest Policy statt Wirkung | **BESTÄTIGT** | **gefixt**: Guard nutzt `ia.isWan (ia.accessGroupOf …)` |
| 3 Upstream-Vergleich exakt `127.0.0.1:5120` | **BESTÄTIGT** | **gefixt**: Port wird extrahiert, Schema/`localhost`/Trailing-Slash toleriert |
| 4 CIDR-Präfix ohne Grenze | **TEILWEISE** | Typ blockte `10.evil` schon (Review-Beispiel widerlegt); **gefixt**: Typ verlangt `[1-9][0-9]{0,2}` (`/0`, `/08` raus), Assertion prüft `v4 >= /8`, `v6 >= /7` |
| 5 Strip nur im `authBlock` | **BESTÄTIGT** | **gefixt**: `request_header -…` steht am Anfang **jedes** `route` (CI-Reihenfolge `request_header < forward_auth` geprüft, bleibt erhalten) |
| 6 `mediaGroup = true` in 511 | **BESTÄTIGT** | **gefixt**: entfernt — ADR-0000 §4 sagt wörtlich „Edge ingress (511) and identity (512) never receive GID 5000" |
| 7 Global-Modus injiziert `auto_https off` etc. | **TEILWEISE** | offen — `auto_https off` ist für das Modell nötig; `mkDefault`-Härtung als Folgearbeit notiert |
| 8 Avahi `openFirewall` Default `true` | **BESTÄTIGT** | offen (Entscheidung) — Default via search.nixos.org bestätigt: `services.avahi.openFirewall` = `true` |
| 9 `cloudflareEnvFile` hat Vorrang | **TEILWEISE** | offen — der „Fallback" ist **dokumentierte, assertierte** Option (`502-host-settings.nix:130-143`); offen bleibt die Blindstelle der Trennungs-Assertion |
| 10 WAN-Landing am Apex ohne Auth/CIDR | **BESTÄTIGT** | offen (Entscheidung) |
| 11 `.local` publiziert, aber nie gerendert | **BESTÄTIGT** | offen (Entscheidung) |
| 12 drei Domain-Quellen | **WIDERLEGT** | Alias-Option; nur der tote `else`-Zweig in `513:41` bleibt (kosmetisch) |
| 13 516 hartkodiert `caddy-media.service` | **BESTÄTIGT** | **gefixt**: `ia.caddyUnitOf` (neu in `lib/ingress-access.nix`) + Assertion `ingress.enable` |
| 14 `internal` nur auf `.lan` | **BESTÄTIGT** | **gefixt**: `internal` rendert jetzt `{name}.{domain}` mit TLS + `lanAbort` (nur mit `tlsEnabled`) — sonst ist der dokumentierte Passkey-Bootstrap unmöglich |
| 15 `prune_label` ohne Managed-by-Filter | **BESTÄTIGT** | offen (Entscheidung — ändert Aufräum-Semantik) |
| 16 `--fail-with-body` + `\|\|` | **BESTÄTIGT** | **gefixt**: jeder Versuch wird einzeln validiert |
| 17 Wildcard deckt nur eine Label-Ebene | **BESTÄTIGT** | **gefixt**: `*.${domain}` als zusätzliche SAN wenn `domain != acmeHost` |
| 18 515 löst „enabled" anders auf als 511 | **BESTÄTIGT** | **gefixt**: `manifest.enable` (wie 511/513/518); `lib/registry`-Import entfernt, `requires` korrigiert |
| 19 `authProxyPresent` ist manueller Spiegel | **BESTÄTIGT** | offen — hängt an 517 (existiert noch nicht) |
| 20 `idp`/`stream` ohne Ack, per Vhost wählbar | **BESTÄTIGT** | offen (Entscheidung) |
| 21 519: tote `useIPTables`-Assertion, tautologisches `caddy` | **BESTÄTIGT** | **gefixt**: `networking.useIPTables` existiert nicht (search.nixos.org) → `networking.firewall.backend == "iptables"`, nur bei `firewall == "managed"`; `keepOn.caddy` entfernt |
| 22 „nur 2 Assertions benannt" | **WIDERLEGT** | 17 `negative-*`-Fixtures in `flake.nix` (nicht in `tests/` — der Review sah sie nicht) |
| 23 515-Alias-Unit nur 3/5 Hardening-Optionen | **BESTÄTIGT** | offen |
| 24 Doku-Drift | **TEILWEISE** | teilweise gefixt (siehe unten); Rest offen |
| 25 Contract-Tabelle/ADR-Konflikt | **TEILWEISE** | offen (ADR-Entscheidung nötig) |
| 26 Duplikate/Altlasten | **TEILWEISE** | offen (kosmetisch) |

## Doku-Korrekturen in diesem Commit

- `default.nix` `ingress.guardrails.enable`: Text sagte „fail2ban is NOT blocked,
  516 is planned" — 516 ist seit 2026-10-15 implementiert, 519 blockt fail2ban.
- `default.nix` `ingress.landing.enable`: Text versprach `https://{domain}`
  **mit** LAN-Abort und `http://home.local` — beides falsch.
- `51-ingress/README.md`: fail2ban-Widerspruch (2 Stellen), 517 als
  „edge firewall" statt oauth2-proxy (2 Stellen), `.local`-Versprechen,
  `home.local`-Landing, `hasStatic` (existiert in keiner `.nix`-Datei),
  Verifikationsblock.
- `51-ingress/510-ingress-SERVICE.md`: „513 wrote the record" — 513 legt nur
  `wan`, `lan`, `*`, Apex an.
- `51-ingress/512-pocket-id.nix`: „511 targets 127.0.0.1:<pocket-id-port>" und
  „leave forwardAuthUpstream empty" — 511 nutzt `forwardAuthUpstream` wörtlich
  und Pocket-ID hat keinen forward-auth-Endpoint.
- `51-ingress/AGENTS.md`: `accessGroupOf` lag bei 511 zugeschrieben, lebt aber in
  `lib/ingress-access.nix`.
- NIXMETA `requires` in 511/512/515/516 an die echten Importe angeglichen.

## Der Verifikationsblock war falsch — und warum

`51-ingress/README.md` behauptete „GitHub CI Flake Check PASS" ohne Datum und
ohne Commit. Gemessen am 2026-10-17 (Run `39030306072`, HEAD `89a7a79`):

- **Alle** Checks inklusive aller `negative-*`-Fixtures und der beiden
  Header-Strip-Checks haben **erfolgreich evaluiert**.
- Der Run starb danach im Binary-Cache-Schritt:
  `HTTP error 418`, `ResourceExhausted: rate limit exceeded`,
  `GitHub Actions Cache throttled Magic Nix Cache`.

Das ist Infrastruktur, keine Code-Regression. Der Block nennt jetzt Datum,
Commit und den echten Zustand.

## Offene Entscheidungen (Betreiber)

1. **WAN-Landing (10):** Soll `https://{domain}` die Diensteliste ohne Auth und
   ohne CIDR-Abort zeigen? Vorschlag: Option `landing.wanPublic` (default
   `false`) + Assertion.
2. **`.local` (11):** Entweder 511 rendert `http://{name}.local` mit `lanAbort`,
   oder 515 publiziert nur, was 511 rendert. Heute ist die Kette gebrochen.
3. **Avahi (8):** `openFirewall` folgt dem nixpkgs-Default `true` → UDP/5353 auf
   allen Interfaces. Vorschlag: `mkDefault (hostIntegration.firewall == "managed")`
   + Interface-Option.
4. **Prune (15):** `prune_label` löscht fremde A/AAAA/CNAME ohne Managed-by-
   Filter. Vorschlag: nur `comment = managed-by=mediNix-core/513` löschen.
5. **`cloudflareEnvFile` (9):** Trennungs-Assertion ist mit EnvFile blind.
6. **`idp`/`stream` (20):** `idp` auf 512 beschränken, `stream` mit Ack-Option.

## Nicht lokal beweisbar

Kein `nix`/`statix`/`deadnix` auf dem Gerät. Geprüft wurde: `nixfmt`-Parse
(exit 0, auf Kopien) für alle geänderten `.nix`-Dateien, `git diff --check`,
Code-Inspektion der CI-Checks in `flake.nix`. Die NixOS-Evaluation und damit die
Assertion-Wirkung liefert nur CI (`nix flake check`).
