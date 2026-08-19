import re

PATH = "54-transfer/541-sabnzbd.nix"
with open(PATH, 'r', encoding='utf-8') as f:
    c = f.read()

# 1. Add persist
if 'grapefruitMedia.persist.extraPaths =' not in c:
    c = c.replace('grapefruitMedia.ingress.vhosts', f'grapefruitMedia.persist.extraPaths = [ stateDir ];\n\n  grapefruitMedia.ingress.vhosts')

# 2. Add InaccessiblePaths and Memory Policy
if 'InaccessiblePaths =' not in c:
    c = c.replace('ReadWritePaths = [', '''MemoryHigh = "2G";
          MemoryMax = "4G";
          InaccessiblePaths = [ "/run/systemd/resolve" "/run/dbus/system_bus_socket" ];
          ReadWritePaths = [''')

with open(PATH, 'w', encoding='utf-8') as f:
    f.write(c)

