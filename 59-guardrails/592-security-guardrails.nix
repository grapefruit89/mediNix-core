# ---
# id: "592-security-guardrails"
# title: "Security & Hardening Guardrails"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-13
# links:
#   adr: ADR-5043
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
  reg = import ./590-registry.nix { inherit lib; };
in
lib.mkIf cfg.enable {
  assertions = [
    # INV-SECRET: Kein Secret-Pfad im Nix-Store
    (reg.mkInvariant "INV-SECRET"
      (let paths = [
        cfg.dns.cloudflareTokenCredential
        cfg.sabnzbd.serverCredentialFile
        cfg.jellyfin.adminPasswordCredential
        cfg.secrets.sonarrApiKeyFile
        cfg.secrets.radarrApiKeyFile
        cfg.secrets.prowlarrApiKeyFile
        cfg.secrets.lidarrApiKeyFile
        cfg.secrets.readarrApiKeyFile
        cfg.secrets.jellyseerrApiKeyFile
        cfg.secrets.sabnzbdApiKeyFile
        cfg.secrets.navidromeOidcFile
        cfg.secrets.jellyseerrEnvFile
      ];
      in lib.all (p: p == null || !(lib.hasPrefix "/nix/store/" p)) paths))

    # INV-TECH-01..03: Verbotene Technologien strukturell unmöglich machen
    (reg.mkInvariant "INV-TECH-01" (!config.virtualisation.docker.enable))
    (reg.mkInvariant "INV-TECH-02" (!config.virtualisation.podman.enable))
    (reg.mkInvariant "INV-TECH-03" (!config.services.cron.enable))
    (reg.mkInvariant "INV-TECH-04" (config.networking.nftables.enable)) # Implicitly enforces no iptables if configured correctly, but we ensure nftables is on
    (reg.mkInvariant "INV-TECH-05" (!(config ? sops))) # sops-nix forbidden

    # INV-FW-01: NFTables Firewall muss aktiv sein (für VPN UID Kill-Switch)
    (reg.mkInvariant "INV-FW-01" (config.networking.nftables.enable))
  ];

}
