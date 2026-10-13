# Aufruf: nix repl --file repl.nix
let
  flake = builtins.getFlake (toString ./.);
  pkgs = import flake.inputs.nixpkgs { };
in
{
  inherit flake pkgs;
  inherit (pkgs) lib;
  # Schneller Zugriff auf Module und Manifeste
  manifest = flake.nixosModules.default;
  # Helfer zum Lokalisieren von Options-Ursprüngen
  where =
    optPath:
    let
      parts = pkgs.lib.splitString "." optPath;
      opt = pkgs.lib.getAttrFromPath parts (flake.nixosConfigurations.check or { }).options;
    in
    opt.declarations;
}
