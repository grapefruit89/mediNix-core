# Caddy Plugins in nixpkgs — Build-in Pattern

## Problem
`pkgs.caddy` from nixpkgs ships WITHOUT any plugins. A Caddyfile that references a
plugin (e.g. CrowdSec AppSec bouncer `caddy-cs-bouncer`) breaks `nix flake check`
with a config parse error — the directive simply does not exist in the binary.

## Fix — compile the plugin in
Use `pkgs.caddy.withPlugins` (nixpkgs >= 25.05). Context7-verified against
`/nixos/nixpkgs` (release notes rl-2505: "Caddy can now be built with plugins").

```nix
services.caddy.package = pkgs.caddy.withPlugins {
  plugins = [
    "github.com/crowdsecurity/caddy-cs-bouncer@latest"
  ];
  # hash is the vendorHash of the source with plugins included.
  # OMIT -> build fails and prints the CORRECT hash. Use lib.fakeHash as a
  # placeholder, run `nix build`, read the hash from the error, then replace.
  hash = lib.fakeHash;
};
```

## Rules
- Set `services.caddy.package` ONLY when the plugin is actually needed
  (`mkIf cfg.observability.crowdsec.enable`). Otherwise leave `pkgs.caddy` default.
- `hash = lib.fakeHash` is the HONEST placeholder — never guess a hash. The first
  `nix build` surfaces the exact required `sha256-...`. Record it in ONBOARDING.md
  as a "known gotcha" for the consumer.
- All plugin entries MUST carry a version/tag (`@latest` or `@v1.2.3`). Plugins
  without tags need a pseudo-version from `go.mod` — prefer `@latest` for simplicity.

## Consumer wiring (mediNix-core)
- `582-crowdsec.nix`: native `services.crowdsec` agent (NO Docker), listens on
  `127.0.0.1:8081`. Caddy AppSec plugin talks to that local agent.
- `511-caddy.nix`: sets `services.caddy.package` when `cfg.observability.crowdsec.enable`.
- Registry: `crowdsec` = mkNoPort "crowdsec" 582 "none" (no port, Caddy plugin only).

## Why not Docker
On NixOS migration, the Unraid Docker-CrowdSec is replaced by the native
`services.crowdsec` systemd unit. Caddy is never a container — it's the chameleon
ingress (511-caddy.nix). The plugin is compiled into the Caddy package so the
single Caddy instance can enforce AppSec.
