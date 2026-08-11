# ---
# id: "559-playback-tuning"
# title: "Jellyfin + Audiobookshelf Playback Tuning"
# domain: 50
# folder: 55-playback
# status: draft
# complexity: 3
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-50-media.md
#   modules:
#     - path: Nix Files/modules/50-media/default.nix
# provides: []
# requires: []
# ports: [5510]
# upstream_docs: []
# forum_links: []
# upstream_github: ''
# nixpkgs_attr: 'services.jellyfin'
# state_dir: '/var/lib/jellyfin'
# uds_socket: false
# systemd_hardened: true
# ---
# 55-playback/559-playback-tuning.nix — Jellyfin/audiobookshelf playback tuning
# Source: mediNix vector store (chat history), pattern-score 0.75 (jellyfin), 0.75 (audiobookshelf)
# VERIFY services.jellyfin.* options via Context7 / nixos.org before deploy
{ lib, pkgs, config, ... }:

let
  cfg = config.grapefruitMedia.jellyfinTuning;
in
{
  options.grapefruitMedia.jellyfinTuning = {
    enable = lib.mkEnableOption "Jellyfin + Audiobookshelf playback tuning";
    softwareTranscode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "ffmpeg software transcode on server (no Pipewire/PulseAudio needed).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Jellyfin: performance tuning is done IN Jellyfin, not in Caddy.
    # ffmpeg runs server-side, client plays the finished stream.
    # Hardware accel (QSV/NVENC) auto-detected via DeviceAllow in 551-jellyfin.nix.
    services.jellyfin.ffmpeg = lib.mkDefault pkgs.ffmpeg_7;  # ⚠️ VERIFY ffmpeg_7 exists in your nixpkgs; Context7: "nixos jellyfin ffmpeg package"

    # Audiobookshelf: flush_interval -1 (streams audio like Jellyfin, same buffering issue)
    # Applied where audiobookshelf service is defined (55-wiedergabe/552-audiobookshelf.nix).
    # ⚠️ VERIFY: audiobookshelf config key for flush interval (app-level, not NixOS option).
    #   Context7: "audiobookshelf flush interval streaming"
  };
}
