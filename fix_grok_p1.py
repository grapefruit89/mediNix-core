import re

PATH = "52-security/526-vpn-killswitch.nix"
with open(PATH, 'r', encoding='utf-8') as f:
    c = f.read()

# 1. Add routingTable option
c = c.replace('dnsServers = lib.mkOption {', '''routingTable = lib.mkOption {
      type = lib.types.int;
      default = 51820;
      description = "The routing table and fwmark used for policy routing.";
    };
    dnsServers = lib.mkOption {''')

# 2. Replace all hardcoded 51820 with ${toString cfg.routingTable}
c = c.replace('51820', '${toString cfg.routingTable}')

# 3. Change nftables.enable = true to lib.mkDefault true
c = c.replace('networking.nftables.enable = true;', 'networking.nftables.enable = lib.mkDefault true;')

# 4. Remove RestrictNetworkInterfaces
c = re.sub(r'\s*RestrictNetworkInterfaces = \[ "lo" cfg\.vpnInterface \];\n', '\n', c)

with open(PATH, 'w', encoding='utf-8') as f:
    f.write(c)

