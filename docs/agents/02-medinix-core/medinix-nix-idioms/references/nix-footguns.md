# Nix Footguns — Full Snippet Diffs

## Footgun 2 — inherit (nixpkgs.lib) lib
```nix
# WRONG (flake.nix):
registryJson = builtins.toJSON (import ./lib/registry.nix { inherit (nixpkgs.lib) lib; }).services;
# Error: lib.lib does not exist → attribute error at eval
# RIGHT:
registryJson = builtins.toJSON (import ./lib/registry.nix { lib = nixpkgs.lib; }).services;
```

## Footgun 3 — eachDefaultSystem double-nesting
```nix
# WRONG (inside eachDefaultSystem { system: ... }):
formatter.${system} = pkgs.nixfmt-rfc-style;
devShells.${system}.default = pkgs.mkShell { buildInputs = [ pkgs.nixfmt-rfc-style ]; };
# Produces formatter.x86_64-linux.x86_64-linux → invalid flake output path
# RIGHT:
formatter = pkgs.nixfmt-rfc-style;
devShells.default = pkgs.mkShell { buildInputs = [ pkgs.nixfmt-rfc-style ]; };
```

## Footgun 4 — types.path leaks secrets
```nix
# WRONG (secret path → file copied into world-readable /nix/store):
navidromeOidcFile = lib.mkOption { type = lib.types.path; default = "${cfg.secrets.secretsDir}/navidrome-oidc.env"; };
# RIGHT (path stays string, no copy):
navidromeOidcFile = lib.mkOption { type = lib.types.str; default = "${cfg.secrets.secretsDir}/navidrome-oidc.env"; };
# Exception: non-secret storage paths (mediaRoot) MAY use types.path, but mediNIX uses str.
```

## Footgun 5 — writeShellApplication for ShellCheck
```nix
# PREFER (ShellCheck runs at build):
script = pkgs.writeShellApplication {
  name = "mediNix-backup-pre";
  runtimeInputs = [ pkgs.systemd ];
  text = ''
    set -euo pipefail
    systemctl stop sonarr-5320.service 2>/dev/null || true
  '';
};
# AVOID (no ShellCheck, bash errors surface only at runtime/deploy):
script = ''systemctl stop sonarr-5320.service'';
```
