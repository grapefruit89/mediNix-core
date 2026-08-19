import re

PATH = "52-security/526-vpn-killswitch.nix"

with open(PATH, 'r', encoding='utf-8') as f:
    c = f.read()

# Add before directive dynamically
c = re.sub(
    r'wantedBy = \[ "multi-user\.target" \];\n      after = \[ "network\.target" \];',
    '''wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      before = map (n: "${n}.service") (lib.attrNames activeInstances);''', 
    c
)

# Fix metric vs priority in routes
c = c.replace('table 51820 priority 100\n', 'table 51820 metric 100\n')
c = c.replace('table 51820 priority 10\n', 'table 51820 metric 10\n')
c = c.replace('table 51820 priority 10 ', 'table 51820 metric 10 ')

with open(PATH, 'w', encoding='utf-8') as f:
    f.write(c)

