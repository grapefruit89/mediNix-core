# ---
# id: "memory-policy"
# title: "SSoT for systemd OOMScoreAdjust and cgroup memory policies"
# domain: 50
# folder: lib
# status: active
# complexity: 2
# ---
# Defines the OOM-kill sacrifice hierarchy and cgroup v2 memory throttling.
# Rules:
# 1. Ingress & Auth (Caddy, Pocket-ID): OOMScoreAdjust = -900. Unantastbar.
# 2. Playback (Jellyfin, ABS): OOMScoreAdjust = +100 / +150. MemoryHigh = 4G. Kein hartes MemoryMax.
# 3. Acquisition (Arrs): OOMScoreAdjust = +200. MemoryHigh = 1.5G. Kein hartes MemoryMax (.NET safety).
# 4. Transfer (SABnzbd): OOMScoreAdjust = +300. Opferlamm bei RAM-Notstand (Entpack-Spitzen).
{
  lib,
  config ? { },
}:

let
  hostRam = config.medinix.host.ramGb or 16;
  calculatedGb = (hostRam * 4) / 10;
  clampedGb =
    if calculatedGb < 3 then
      3
    else if calculatedGb > 8 then
      8
    else
      calculatedGb;

  mkLimits =
    {
      oomScore ? null,
      memoryHigh ? null,
      memoryMax ? null,
      cpuWeight ? null,
      ioWeight ? null,
    }:
    lib.filterAttrs (_: v: v != null) {
      OOMScoreAdjust = if oomScore != null then oomScore else null;
      MemoryHigh = if memoryHigh != null then memoryHigh else null;
      MemoryMax = if memoryMax != null then memoryMax else null;
      CPUWeight = if cpuWeight != null then cpuWeight else null;
      IOWeight = if ioWeight != null then ioWeight else null;
    };
in
{
  inherit mkLimits;

  # Ingress & Auth: Unantastbar (-900)
  caddy = mkLimits {
    oomScore = -900;
    cpuWeight = 400;
    ioWeight = 200;
  };
  caddy-media = mkLimits {
    oomScore = -900;
    cpuWeight = 400;
    ioWeight = 200;
  };
  pocket-id = mkLimits {
    oomScore = -900;
    cpuWeight = 400;
    ioWeight = 200;
  };

  # Playback: Leicht positiv (+100 bis +150), sanftes Throttling
  jellyfin = {
    OOMScoreAdjust = 250;
    CPUWeight = 250;
    IOWeight = 200;
    MemoryMin = "1G";
    MemoryLow = "2G";
    MemoryHigh = "${toString (clampedGb * 850)}M";
    MemoryMax = "${toString clampedGb}G";
    ManagedOOMMemoryPressure = "kill";
    ManagedOOMMemoryPressureLimit = "80%";
  };
  audiobookshelf = mkLimits {
    oomScore = 150;
    cpuWeight = 150;
    ioWeight = 150;
    memoryHigh = "1G";
  };
  navidrome = mkLimits {
    oomScore = 150;
    cpuWeight = 150;
    ioWeight = 150;
    memoryHigh = "512M";
  };

  # Acquisition (Arrs): Positiv (+200), großzügiges MemoryHigh, KEIN hartes MemoryMax
  # Verhindert SIGKILLs während großer Library-Scans / Batch-Imports.
  sonarr = mkLimits {
    oomScore = 200;
    cpuWeight = 100;
    ioWeight = 100;
    memoryHigh = "1536M";
  };
  radarr = mkLimits {
    oomScore = 200;
    cpuWeight = 100;
    ioWeight = 100;
    memoryHigh = "1536M";
  };
  readarr = mkLimits {
    oomScore = 200;
    cpuWeight = 100;
    ioWeight = 100;
    memoryHigh = "1024M";
  };
  lidarr = mkLimits {
    oomScore = 200;
    cpuWeight = 100;
    ioWeight = 100;
    memoryHigh = "1024M";
  };
  prowlarr = mkLimits {
    oomScore = 200;
    cpuWeight = 100;
    ioWeight = 100;
    memoryHigh = "512M";
  };

  # Presentation & UI
  seerr = mkLimits {
    oomScore = 150;
    cpuWeight = 150;
    ioWeight = 150;
    memoryHigh = "1G";
  };
  feishin = mkLimits {
    oomScore = 200;
    cpuWeight = 100;
    ioWeight = 100;
    memoryHigh = "256M";
  };

  # Observability
  ntfy = mkLimits {
    oomScore = 100;
    cpuWeight = 200;
    ioWeight = 100;
    memoryHigh = "256M";
  };

  # Transfer: Kontrolliertes Opferlamm (+300)
  # Bei akutem Speichermangel durch Entpacken wird SABnzbd zuerst beendet.
  sabnzbd = mkLimits {
    oomScore = 300;
    cpuWeight = 40;
    ioWeight = 40;
    memoryHigh = "2G";
    memoryMax = "4G";
  };

  # Default fallback for unlisted services
  default = mkLimits {
    oomScore = 200;
    cpuWeight = 100;
    ioWeight = 100;
  };
}
