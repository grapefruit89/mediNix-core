# ---
# id: "hardening-profiles"
# title: "Systemd Hardening Profiles (central, not per-module)"
# domain: 50
# folder: 50-media
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5050
#   skill: nixos-context7-gate
# context7:
#   - query: "systemd.services serviceConfig NoNewPrivileges ProtectSystem MemoryDenyWriteExecute"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "NoNewPrivileges=true, ProtectSystem=strict, MemoryDenyWriteExecute=true valid"
# ---
{ lib }:

# Zentrale Hardening-Profile. Jeder Dienst bekommt genau EIN Profil aus der
# Registry (svc.hardeningProfile). Inkonsistente per-Modul serviceConfig-Blöcke
# werden dadurch eliminiert (ADR-5050).

# ── Basis: für alle Dienste gleich ──────────────────────────────────────────
base = {
  NoNewPrivileges       = true;
  ProtectSystem         = "strict";
  ProtectHome           = true;
  PrivateTmp            = true;
  ProtectKernelTunables = true;
  ProtectKernelModules  = true;
  ProtectKernelLogs     = true;
  ProtectControlGroups  = true;
  ProtectProc           = "invisible";
  RestrictNamespaces    = true;
  RestrictRealtime      = true;
  RestrictSUIDSGID      = true;
  LockPersonality       = true;
  SystemCallFilter      = "@system-service";
  SystemCallErrorNumber = "EPERM";  # statt SIGSYS (stiller Tod)
  CapabilityBoundingSet = "";
  AmbientCapabilities   = "";
  Restart               = "on-failure";
  RestartSec            = "5s";
};

# ── .NET-Dienste (Sonarr/Radarr/Readarr/Lidarr/Prowlarr/Jellyseerr) ────────
# .NET JIT braucht ausführbaren Speicher → MemoryDenyWriteExecute = false
dotnet = base // {
  MemoryDenyWriteExecute = false;
  PrivateDevices         = true;   # keine Hardware nötig
};

# ── .NET mit GPU (Jellyfin) ─────────────────────────────────────────────────
# /dev/dri muss sichtbar sein (VA-API). DeviceAllow per-Dienst via extraConfig.
dotnet-gpu = dotnet // {
  PrivateDevices = false;
};

# ── Python (SABnzbd) ───────────────────────────────────────────────────────
python = base // {
  MemoryDenyWriteExecute = true;   # Python braucht kein W+X
  PrivateDevices         = true;
};

# ── Node.js (Audiobookshelf, Navidrome) ────────────────────────────────────
# V8 JIT braucht W+X → MemoryDenyWriteExecute = false
nodejs = base // {
  MemoryDenyWriteExecute = false;
  PrivateDevices         = true;
};

# ── Netzwerk-Dienste mit Port-Binding (Caddy, ntfy, Feishin-SPA via Caddy) ─
network = base // {
  MemoryDenyWriteExecute = true;
  PrivateDevices         = true;
  AmbientCapabilities    = "CAP_NET_BIND_SERVICE";
  CapabilityBoundingSet  = "CAP_NET_BIND_SERVICE";
};

# ── Bash-Skripte (Mover, Maintenance-Timer) ────────────────────────────────
script = base // {
  MemoryDenyWriteExecute = true;
  PrivateDevices         = true;
  PrivateNetwork         = true;  # Skripte brauchen kein Netz
};
