# ---
# id: "repl"
# title: "Nix-REPL mit gepinnten nixpkgs"
# domain: 50
# folder: 50-core
# status: active
# complexity: 1
# last_reviewed: 2026-10-15
# links:
#   adr: ADR-0000
# ---
# Aufruf: nix repl --file 50-core/repl.nix
let
  flake = builtins.getFlake (toString ./..);
  pkgs = import flake.inputs.nixpkgs { };
in
{
  inherit flake pkgs;
  inherit (pkgs) lib;
  # Schneller Zugriff auf Module und Manifeste
  manifest = flake.nixosModules.default;
  # Helfer zum Lokalisieren von Options-Ursprüngen (Alternative: nixos-option <option>)
  where =
    optPath:
    let
      parts = pkgs.lib.splitString "." optPath;
      checkCfg = flake.nixosConfigurations.check or null;
      opts = if checkCfg != null then checkCfg.options or { } else { };
      opt = pkgs.lib.attrByPath parts null opts;
    in
    if opt != null && opt ? declarations then opt.declarations else null;
}
