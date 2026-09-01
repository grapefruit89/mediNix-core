# Systemd Hardening-Profile — zentrale Vorlage (kein per-Modul Duplikat)

**Problem:** Jeder Dienst schrieb seinen `serviceConfig`-Hardening-Block selbst →
inkonsistent (mal `ProtectSystem=strict`, mal nicht, mal vergessen `NoNewPrivileges`).
**Lösung:** Eine zentrale `lib/hardening-profiles.nix` mit benannten Profilen, die
jeder Dienst via `mkMerge [ profiles.<profil> { service-spezifisch } ]` einbindet.

## Profile (lib/hardening-profiles.nix)
```nix
{ lib }:
let base = {
  NoNewPrivileges = true; ProtectSystem = "strict"; ProtectHome = true;
  PrivateTmp = true; UMask = "0027";          # Dateien nicht world-readable
  ProtectKernelTunables = true; ProtectKernelModules = true;
  ProtectKernelLogs = true; ProtectControlGroups = true; ProtectProc = "invisible";
  RestrictNamespaces = true; RestrictRealtime = true; RestrictSUIDSGID = true;
  LockPersonality = true; SystemCallFilter = "@system-service";
  SystemCallErrorNumber = "EPERM";            # statt SIGSYS (stiller Tod)
  CapabilityBoundingSet = ""; AmbientCapabilities = "";
  Restart = "on-failure"; RestartSec = "5s";
  InaccessiblePaths = [ "/root" "/home" "/boot" "/etc/shadow" "/etc/ssh" "/run/secrets" ];
};
  # --- networkPolicy (ersetzt alte RestrictNetworkInterfaces/IPAddressDeny) ---
  networkPolicy.loopback = { IPAddressDeny = "any"; IPAddressAllow = [ "127.0.0.1" "::1" ]; };
  networkPolicy.internet = networkPolicy.loopback // { IPAddressAllow = [ "127.0.0.1" "::1" "0.0.0.0/0" "::/0" ]; };
  networkPolicy.proxy    = {};                 # keine Restriktion (nur Caddy)
in {
  dotnet      = base // { MemoryDenyWriteExecute = false; PrivateDevices = true; } // networkPolicy.internet;
  dotnet-gpu  = dotnet // { PrivateDevices = false; };                 # Jellyfin: /dev/dri sichtbar!
  python      = base // { MemoryDenyWriteExecute = true; PrivateDevices = true; } // networkPolicy.loopback;  # SABnzbd, kein direktes Internet (VPN-ns)
  nodejs      = base // { MemoryDenyWriteExecute = false; PrivateDevices = true; } // networkPolicy.internet;
  network     = base // { MemoryDenyWriteExecute = true; PrivateDevices = true;
                          AmbientCapabilities = "CAP_NET_BIND_SERVICE";
                          CapabilityBoundingSet = "CAP_NET_BIND_SERVICE"; } // networkPolicy.proxy;
  client      = base // { MemoryDenyWriteExecute = true; PrivateDevices = true;
                          PrivateNetwork = false; };   # HTTP-Client, KEIN Port-Binding
  script      = base // { MemoryDenyWriteExecute = true; PrivateDevices = true;
                          PrivateNetwork = true; } // networkPolicy.loopback;  # bash-Timer, brauchen kein Netz
}
```

## Registry-Zuordnung (lib/registry.nix)
`mkService` bekommt 4. Arg `profile`:
- `network` → caddy, pocket-id, feishin, ntfy
- `dotnet` → sonarr, radarr, readarr, lidarr, prowlarr, seerr
- `dotnet-gpu` → jellyfin
- `python` → sabnzbd
- `nodejs` → audiobookshelf, navidrome
- `client` → 574-provisioning, 575-update-notifier (HTTP-API-Calls zu 127.0.0.1)
- `script` → cloudflare-dns, 543-mover, 571-sqlite-optimize (reine bash, kein Netz)

## Service-Modul Pattern
```nix
serviceConfig = lib.mkMerge [
  (import ../lib/hardening-profiles.nix { inherit lib; }).dotnet
  { ExecStart = "..."; User = "sonarr"; Group = "media";
    StateDirectory = "sonarr-5320"; UMask = "002";
    ReadWritePaths = [ stateDir config.medinix.storage.mediaRoot ]; }
];
```
Nie wieder `ProtectSystem=strict` etc. im Modul hart reinschreiben — kommt aus dem Profil.

## Peer-Isolation (Factory, defence-in-depth)
`lib/service-factory.nix` `mkPeerIsolation selfName allowedPeers` generiert
`InaccessiblePaths` für ALLE fremden State-Dirs aus der Registry, AUSSER
`allowedPeers`. Arr-Module (532-536) nutzen `allowedPeers = [ "sabnzbd" "prowlarr" ]`,
SABnzbd (541) `allowedPeers = []`. Module die `profiles.<profil>` direkt nutzen
(statt Factory) ziehen `mkPeerIsolation` NICHT automatisch.

## systemd service `path` Pflicht bei CLI-Tools
Ein `oneshot`-Skript das `nix`/`curl`/`jq` aufruft, läuft im harten Profil und
findet die Binaries NICHT im PATH → Build/Betrieb bricht. EXPLIZIT setzen:
`path = [ pkgs.nix pkgs.jq pkgs.curl ];` im `systemd.services.<name>`-Block
(575-update-notifier braucht das für `nix flake metadata`).

## GOTCHAS (aus Aufgabe 12a + Security-Sessions)
1. **Jellyfin = dotnet-gpu, NICHT dotnet.** `PrivateDevices=false` PFLICHT, sonst ist
   `/dev/dri` (VA-API GPU-Transcode) nicht sichtbar. `SupplementaryGroups = [ "video" ]`.
2. **.NET + Node.js brauchen `MemoryDenyWriteExecute=false`** (JIT kompiliert zur Laufzeit).
   `base` hat `true` → dotnet/nodejs-Profil ÜBERSCHREIBEN auf `false`.
3. **SABnzbd (python):** `TimeoutStopSec=30` (Harvester #992: sonst Kill-Loop beim Stop).
   `MemoryDenyWriteExecute=true` ist ok (Python braucht kein W+X).
4. **Profil-Wahl für Client-Skripte:** Skripte die nur HTTP-Requests zu `127.0.0.1`
   machen (API-Calls, flake-metadata) bekommen **`client`**, NICHT `network`
   (unnötiges `CAP_NET_BIND_SERVICE`) und NICHT `script` (blockiert Loopback →
   stiller Fail). Reproduced Bug (2026-08-11): 574-provisioning hatte erst `script`,
   dann falsch `network` (CAP_NET_BIND) → korrigiert zu `client`.
5. **LoadCredentialEncrypted + ProtectSystem=strict = KOMPATIBEL.** Credentials werden
   in `/run/credentials/<unit>/` gemountet (tmpfs, nicht betroffen von ProtectSystem).
   Kein Konflikt — systemd managed das Mount vor ExecStart.
6. **ntfy / Caddy (Go, Port-Binding):** `network`-Profil (CAP_NET_BIND_SERVICE).
   `services.ntfy-sh.serviceConfig` via `mkMerge [ profiles.network { User="ntfy"; } ]`.
7. **networkPolicy statt IPAddressDeny:** nacktes `IPAddressDeny=["any"]` ohne Allow
   blockiert Loopback. Immer `loopback`/`internet`/`proxy` aus den Profilen nutzen.
   Loopback→Loopback funktioniert IMMER (beide Dienste haben 127.0.0.1 in Allow).
