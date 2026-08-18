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
#   - query: "systemd.services serviceConfig NoNewPrivileges ProtectSystem MemoryDenyWriteExecute IPAddressAllow"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "NoNewPrivileges=true, ProtectSystem=strict, IPAddressAllow/Deny valid (Loopback isolation)"
# ---
{ lib }:

# Zentrale Hardening-Profile. Jeder Dienst bekommt genau EIN Profil aus der
# Registry (svc.hardeningProfile). Inkonsistente per-Modul serviceConfig-Blöcke
# werden dadurch eliminiert (ADR-5050).
rec {

# ── Netzwerk-Policy: wer darf wohin? ────────────────────────────────────────
# loopback: nur 127.0.0.1/::1 — kein Internet (SABnzbd geht durch VPN-ns)
# internet: Loopback + Internet — Metadaten/Indexer-Suche (Arr/Jellyfin/etc.)
# proxy:    alles erlaubt — nur Caddy (der Reverse-Proxy)
networkPolicy.loopback = {
  IPAddressDeny  = "any";
  IPAddressAllow = [ "127.0.0.1" "::1" ];
};
networkPolicy.internet = {
  IPAddressDeny  = "any";
  IPAddressAllow = [ "127.0.0.1" "::1" "0.0.0.0/0" "::/0" ];
};
networkPolicy.proxy = {};  # keine IPAddress-Restrictions

# ── Basis: für alle Dienste gleich ──────────────────────────────────────────
base = {
  NoNewPrivileges       = true;
  ProtectSystem         = "strict";
  ProtectHome           = true;
  PrivateTmp            = true;
  UMask                 = "0027";  # Dateien nicht world-readable
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
  SystemCallArchitectures = "native";  # nur native Syscall-Architektur (kein i386 etc.)
  ProtectClock          = true;   # UTC-Hardware-Clock schützen
  ProtectHostname       = true;   # Hostname-Änderungen verweigern
  RemoveIPC             = true;   # POSIX-IPC Objekte nach Exit aufräumen
  OOMScoreAdjust        = 500;    # Dienste zuerst vom OOM-Killer erwischen
  CapabilityBoundingSet = "";
  AmbientCapabilities   = "";
  Restart               = "on-failure";
  RestartSec            = "5s";
  # InaccessiblePaths: sensible Bereiche für ALLE Dienste gesperrt
  InaccessiblePaths = [
    "/root"
    "/home"
    "/boot"
    "/etc/shadow"
    "/etc/ssh"
    "/run/secrets"  # sops-nix / agenix secrets anderer Dienste
  ];
};

# ── .NET-Dienste (Sonarr/Radarr/Readarr/Lidarr/Prowlarr/Jellyseerr) ────────
# .NET JIT braucht ausführbaren Speicher → MemoryDenyWriteExecute = false
dotnet = base // {
  MemoryDenyWriteExecute = false;
  PrivateDevices         = true;   # keine Hardware nötig
  UMask                  = "0002";  # P0-6 FIX: Arr-Stack braucht Gruppen-Schreibrechte (0027 aus base reicht nicht)
} // networkPolicy.internet;  # Indexer-Suche braucht Internet

# ── .NET mit GPU (Jellyfin) ─────────────────────────────────────────────────
# /dev/dri muss sichtbar sein (VA-API). DeviceAllow per-Dienst via extraConfig.
dotnet-gpu = dotnet // {
  PrivateDevices = false;
} // networkPolicy.internet;  # Metadaten-Download (TMDB etc.)

# ── Python (SABnzbd) ───────────────────────────────────────────────────────
python = base // {
  MemoryDenyWriteExecute = true;   # Python braucht kein W+X
  PrivateDevices         = true;
} // networkPolicy.loopback;  # nur Loopback — geht durch VPN-ns, kein direktes Internet

# ── Node.js (Audiobookshelf, Navidrome) ────────────────────────────────────
# V8 JIT braucht W+X → MemoryDenyWriteExecute = false
nodejs = base // {
  MemoryDenyWriteExecute = false;
  PrivateDevices         = true;
} // networkPolicy.internet;  # Cover-Downloads brauchen Internet

# ── Netzwerk-Dienste mit Port-Binding (Caddy, ntfy, Feishin-SPA via Caddy) ─
network = base // {
  MemoryDenyWriteExecute = true;
  PrivateDevices         = true;
  AmbientCapabilities    = "CAP_NET_BIND_SERVICE";
  CapabilityBoundingSet  = "CAP_NET_BIND_SERVICE";
  OOMScoreAdjust         = -500;   # Caddy/ntfy: letzte die OOM-Killer erwischt (Proxy muss überleben)
} // networkPolicy.proxy;  # Caddy = Proxy, darf alles

# ── Client-Skripte (HTTP-Requests, kein Port-Binding) ──────────────────────
# Wie script, aber PrivateNetwork=false (HTTP zu 127.0.0.1 erlaubt)
# Kein CAP_NET_BIND_SERVICE — binden keine Ports
client = base // {
  MemoryDenyWriteExecute = true;
  PrivateDevices         = true;
  PrivateNetwork         = false;
};

# ── Bash-Skripte (Mover, Maintenance-Timer) ────────────────────────────────
script = base // {
  MemoryDenyWriteExecute = true;
  PrivateDevices         = true;
  PrivateNetwork         = true;  # Skripte brauchen kein Netz
} // networkPolicy.loopback;  # nur Loopback falls sie localhost ansprechen
}
