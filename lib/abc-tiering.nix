# ---
# id: "abc-tiering"
# title: "ABC Storage Tiering Convention (portabel, mediaRoot-based)"
# domain: 50
# folder: 50-media
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5043
# provides: ["tierA", "tierB", "tierC"]
# requires: ["lib/abc-tiering"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# lib/abc-tiering.nix — ABC Storage Tiering convention (portabel)
# Tier paths derived from cfg.storage.mediaRoot (Regel 3: no hardcoded paths).
# Import: (import ../lib/abc-tiering.nix { cfg = config.medinix; })
{ cfg }:
{
  # Tier A: System-State, Datenbanken, Secrets (NVMe/SATA-SSD)
  tierA = svc: "/var/lib/${svc}";
  # Tier B: Downloads-Cache, schneller Pool (SATA-SSD)
  tierB = cfg.storage.mediaRoot + "/downloads";
  # Tier C: Medien-Bibliothek, Cold Storage (HDD)
  tierC = cfg.storage.mediaRoot + "/library";
}
