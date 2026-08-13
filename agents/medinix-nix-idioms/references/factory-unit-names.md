# Factory Unit Names — Worked Example

## The SSoT
`lib/service-factory.nix` line 47 (verified 2026-08-12):
```nix
systemd.services."${name}" = { ... };
```
`name` is passed as kebab-case from each module:
- `532-sonarr.nix`: `mkService { name = "sonarr"; ... }` → `systemd.services.sonarr` → **sonarr.service**
- `536-prowlarr.nix`: `name = "prowlarr"` → **prowlarr.service**
- `541-sabnzbd.nix`: native nixpkgs `services.sabnzbd.enable = true` → **sabnzbd.service**

## What has the port, what doesn't
| Concept | Has port? | Example |
|---------|-----------|---------|
| Unit name (systemd) | NO | `sonarr.service` |
| StateDirectory | YES | `/var/lib/sonarr-5320` |
| Socket listenStreams | YES | `127.0.0.1:5320` |

## The bug both AIs made
Confused `StateDirectory` (`/var/lib/sonarr-5320`) with the unit name, assumed
`sonarr-5320.service` existed. It does NOT. `after = [ "sonarr-5320.service" ]` points to a
non-existent unit → ordering silently broken (systemd skips unknown units in `after`).

## Correct usage in 574-provisioning.nix (fixed 2026-08-12, commit c5594c2)
```nix
after = [ "network.target" "sabnzbd.service" "prowlarr.service"
          "sonarr.service" "radarr.service" ];
```

## How to verify in any session
```bash
grep -n 'systemd.services."${name}"' lib/service-factory.nix
```
That line is the authority. Never infer unit names from `StateDirectory` paths.
