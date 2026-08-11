# ---
# id: "55-wiedergabe-default"
# title: "Playback Decade Block-ID (scans 55N files)"
# domain: 50
# folder: 55-playback
# status: active
# complexity: 2
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-0000
# provides: []
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# 5N0 -- Block-ID / Fundament der Dekade (ADR-8000: N0 sammelt N1-N9, ist nie
# selbst ein Dienst). Importiert rekursiv jede 5NN-Datei/-Unterordner der Dekade.
{ lib, ... }:
{
  imports =
    let
      hier = builtins.readDir ./.;
      istDienst =
        name: typ:
        (typ == "regular" && builtins.match "^[0-9]{3}-.*\\.nix$" name != null)
        || (typ == "directory" && builtins.match "^[0-9]{3}-.*" name != null);
    in
    map (n: ./. + "/${n}") (lib.attrNames (lib.filterAttrs istDienst hier));
}
