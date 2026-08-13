# 50-mediNix Boilerplate Gotchas

## 1. containerIsolation never reaches the systemd unit
Symptom: build succeeds, but `systemctl cat <svc>` shows no `RestrictNetworkInterfaces`.
Cause: `containerIsolation` result was bound to a variable `isolation` but NOT placed as a LIST element inside `lib.mkMerge`.
Correct pattern:
```nix
isolation = containerIsolation { inherit extraInterfaces vpnInterface; };
systemd.services.${name}.serviceConfig = lib.mkMerge [
  { User = name; Group = "media"; UMask = "0002"; }
  isolation          # MUST be a list element
  extraSystemd
];
```
A bare `serviceConfig = isolation;` (outside mkMerge) or omitting it from the list → silently ignored.

## 2. `.local` names never appear
Cause: avahi publish without `userServices = true`. Exit code is still 0 — silent failure.
Fix: `services.avahi.publish = { enable = true; userServices = true; addresses = true; };`

## 3. nftables kills SSH
`networking.nftables.enable = true` with no `allowedTCPPorts = [ 22 ]` → assertion 595 aborts the build. Keep port 22 in `allowedTCPPorts` always.

## 4. IPAddressDeny = [ "any" ] is a trap
Looks like hardening but blocks inter-service loopback (Sonarr→Jellyfin over 127.0.0.1). Use ONLY `RestrictNetworkInterfaces = [ "lo" ]`. User mandate: services must see each other.

## 5. Workspace never to touch
`/opt/data/knowledge/` is read-only external docs. Boilerplate lives at `/opt/data/50-mediNix/`. Repo clone at `/opt/data/github_repos/mediNix/`. Docs at `/opt/data/docs/{ADR,OPS,nix}/`.
