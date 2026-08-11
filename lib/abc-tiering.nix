# ---
# id: "abc-tiering"
# title: "ABC Storage Tiering Convention (mergerfs + ext4)"
# domain: 50
# folder: 50-media
# status: draft
# complexity: 3
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-30-storage.md
#   modules:
#     - path: Nix Files/modules/30-storage.nix
# provides: []
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ''
# nixpkgs_attr: ''
# state_dir: ''
# uds_socket: false
# systemd_hardened: false
# ---
# lib/abc-tiering.nix — ABC Storage Tiering convention (mergerfs + ext4)
# Source: mediNix vector store (chat history), pattern-score 0.71
# VERIFY mergerfs / snapraid nixos options via Context7 / nixos.org before deploy
#
# Architecture decision (Gold Standard from chat + ADR-30-storage):
#   Tier A (NVMe/High-Speed): system state, SQLite DBs (WAL pragmas)
#   Tier B (SATA SSD): SABnzbd active downloads + unpack workspace
#   Tier C (HDD mergerfs): long-term media pool (Hot/Warm/Cold)
#
# mergerfs: the dev explicitly does NOT include a built-in spin-down / smart
# tier-move — that is a known gap. mediNix fills it with event-driven moves
# (see 57-maintenance), not legacy cron.
#
# NOTE: this is a lib (returns attrset), imported like registry.nix:
#   (import ../lib/abc-tiering.nix { inherit lib; })
{ lib, ... }:

{
  # SSoT anchor paths. Actual mount units live in 53-acquisition (Tier B)
  # and 55-playback (Tier C paths) — this file only declares the convention.
  tiering = {
    a = "/var/lib";        # state + sqlite (WAL), SSD/NVMe
    b = "/data/downloads"; # sabnzbd workspace (SSD, Tier B)
    c = "/data/media";     # mergerfs media pool (HDD, Tier C)
  };

  # mergerfs mount flags mandated by ADR-30-storage (VERIFY against current nixpkgs):
  #   category.create = "ff"   (first-found write -> SSD cache)
  #   minfreespace    = "50G"  (avoid disk-full lockups)
  #   dropcacheonclose = true  (allow hd-idle spindown)
}
