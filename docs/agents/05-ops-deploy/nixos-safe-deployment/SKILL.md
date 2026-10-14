---
name: nixos-safe-deployment
description: NixOS deployment on mediahost with anti-lockout guarantees.
---

# NixOS Safe Deployment (mediahost)

## Ziel
mediNix auf mediahost (192.168.0.10) deployen ohne SSH zu killen. Nutzt Anti-Lockout Stack (593, 594, 595) und 3-Wege-Ingress (512).

## Voraussetzungen
- SSH-Key: `/tmp/mediahost_key`
- mediNix auf mediahost: `/home/mediahost/mediNix/`
- Host: `mediahost@192.168.0.10:22`, Backup: Port `2222`

## Schritt 1: Configs prüfen
In `59-leitplanken/`:
- `593-no-password-auth.nix` (SSH-Keys only)
- `594-backup-ssh.nix` (Port 2222)
- `595-ssh-assertions.nix` (Build bricht ab bei SSH-Gefahr)

In `51-zugang/`:
- `512-three-way-ingress.nix` (3-Wege-Zugang)

## Schritt 2: Imports in `default.nix`
```nix
imports = [
  ./51-zugang/512-three-way-ingress.nix
  ./59-leitplanken/593-no-password-auth.nix
  ./59-leitplanken/594-backup-ssh.nix
  ./59-leitplanken/595-ssh-assertions.nix
];
```

## Schritt 3: Dry-Run (IMMER ZUERST!)
```bash
ssh -i /tmp/mediahost_key mediahost@192.168.0.10 "cd /home/mediahost/mediNix && nixos-rebuild dry-run --flake .#check 2>&1 | tail -20"
```
Bei `assertion failed` → **STOPP!**

## Schritt 4: Switch
```bash
ssh -i /tmp/mediahost_key mediahost@192.168.0.10 "cd /home/mediahost/mediNix && sudo nixos-rebuild switch --flake .#check 2>&1 | tail -30"
```

## Schritt 5: Verifikation
1. SSH: `ssh -i /tmp/mediahost_key mediahost@192.168.0.10`
2. Backup-SSH: `ssh -i /tmp/mediahost_key -p 2222 mediahost@192.168.0.10`
3. 3-Wege-Zugang: `curl http://sonarr.local`

## Fehlerbehebung
- **SSH weg:** mediahost neu starten (Strom aus/an), dann Port 2222 nutzen
- **nftables blockiert:** `systemctl stop nftables` (via TTY)
- **Rollback:** `nixos-rebuild rollback`

## Wichtige Regeln
1. Niemals `IPAddressDeny = [ "any" ]` ohne Loopback-Allow
2. Niemals nftables ohne Port 22 in `allowedTCPPorts`
3. Immer dry-run vor switch
4. Backup-SSH (Port 2222) immer konfiguriert

## User-Präferenz (TTY)
Bei direktem Zugriff am mediahost: **Kurze Befehle**, keine langen Erklärungen.
