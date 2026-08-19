import os
import re

# 1. 52-security/README.md
sec_readme = "52-security/README.md"
if os.path.exists(sec_readme):
    with open(sec_readme, 'r', encoding='utf-8') as f:
        c = f.read()
    c = re.sub(r'\| \*\*521\*\*.+\n', '', c)
    c = re.sub(r'\| \*\*522\*\*.+\n', '', c)
    c = re.sub(r'\| \*\*524\*\*.+\n', '', c)
    c = c.replace('523-emergency-user', '520-core-security')
    with open(sec_readme, 'w', encoding='utf-8') as f:
        f.write(c)

# 2. README.md & docs/README.md
for rm in ["README.md", "docs/README.md"]:
    if os.path.exists(rm):
        with open(rm, 'r', encoding='utf-8') as f:
            c = f.read()
        c = re.sub(r'\| `52-security` \|.*', '| `52-security` | Core Security, VPN | 520-core-security, 525-vpn-interface, 526-vpn-killswitch |', c)
        with open(rm, 'w', encoding='utf-8') as f:
            f.write(c)

# 3. ADMIN-HANDOFF.md
ah = "ADMIN-HANDOFF.md"
if os.path.exists(ah):
    with open(ah, 'r', encoding='utf-8') as f:
        c = f.read()
    c = c.replace('mediNIX-core liefert `521-nftables.nix` (Ingress-Firewall).', 'mediNIX-core verzichtet auf eigene Firewall-Regeln (Additive Host Integration).')
    with open(ah, 'w', encoding='utf-8') as f:
        f.write(c)

# 4. ADRs
adr1 = "docs/adr/ADR-54-sabnzbd-vpn-confinement.md"
if os.path.exists(adr1):
    with open(adr1, 'r', encoding='utf-8') as f:
        c = f.read()
    c = c.replace('52-security/525-usenet-confinement.nix', '54-transfer/541-sabnzbd.nix')
    with open(adr1, 'w', encoding='utf-8') as f:
        f.write(c)

adr2 = "docs/adr/ADR-5410-usenet-confinement.md"
if os.path.exists(adr2):
    with open(adr2, 'r', encoding='utf-8') as f:
        c = f.read()
    c = c.replace('525-usenet-confinement.nix', 'den jeweiligen Service-Modulen (z.B. 541-sabnzbd.nix)')
    with open(adr2, 'w', encoding='utf-8') as f:
        f.write(c)

