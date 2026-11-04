# ---
# id: "medinix-cli-default"
# title: "mediNix Health-CLI — Paket-Layout"
# domain: 50
# folder: "packages/medinix-cli"
# status: active
# kind: package
# complexity: 1
# last_reviewed: 2026-11-04
# links:
#   adr: ADR-0000
# ---
# Nix-Paket-Layout: `callPackage ./packages/medinix-cli` loest auf diese
# Datei auf. Reiner Durchreicher — die Argumentliste steht EINMAL in
# cli.nix; ein neues Argument dort muss hier nicht nachgezogen werden.
# `pkgs` muss benannt sein: callPackage fuellt autoArgs nur fuer deklarierte
# Formalparameter (intersectAttrs), nicht fuer `...`. Es wird im Rumpf erneut
# eingesetzt, damit deadnix den Parameter nicht als unbenutzt meldet.
{ pkgs, ... }@args: import ./cli.nix (args // { inherit pkgs; })
