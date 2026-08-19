import re

CADDY = "51-ingress/511-caddy.nix"

with open(CADDY, 'r', encoding='utf-8') as f:
    c = f.read()

# We need to find the caddyStandalone = (import ../lib/service-factory.nix ...) block
# and inject the extraConfig into it.
target = """    execStart = "${pkgs.caddy}/bin/caddy run --config /etc/caddy-media/Caddyfile";
    stateDir = registry.caddy.stateDir;
    profile = "network";
  };"""

replacement = """    execStart = "${pkgs.caddy}/bin/caddy run --config /etc/caddy-media/Caddyfile";
    stateDir = registry.caddy.stateDir;
    profile = "network";
    extraConfig = {
      Service = {
        CPUWeight = lib.mkDefault 400;
        IOWeight = lib.mkDefault 200;
        MemoryMin = lib.mkDefault "64M";
        MemoryLow = lib.mkDefault "128M";
        MemoryHigh = lib.mkDefault "512M";
        MemoryMax = lib.mkDefault "768M";
        OOMScoreAdjust = lib.mkDefault (-500);
        ManagedOOMPreference = lib.mkDefault "avoid";
      };
    };
  };"""

if target in c:
    c = c.replace(target, replacement)
    with open(CADDY, 'w', encoding='utf-8') as f:
        f.write(c)
    print("SUCCESS")
else:
    print("TARGET NOT FOUND")

