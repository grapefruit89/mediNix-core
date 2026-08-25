# NixOS Modul-Bugs (selbst von Hermes gebaut, vom User korrigiert)

Diese Fehler sind in mediNix-core aufgetreten und HABEN den Build oder die
Assertions stillschweigend kaputt gemacht. NIEMALS wiederholen.

## Bug A — `cfg.security.enable` existiert NICHT
Symptom: Alle Guardrail-Assertionen feuern nie (Bedingung immer false), Build
passiert trotz falscher Config.
Cause: `sed` ersetzte `cfg.enable` durch `cfg.security.enable`. Aber der
Top-Level-Enable in mediNix-core ist `config.medinix.enable`, NICHT
`config.medinix.security.enable`. `security.*` sind NUR Unter-Optionen
(`cfg.security.emergencyUser.enable`), nicht der Gating-Schalter.
Richtig: Modul-Gating immer `lib.mkIf cfg.enable { ... }`.

## Bug B — `cfg.services.X.enable` falscher Pfad
Symptom: Dienst-spezifische Checks matchen nie.
Cause: mediNix-core nutzt flache Options (`cfg.jellyfin.enable`,
`cfg.sabnzbd.enable`, `cfg.prowlarr.enable`) — NICHT `cfg.services.jellyfin.enable`.
`cfg.services\.` ist IMMER falsch in diesem Repo.

## Bug C — `config.systemd.services.X` beim Definieren lesen = Infinite Recursion
Symptom: kryptischer Recursion-Error beim Build.
Cause: Querschnitts-Modul wollte `sandboxAttrs` per `lib.recursiveUpdate` auf
`config.systemd.services.sabnzbd` legen — liest also `config.*` während es
`config.systemd.services.sabnzbd` definiert.
FALSCH:
```nix
systemd.services.sabnzbd = lib.recursiveUpdate config.systemd.services.sabnzbd sandboxAttrs;
```
RICHTIG (mkMerge, kein Lesen aus config):
```nix
systemd.services.sabnzbd = lib.mkIf config.services.sabnzbd.enable (lib.mkMerge [ sandboxAttrs ]);
```
Das Querschnitts-Modul DEFINIERT `sandboxAttrs`, die Ziel-Unit bekommt es per
`mkMerge` — niemals aus `config.*` lesen während man es schreibt.

## Bug D — Bash `PROBLEMS=$((PROBLEMS+1))` in `while read` Subshell zählt nie
Symptom: `cmd_check` gibt immer "✅ Alle Checks bestanden" zurück, egal was kaputt ist.
Cause: `while read -r ...; do ...; PROBLEMS=$((PROBLEMS+1)); done` läuft in einer
Subshell (Pipe). Variablenänderungen in Subshells propagieren NICHT nach außen.
Der Counter bleibt 0 → falscher "OK"-Report (stillschweigendes False-Negative).
RICHTIG (mktemp-Datei statt Subshell-Variable):
```bash
PROBLEMS_FILE=$(mktemp)
echo "0" > "$PROBLEMS_FILE"
add_problem() { echo $(($(cat "$PROBLEMS_FILE") + 1)) > "$PROBLEMS_FILE"; }
# im Loop statt PROBLEMS=$((PROBLEMS+1)):  add_problem
# am Ende: PROBLEMS=$(cat "$PROBLEMS_FILE"); rm -f "$PROBLEMS_FILE"
```
Alternativ: Process-Substitution `while ...; do done < <(cmd)` (keine Subshell)
oder den ganzen Check in EINE Funktion ohne Pipe legen.

## Bug E — Falscher CrowdSec-Caddy-Plugin-Name (Build-Blocker)
Symptom: `nix build` mit `pkgs.caddy.withPlugins` scheitert still (Plugin nicht gefunden).
Cause: `github.com/crowdsecurity/caddy-cs-bouncer` existiert NICHT mehr aktiv.
Der korrekte Maintainer ist `github.com/hslatman/caddy-crowdsec-bouncer`.
RICHTIG: `plugins = [ "github.com/hslatman/caddy-crowdsec-bouncer@latest" ];`
Fund via Vektor-DB-Sweep (Topic-Split, mehrere Chunks bestätigten hslatman).
WICHTIG: vor erstem Build den Hash via `nix build --impure` ermitteln (ONBOARDING.md).

## TPM `systemd-creds` Secret-Workflow (SABnzbd/Jellyfin/Cloudflare)
Secrets NIEMALS im Nix-Store / in Optionen als Plaintext. Pattern:
- Option: `cfg.sabnzbd.serverCredentialFile` (nullOr path, .cred-Pfad).
- Unit: `serviceConfig.LoadCredentialEncrypted = [ "mediNix-sabnzbd-server:${cfg.serverCredentialFile}" ];`
- Env: `SABNZBD__SERVER_0__CREDENTIAL_FILE = "/run/credentials/sabnzbd.service/mediNix-sabnzbd-server";`
- Erzeugung auf q958: `systemd-creds encrypt --with-key=tpm2+host /tmp/plain.txt /var/lib/systemd/credential.d/mediNix-<name>.cred`
- `.cred`-Datei ist ohne DIESES TPM wertlos → darf ins Repo.
- `INV-SECRET` Invariante (599-cross-domain.nix) bricht den Build wenn ein
  Secret-Pfad mit `/nix/store/` beginnt.


Um Service-Metadaten (UIDs/Ports/State-Dirs) zur Build-Zeit in ein Script zu
einbetten (z.B. Health-CLI `medinix`):
```nix
# flake.nix (outputs-let):
registryJson = builtins.toJSON (import ./lib/registry.nix { inherit (nixpkgs.lib) lib; }).services;
# default.nix config-Block:
environment.systemPackages = lib.mkIf cfg.cli.enable [
  (pkgs.callPackage ./packages/mediNix-cli {
    inherit lib;
    registryJson = builtins.toJSON (import ./lib/registry.nix { inherit lib; }).services;
  })
];
# packages/mediNix-cli/default.nix:
pkgs.writeShellApplication {
  name = "medinix";
  runtimeInputs = [ systemd sqlite jq curl coreutils util-linux gawk findutils iproute2 ];
  text = '' ... SERVICES_JSON='${registryJson}' ... '';
}
```
`writeShellApplication` (nixpkgs) macht automatisch `set -euo pipefail` + shellcheck.
