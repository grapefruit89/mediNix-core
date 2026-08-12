# CrowdSec-Plugin-Hash — Build-Vorbereitung

`51-ingress/511-caddy.nix` nutzt `caddy.withPlugins` für den CrowdSec-Bouncer:
```nix
services.caddy.package = lib.mkIf cfg.observability.crowdsec.enable (pkgs.caddy.withPlugins {
  plugins = [ "github.com/hslatman/caddy-crowdsec-bouncer@latest" ];
  hash = lib.fakeHash;  # ← PLATZHALTER
});
```

## Status
- `hash = lib.fakeHash` ist ein **bewusster Platzhalter** (Build-Fehler zeigt den korrekten Hash).
- **CrowdSec ist default = false** (`observability.crowdsec.enable`). Solange CrowdSec NICHT aktiviert
  ist, ist dieser Pfad NICHT im Build — `nix flake check` läuft auch mit fakeHash durch.
- Erst wenn `observability.crowdsec.enable = true` → Build bricht mit Hash-Mismatch.

## Hash ermitteln (auf einer Nix-Maschine, z.B. Build-Host oder q958)
```bash
# Echten Hash holen (Build-Fehler zeigt ihn, oder proaktiv ermitteln):
nix build --impure -E 'with import <nixpkgs> {};
  caddy.withPlugins { plugins = ["github.com/hslatman/caddy-crowdsec-bouncer@latest"]; hash = lib.fakeHash; }' 2>&1 \
  | grep -oE 'got: [a-z0-9]+' | head -1
# → "got: sha256-xxxxxxxxxxxx..." → den Hash (ohne "sha256-") in 511-caddy.nix eintragen:
#   hash = "xxxxxxxxxxxx...";
```

## Nach dem Hash-Eintrag
```bash
nix flake check .#checks.x86_64-linux.nixos-check   # Ratsche: evaluiert komplettes Modul
nix build .#nixosConfigurations.check.config.system.build.toplevel  # voller System-Build
```

## Hinweis
- FakeHash ersetzt erst kurz vor Deploy (Hash ist nixpkgs-/Plugin-Version-abhängig).
- Wenn CrowdSec vorerst nicht genutzt wird: `observability.crowdsec.enable = false` lassen →
  kein Build-Blocker.
