import os
import re

CADDY = "51-ingress/511-caddy.nix"
FEISHIN = "55-playback/554-feishin.nix"

# 1. Update Caddy
with open(CADDY, 'r', encoding='utf-8') as f:
    c = f.read()
if "MemoryMin" not in c:
    c = c.replace(
        'profile = "network";\n    };',
        '''profile = "network";
    extraConfig = {
      Service = {
        MemoryMin = "64M";
        MemoryLow = "64M";
        ManagedOOMPreference = "avoid";
        OOMScoreAdjust = -500;
        CPUWeight = 400;
        IOWeight = 200;
      };
    };
  };'''
    )
    with open(CADDY, 'w', encoding='utf-8') as f:
        f.write(c)

# 2. Update Feishin
with open(FEISHIN, 'r', encoding='utf-8') as f:
    fe = f.read()

fe = fe.replace(
'''      file_server * {
        root * ${pkgs.feishin-web}/share/feishin-web
        try_files {path} /index.html
      }''',
'''      root * ${pkgs.feishin-web}/share/feishin-web
      try_files {path} /index.html
      file_server'''
)
fe = fe.replace(
'''        file_server * {
          root * ${pkgs.feishin-web}/share/feishin-web
          try_files {path} /index.html
        }''',
'''        root * ${pkgs.feishin-web}/share/feishin-web
        try_files {path} /index.html
        file_server'''
)

with open(FEISHIN, 'w', encoding='utf-8') as f:
    f.write(fe)

