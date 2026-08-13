# Remote vserver Provisioning — Notes

## Host (Session 2026-06-03)
- Provider intern: **Special 1**
- Hostname: `mo's pc`
- IPv4: `77.90.42.6`
- IPv6: `2a06:de00:401:908e::1`
- SSH: root, password-auth offen, pubkey möglich
- Base OS: Debian GNU/Linux trixie (Testing), Kernel 6.12.74+deb13+1-amd64
- Besonderheit: `/usr/local/bin` zunächst nicht existent; `xz` per apt nicht verfügbar
- Repo-Quelle: `/opt/data/NixOS` (ZIP-Import), Windows-Quelle `C:\\Users\\morit\\Documents\\Obsidian_Main\\NixOS`

## Sessionspezifische Erkenntnisse

### Stabiler Debian-Trixie-Workflow
- `apt-get install xz` scheitert: korrekt ist **`apt-get install -y xz-utils`**.
- `/usr/local/bin` existiert initial nicht — zuerst `mkdir -p /usr/local/bin`.
- GitHub-Release-Binary für xz (z. B. 5.6.4) liefert 404 — **nicht verwenden**.
- Root-Installation von Nix scheitert mit `group 'nixbld' does not exist`:
  ```bash
  groupadd -f nixbld && useradd -r -g nixbld -G nixbld -s /usr/sbin/nologin -d /var/empty nix
  ```
- Nix nach Installation: `. /root/.nix-profile/etc/profile.d/nix.sh` in neuer Session.
- `nix build` mit absoluten Pfaden zur `configuration.nix` bricht mit `access to absolute path ... is forbidden in pure evaluation mode` — **immer `--impure` verwenden**.
- Korrekter Build-Attribut-Pfad:
  ```
  .#nixosConfigurations.<host>.config.system.build.toplevel
  ```
- `nixos-anywhere` auf dem Zielhost selbst ausführen: Endet in SSH-Loop über `ssh-copy-id` — **nicht verwenden**, stattdessen lokalen Build + `switch-to-configuration boot && switch`.
- `ssh-copy-id` mit `Connection reset by peer` / `Permission denied (publickey,password)`: Lokaler Build umgeht das.
- Nach `switch-to-configuration boot` kann SSH temporär wegfallen — normaler Reboot-Vorgang, kein Fehler.
- Remote-Status-Check: `ps aux | grep nix | grep -v grep | wc -l` + Prüfung auf `/nix/store/*-system-toplevel`.

### Hard Rules für vserver-Deploys
- **Kein `nixos-anywhere` auf demselben Host, der gleichzeitig Deploy-Host ist.**
- **Ein Script, ein Befehl, fertig.** Schritt-für-Schritt-Ketten vermeiden.
- **Reboot nur, wenn `/nix/store/*-system-toplevel` existiert.**
