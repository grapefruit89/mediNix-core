# ---
# id: "50-core-gpu"
# title: "GPU hardware acceleration abstraction"
# domain: 50
# folder: "50-core"
# status: active
# kind: library
# complexity: 3
# last_reviewed: 2026-11-26
# links:
#   adr: ADR-0000
# provides: ["gpuLib"]
# requires: []
# ---
#
# Herstellerunabhaengige Hardwarebeschleunigung:
# Leitet Geraete, Pakete und ffmpeg-Methoden (Intel, AMD, NVIDIA, None) aus Optionen ab.
{ lib, pkgs }:
let
  vendors = {

    # ── Intel (Gen 8+ bis Arc/Battlemage) ────────────────────────────────────
    intel = {
      description = "Intel QuickSync über VAAPI";
      hwaccel = "vaapi";
      devices = [
        "/dev/dri"
        "/dev/dri/card0"
        "/dev/dri/renderD128"
      ];
      renderDevice = "/dev/dri/renderD128";
      packages = with pkgs; [
        intel-media-driver
        vpl-gpu-rt
        libva-utils
      ];
      groups = [
        "video"
        "render"
      ];
    };

    # ── AMD (GCN und neuer) ──────────────────────────────────────────────────
    amd = {
      description = "AMD über VAAPI (Mesa)";
      hwaccel = "vaapi";
      devices = [
        "/dev/dri"
        "/dev/dri/card0"
        "/dev/dri/renderD128"
      ];
      renderDevice = "/dev/dri/renderD128";
      packages = with pkgs; [
        mesa
        libva-utils
      ];
      groups = [
        "video"
        "render"
      ];
    };

    # ── NVIDIA ───────────────────────────────────────────────────────────────
    nvidia = {
      description = "NVIDIA NVENC/NVDEC";
      hwaccel = "nvenc";
      devices = [
        "/dev/nvidia0"
        "/dev/nvidiactl"
        "/dev/nvidia-modeset"
        "/dev/nvidia-uvm"
        "/dev/nvidia-uvm-tools"
      ];
      renderDevice = "";
      packages = with pkgs; [
        nvidia-vaapi-driver
        libva-utils
      ];
      groups = [ "video" ];
    };

    # ── Keine Beschleunigung ─────────────────────────────────────────────────
    none = {
      description = "Software-Transkodierung (CPU)";
      hwaccel = "none";
      devices = [ ];
      renderDevice = "";
      packages = [ ];
      groups = [ ];
    };
  };

  detect =
    hostConfig:
    let
      hasNvidia =
        (hostConfig.hardware.nvidia.modesetting.enable or false)
        || (lib.elem "nvidia" (hostConfig.services.xserver.videoDrivers or [ ]))
        || (hostConfig.hardware.nvidia-container-toolkit.enable or false);
      hasGraphics = hostConfig.hardware.graphics.enable or false;
    in
    if hasNvidia then
      "nvidia"
    else if hasGraphics then
      "intel"
    else
      "none";

  resolve = accel: vendors.${accel} or vendors.none;
in
{
  inherit vendors detect resolve;

  accelTypes = [
    "auto"
    "intel"
    "amd"
    "nvidia"
    "vaapi"
    "none"
  ];

  normalize = accel: if accel == "vaapi" then "amd" else accel;
}
