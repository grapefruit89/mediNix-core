# 50-mediNix Boilerplate Tree (canonical)
Kopieren als Startpunkt für neue mediNix-Module. Liegt auf dem Agent-Host unter
`/opt/data/50-mediNix/`.

```
50-mediNix/
├── default.nix                    # importiert alle Module + options.grapefruitMedia
├── lib/
│   ├── registry.nix               # SSoT: mkService name port -> {uid=5000+port/10, gid=5000, wan, stream}
│   └── service-factory.nix        # mkService + containerIsolation (Loopback only!)
├── 51-zugang/
│   └── 512-three-way-ingress.nix  # Caddy: {svc}.local / .m7c5 / .m7c5.de(wan)
├── 52-sicherheit/
│   ├── 522-service-slimming.nix   # systemd hardening (NoNewPrivileges etc.)
│   └── 523-nftables-hardening.nix # nftables.enable, allowedTCPPorts=[22]
├── 53-beschaffung/
│   └── default.nix                # *arr Integration aus registry
└── 59-leitplanken/
    ├── 593-no-password-auth.nix   # PasswordAuthentication=false, sudo NOPASSWD
    ├── 594-backup-ssh.nix         # sshd-backup Port 2222, allowedTCPPorts+=[2222]
    └── 595-ssh-assertions.nix     # assertions: SSH an, Port22 erlaubt, kein Passwort
```

## containerIsolation (service-factory.nix) — beweisbar korrekt
```nix
containerIsolation = { extraInterfaces ? [], vpnInterface ? null }:
  { RestrictNetworkInterfaces = lib.mkDefault ([ "lo" ] ++ extraInterfaces
      ++ lib.optional (vpnInterface != null) vpnInterface); };

mkService = { name, port, ... }: let
    isolation = containerIsolation { inherit extraInterfaces vpnInterface; };
  in {
    systemd.services.${name}.serviceConfig = lib.mkMerge [ { User=name; } isolation extraSystemd ];
  };
```

## kritische Fehler (nicht wiederholen)
- `IPAddressDeny = [ "any" ]` -> tötet 127.0.0.1 Inter-Service-Talk. NIE.
- `containerIsolation` nicht als `[ isolation ]` in mkMerge -> greift nicht.
- avahi `userServices=true` vergessen -> keine `.local` Namen trotz exit 0.
- nftables ohne `22` in `allowedTCPPorts` -> 595-Assertion bricht Build ab (gewollt).
