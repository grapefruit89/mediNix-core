# ---
# id: "_helpers"
# title: "Kleine Nix-Helfer fuer mediNix-Module"
# domain: 50
# folder: "lib"
# status: deprecated
# complexity: 1
# last_reviewed: 2026-10-15
# links:
#   adr: ADR-0000
# ---
# NIE VERDRAHTET (Entscheidung 2026-10-15): `recursiveMergeAttrs` ist redundant zu
# `lib.mkMerge` (Listen werden dort ebenfalls konkateniert; 28 Dateien nutzen es).
# NICHT importieren - siehe lib/README.md.
# lib/_helpers.nix
# Private helper functions for mediNix-core (prefixed with _ to prevent module auto-import)
{ lib }:

rec {
  # recursiveMergeAttrs: Rekursives Mergen von Attrsets, das Listen zusammenführt (konkateniert)
  # statt sie wie lib.recursiveUpdate zu überschreiben.
  recursiveMergeAttrs =
    lhs: rhs:
    lib.zipAttrsWith
      (
        _name: values:
        let
          first = builtins.head values;
        in
        if builtins.length values == 1 then
          first
        else if builtins.isAttrs first then
          recursiveMergeAttrs (builtins.elemAt values 0) (builtins.elemAt values 1)
        else if builtins.isList first then
          lib.concatLists values
        else
          lib.last values
      )
      [
        lhs
        rhs
      ];
}
