import os
import re

SEC_DIR = "52-security"
ACQ_DIR = "53-acquisition"
TRA_DIR = "54-transfer"
PLA_DIR = "55-playback"

# 1. Delete 521, 522, 524, 525-usenet-confinement
for f in ["521-nftables.nix", "522-kernel.nix", "524-systemd-credentials.nix", "525-usenet-confinement.nix"]:
    p = os.path.join(SEC_DIR, f)
    if os.path.exists(p):
        os.remove(p)

# 2. Rename 523 -> 520
try:
    os.rename(os.path.join(SEC_DIR, "523-emergency-user.nix"), os.path.join(SEC_DIR, "520-core-security.nix"))
except Exception:
    pass

# 3. Strip VPN instances from 525-vpn-interface.nix
vpn_if_path = os.path.join(SEC_DIR, "525-vpn-interface.nix")
clean_vpn = '''# ---
# id: "525-vpn-interface"
# title: "Flake-managed WireGuard Interface"
# domain: 52
# folder: 52-security
# status: active
# complexity: 4
# last_reviewed: 2026-08-18
# links:
#   adr: ADR-5270
# ---
{ config, pkgs, lib, ... }:

let
  cfg       = config.grapefruitMedia;
  vpn       = cfg.vpn;
  ifName    = vpn.interfaceName;
  credMount = "/run/credentials/wireguard-${ifName}.service/wg-private-key";
in
lib.mkIf (cfg.enable && vpn.enable && !vpn.useExistingInterface) {
  grapefruitMedia.vpn.interface  = lib.mkDefault ifName;
  grapefruitMedia.vpn.dnsServers = lib.mkDefault vpn.dns;

  networking.wireguard.interfaces.${ifName} = {
    ips            = vpn.address;
    privateKeyFile = credMount;

    peers = lib.optional (vpn.peer.publicKey != "") {
      publicKey           = vpn.peer.publicKey;
      endpoint            = vpn.peer.endpoint;
      allowedIPs          = vpn.peer.allowedIPs;
      persistentKeepalive = vpn.peer.persistentKeepalive;
    };
  };

  systemd.services."wireguard-${ifName}" =
    lib.mkIf (vpn.privateKeyCredentialPath != null) {
      serviceConfig.LoadCredentialEncrypted = [
        "wg-private-key:${vpn.privateKeyCredentialPath}"
      ];
    };
}
'''
with open(vpn_if_path, 'w', encoding='utf-8') as f:
    f.write(clean_vpn)


# 4. Inject LoadCredentialEncrypted and VPN Killswitch into domain modules
secrets_map = {
    "53-acquisition/532-sonarr.nix": "sonarrApiKeyFile",
    "53-acquisition/533-radarr.nix": "radarrApiKeyFile",
    "53-acquisition/536-prowlarr.nix": "prowlarrApiKeyFile",
    "53-acquisition/535-lidarr.nix": "lidarrApiKeyFile",
    "53-acquisition/534-readarr.nix": "readarrApiKeyFile",
    "54-transfer/541-sabnzbd.nix": "sabnzbdApiKeyFile",
    "55-playback/551-jellyfin.nix": "jellyfinAdminPasswordFile",
    "55-playback/555-jellyseerr.nix": "jellyseerrApiKeyFile"
}

for path, secret_key in secrets_map.items():
    name = path.split('-')[-1].replace('.nix', '')
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()
    
    inject_cred = f'''
  systemd.services."{name}" = lib.mkIf (cfg.secrets.{secret_key} != null) {{
    serviceConfig.LoadCredentialEncrypted = [ "{name}-api-key:${{cfg.secrets.{secret_key}}}" ];
  }};
'''
    if name == "sabnzbd":
        inject_cred += '''
  services.vpnKillSwitch.instances.sabnzbd = lib.mkIf cfg.usenet-confinement.enable {
    enable = true;
    vpnInterface = cfg.vpn.interface;
    routingTable = 51820;
    routingPriority = 100;
    blockedSocketPaths = [ "/run/medinix" "/run/systemd/resolve" "/run/dbus/system_bus_socket" ];
    dnsServers = cfg.vpn.dnsServers;
  };
'''
    elif name == "prowlarr":
        inject_cred += '''
  services.vpnKillSwitch.instances.prowlarr = lib.mkIf cfg.usenet-confinement.enable {
    enable = true;
    vpnInterface = cfg.vpn.interface;
    routingTable = 51820;
    routingPriority = 101;
    blockedSocketPaths = [ "/run/medinix" "/run/systemd/resolve" "/run/dbus/system_bus_socket" ];
    dnsServers = cfg.vpn.dnsServers;
  };
'''

    c = c.rstrip()
    if c.endswith('}'):
        c = c[:-1] + inject_cred + "\n}\n"
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(c)

