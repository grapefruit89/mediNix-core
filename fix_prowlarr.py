import re

PATH = "53-acquisition/536-prowlarr.nix"

with open(PATH, 'r', encoding='utf-8') as f:
    c = f.read()

# Remove the VPN Killswitch block entirely
c = re.sub(r'  services\.vpnKillSwitch = lib\.mkIf cfg\.usenet-confinement\.enable \{.*?\};\n', '', c, flags=re.DOTALL)

# Add a warning comment at the top of the file
warning = """
# WARNING (CRITICAL): PROWLARR MUST NEVER GO THROUGH THE VPN!
# Indexers heavily block, ban, or throw Captchas at known VPN IP addresses.
# Routing Prowlarr through a VPN will break search and indexer sync.
# DO NOT add services.vpnKillSwitch confinement to this file.
"""

if "# WARNING (CRITICAL)" not in c:
    lines = c.split('\n')
    for i, line in enumerate(lines):
        if line.startswith('{ config'):
            lines.insert(i, warning.strip() + "\n")
            break
    c = '\n'.join(lines)

with open(PATH, 'w', encoding='utf-8') as f:
    f.write(c)

