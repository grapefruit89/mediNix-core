# mediNix-core — AGENTS.md

> Autonome AI-Agenten-Anleitung. Dieses Dokument überlebt jeden `/reset` (liegt im Repo).

## Projekt
Portables NixOS Media-Stack-Modul. Repo: `github:grapefruit89/mediNix-core`, Branch `main`.
Arbeitsverzeichnis lokal: `/opt/data/50-mediNix`. Host-Deploy: q958 (192.168.2.73, AUS bis Freigabe).

## Architektur-Invarianten (ADR-0000, NICHT verhandelbar)
- **Dezimalrahmen:** Port = ServiceNum × 10 | UID = Port | GID = 5000
- **Flache Struktur:** `XX-domain/NNN-service.nix` — nie tiefer verschachteln
- **systemd-native:** kein Docker, kein netns. WireGuard OK als `NetworkNamespacePath`/UID-Routing
- **Chameleon Caddy:** `config.services.caddy.enable` → inject | else → `caddy-media`
- **Binding:** alle Dienste auf 127.0.0.1 (nur Ingress exponiert)
- **Fail-closed:** Assertions = Build-Abbruch, nie nur Warnung
- **Keine Inline-Secrets:** nur `LoadCredentialEncrypted` / `EnvironmentFile`

## Build-Status (Stand: 1f4b80e)
- ~95% fertig. Vor erstem Deploy auf q958: CrowdSec-Plugin-Hash via `nix build` in `511-caddy.nix`
  ermitteln (aktuell `lib.fakeHash` Platzhalter), dann `nix flake check .#checks.x86_64-linux.nixos-check`.
- Heute erledigt: P0-Bugfixes (pocketId, secrets-Pfade, dotnet-UMask, Jellyfin-Bind),
  Invarianten (INV-VPN-02/TLS-02/UMASK-01/BIND-01/SEC-01), devNIX-Shift-Left (flake.nix:
  Ratsche + Decimal-Enforcer + Linting + devShell), Hardening-Round-3 (SystemCallArchitectures/
  ProtectClock/RemoveIPC/OOM/journal-logging/network.target), arr-settings.nix (.NET Env Vars),
  nixpkgs-Audit (keine Migration nötig), Autobrr abgelehnt.
- Nix-Verifikation bisher UNTESTED (kein nix-Binary im Hermes-Container, q958 AUS).

## Deklaratives Modul-Muster (VORBILD)
Jedes Service-Modul:
```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.grapefruitMedia.services.<name>;
  svc = config.grapefruitMedia;
  port = <num> * 10;  uid = port;  gid = 5000;
in {
  config = lib.mkIf cfg.enable {
    users.users.<name> = { uid = uid; group = "media"; extraGroups = [ "media" ]; home = stateDir; isSystemUser = true; };
    users.groups.media.gid = gid;
    services.<name> = { enable = true; /* native nixpkgs */ };
    systemd.services.<name> = {
      serviceConfig = lib.mkMerge [ (import ../lib/hardening-profiles.nix { inherit lib; }).python /* oder dotnet/nodejs/network */ {
        User = "<name>"; Group = "media"; UMask = "0002"; StateDirectory = "<name>-${toString port}";
      } ];
    };
  };
}
```

## Guardrails (59X-Schema)
- `590-registry.nix`: `invariants` (INV-01..07, INV-SECRET) + `errors` (VPN/TLS/AUTH/DNS/SEC/STORE)
  + Helper `mkInvariant`/`mkError`/`mkErrorDoc`
- `591-599`: domänenspezifische Assertions. `599-cross-domain.nix`: alle Invarianten (Systemgarantien).
- `ops/59A1-emergency-user.nix` + `ops/59A2-backup-ssh.nix`: Hilfs-User (außerhalb 59X-Assertions-Schema).

## Bekannte Fallstricke
- `cfg.enable` = `config.grapefruitMedia.enable` (NICHT `cfg.security.enable` — gibt's nicht!)
- Service-Optionen: `cfg.jellyfin.enable` (nicht `cfg.services.jellyfin.enable`)
- `525-usenet-confinement.nix`: KEIN `config.systemd.services.*` lesen (Infinite Recursion!) — nur `mkMerge`
- `medinix`-CLI: `PROBLEMS`-Counter über `mktemp`-Datei (Subshell-safe)
- Portabilität: KEINE hardcoded IPs/CIDRs/Machine-Namen in Modulen (K.O.-Kriterium)
- Secrets: TPM2-verschlüsselt (`systemd-creds encrypt --with-key=tpm2+host`), Pfade nie im Nix-Store
  (INV-SECRET prüft alle 12 Secret-Pfade → Build-Abbruch bei `/nix/store/`-Präfix)

## CLI-Tool
`packages/mediNix-cli/default.nix` → `medinix` (check/repair/status/vpn/secrets).
Build-Zeit aus `lib/registry.nix` generiert (registryJson). Tier-Pfade + Domain als Parameter.

## Security-Prinzip (Pareto-Hardening)
"So sicher wie möglich, aber KISS." Ziel: 90-95% Absicherung mit 20% Aufwand.
Beispiel: VPN-Killswitch via UID-Routing (billig, robust) statt netns (komplex, fragil).
Keine 100%-Goldplating-Complexity. Fail-closed bleibt (Assertions brechen den Build).
Siehe ADR-5050 (systemd-hardening-baseline) + lib/hardening-profiles.nix.

## Host-Admin-Verantwortung (mediNIX-core macht DAS NICHT)
mediNIX-core ist ein portables Modul. Folgende Punkte sind **Host-Entscheidungen** und
müssen vom Admin auf q958 selbst konfiguriert werden (siehe ADMIN-HANDOFF.md):
- **Binary-Cache:** `nix.settings.substituters` mit Fallback-Caches setzen (cache.nixos.org +
  optional eigener). ZIEL: NICHTS wird auf q958 kompiliert. Nur absoluter Notfall-Build erlaubt.
- **Impermanence:** Root auf tmpfs / persist-Modul — Architektur-Entscheidung, nicht Modul-Sache.
- **Tier-Hardware-Zuordnung:** Welche Platte ist NVMe/SSD/HDD (ABC-Tiering) — Host-Config.
- **SSH-Hardening, TPM-Secrets, nftables-Baseline:** Host-seitig (mediNIX liefert nur Module).

## Roadmap (nicht vor erstem Deploy)
- INV-STORE-xx: State-Pfad-Whitelist als Guardrail (Alarm bei neuem Pfad außerhalb Tier-Liste).
  Build-Time-Cheap, hoher Effekt — Impermanence-Whitelist-Ansatz.
- ADMIN-HANDOFF.md: saubere Übergabe der Host-Verantwortlichkeiten an den Admin.

## Tests
`tests/smoke-test.nix` → `checks.mediNix-smoke` in `flake.nix` (Navidrome Unit + Port-Isomorphie).

## Quell-Repos (Harvest, siehe docs/ADR-0001)
- mediNix (Gold, deutsch) | devNIX (ADR-8000) | Nix-Grok (UID-Routing: modules/10-network/1096-vpn.nix)
- nixarr (Vergleich: unser UID-Routing > deren netns) | nixflix (deklarative API-Provisioning)

## Skills (Hermes)
- `karpathy-coding-principles` (immer aktiv bei Implementierung)
- `nixos-context7-gate` (NixOS-Optionen verifizieren — `libraryId` nicht `libraryName`)
- `nixos-decimal-audit` (Nummern-Duplikate prüfen — erkennt KEINE Präfix-Kollision bei gleicher 3-stelliger Nummer!)
