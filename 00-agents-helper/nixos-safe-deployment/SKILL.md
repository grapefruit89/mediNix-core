---
name: nixos-safe-deployment
description: NixOS deployment on q958 with anti-lockout guarantees.
---

# NixOS Safe Deployment (q958)

## Ziel
mediNix auf q958 (192.168.2.73) deployen ohne SSH zu killen. Nutzt Anti-Lockout Stack (593, 594, 595) und 3-Wege-Ingress (512).

## Voraussetzungen
- SSH-Key: `/tmp/q958_key`
- mediNix auf q958: `/home/jarvis/mediNix/`
- Host: `jarvis@192.168.2.73:22`, Backup: Port `2222`

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
ssh -i /tmp/q958_key jarvis@192.168.2.73 "cd /home/jarvis/mediNix && nixos-rebuild dry-run --flake .#check 2>&1 | tail -20"
```
Bei `assertion failed` → **STOPP!**

## Schritt 4: Switch
```bash
ssh -i /tmp/q958_key jarvis@192.168.2.73 "cd /home/jarvis/mediNix && sudo nixos-rebuild switch --flake .#check 2>&1 | tail -30"
```

## Schritt 5: Verifikation
1. SSH: `ssh -i /tmp/q958_key jarvis@192.168.2.73`
2. Backup-SSH: `ssh -i /tmp/q958_key -p 2222 jarvis@192.168.2.73`
3. 3-Wege-Zugang: `curl http://sonarr.local`

## Fehlerbehebung
- **SSH weg:** q958 neu starten (Strom aus/an), dann Port 2222 nutzen
- **nftables blockiert:** `systemctl stop nftables` (via TTY)
- **Rollback:** `nixos-rebuild rollback`

## Wichtige Regeln
1. Niemals `IPAddressDeny = [ "any" ]` ohne Loopback-Allow
2. Niemals nftables ohne Port 22 in `allowedTCPPorts`
3. Immer dry-run vor switch
4. Backup-SSH (Port 2222) immer konfiguriert

## User-Präferenz (TTY)
Bei direktem Zugriff am q958: **Kurze Befehle**, keine langen Erklärungen.
