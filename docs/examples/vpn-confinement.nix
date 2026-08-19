# docs/examples/vpn-confinement.nix — mediNix-core with VPN + Usenet Sandbox
#
# Use case: Internet-facing media server. SABnzbd + Prowlarr are sandboxed
# under WireGuard — their traffic never leaves the VPN tunnel (UID kill-switch).
# Jellyfin/Sonarr/Radarr are unaffected by the VPN.
#
# Host provides:
#   - Disk mounts
#   - WireGuard private key (TPM-sealed .cred)
#   - Cloudflare token (TPM-sealed .cred) for ACME + DDNS
#   - SABnzbd Usenet-provider credentials (TPM-sealed .cred)
#
{ inputs, ... }:
{
  imports = [
    inputs.mediNix-core.nixosModules.default
  ];

  # ── Physical disk mounts ───────────────────────────────────────────────
  fileSystems."/mnt/ssd" = {
    device = "/dev/disk/by-label/SSD";
    fsType = "ext4";
  };
  fileSystems."/mnt/hdd" = {
    device = "/dev/disk/by-label/HDD";
    fsType = "ext4";
  };

  # ── mediNix-core ────────────────────────────────────────────────────────
  grapefruitMedia = {
    enable = true;
    domain = "m7c5.de";

    storage = {
      mediaRoot   = "/mnt/ssd/media";
      metadataDir = "/mnt/ssd/cache";
      backends = {
        hot  = "/mnt/ssd";
        cold = "/mnt/hdd";
      };
    };

    # Services
    jellyfin.enable   = true;
    sonarr.enable     = true;
    radarr.enable     = true;
    sabnzbd = {
      enable = true;
      # TPM-sealed credential: systemd-creds encrypt --with-key=tpm2+host usenet.env out.cred
      serverCredentialFile = "/var/lib/credstore.encrypted/sabnzbd-server.cred";
    };
    prowlarr.enable   = true;

    # VPN — flake-managed WireGuard interface (526-vpn-interface.nix)
    vpn = {
      enable         = true;
      interface      = "vpn0";
      address        = [ "10.64.0.2/32" ];
      dns            = [ "10.64.0.1" ];   # VPN-internal resolver (no leak)

      peer = {
        publicKey  = "PEER_PUBLIC_KEY_HERE";
        endpoint   = "vpn.provider.com:51820";
        allowedIPs = [ "0.0.0.0/0" "::/0" ];
      };

      # TPM-sealed WireGuard private key
      # systemd-creds encrypt --with-key=tpm2+host wg-private.key wg-key.cred
      privateKeyCredentialPath = "/var/lib/credstore.encrypted/wg-key.cred";
    };

    # Usenet sandbox — SABnzbd + Prowlarr under UID kill-switch
    usenet-confinement.enable = true;

    # TLS — ACME wildcard via Cloudflare DNS-01 (no port 80/443 WAN needed)
    ingress.tls = {
      mode     = "acme";
      acmeHost = "m7c5.de";
      # TPM-sealed Cloudflare token (CF_DNS_API_TOKEN=<token>)
      acmeCredential = "/var/lib/credstore.encrypted/cf-acme.cred";
    };

    # DDNS — keep dynamic IP in sync with Cloudflare
    dns.ddns = {
      enable                   = true;
      cloudflareTokenCredential = "/var/lib/credstore.encrypted/cf-acme.cred";  # reuse
    };
  };
}
