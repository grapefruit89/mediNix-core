# ---
# id: "521-creds"
# title: "Sealed-only systemd-creds contract"
# domain: 52
# folder: 52-security
# status: active
# last_reviewed: 2026-09-02
# provides: ["creds"]
# requires: ["lib/creds"]
# adr: ADR-5000
# ---
# Every path that hits LoadCredentialEncrypted must look like a sealed blob.
# Defaults under /var/lib/media-secrets/ without .encrypted/.cred fail eval.
{ config, lib, ... }:

let
  cfg = config.medinix;
  creds = import ../lib/creds.nix { inherit lib; };
  check = creds.check;

  hostCreds = lib.mapAttrsToList (n: p: check "host.credentials.${n}" p) (cfg.host.credentials or {});

  secretChecks = [
    (check "secrets.arrApiKeyFile" cfg.secrets.arrApiKeyFile)
    (check "secrets.sonarrApiKeyFile" cfg.secrets.sonarrApiKeyFile)
    (check "secrets.radarrApiKeyFile" cfg.secrets.radarrApiKeyFile)
    (check "secrets.prowlarrApiKeyFile" cfg.secrets.prowlarrApiKeyFile)
    (check "secrets.lidarrApiKeyFile" cfg.secrets.lidarrApiKeyFile)
    (check "secrets.readarrApiKeyFile" cfg.secrets.readarrApiKeyFile)
    (check "secrets.seerrApiKeyFile" cfg.secrets.seerrApiKeyFile)
    (check "secrets.sabnzbdApiKeyFile" cfg.secrets.sabnzbdApiKeyFile)
    (check "secrets.jellyfinAdminPasswordFile" cfg.secrets.jellyfinAdminPasswordFile)
    (check "secrets.navidromeOidcFile" cfg.secrets.navidromeOidcFile)
    (check "secrets.seerrEnvFile" cfg.secrets.seerrEnvFile)
    (check "jellyfin.adminPasswordFile" (cfg.jellyfin.adminPasswordFile or null))
    (check "jellyfin.adminPasswordCredential" (cfg.jellyfin.adminPasswordCredential or null))
    (check "sabnzbd.serverCredentialFile" (cfg.sabnzbd.serverCredentialFile or null))
    (check "dns.ddns.cloudflareTokenCredential" (cfg.dns.ddns.cloudflareTokenCredential or null))
    (check "dns.ddns.tokenCredential" (cfg.dns.ddns.tokenCredential or null))
    (check "dns.ddns.tokenFile" (cfg.dns.ddns.tokenFile or null))
    (check "ingress.tls.acmeCredential" (cfg.ingress.tls.acmeCredential or null))
    (check "vpn.privateKeyCredentialPath" (cfg.vpn.privateKeyCredentialPath or null))
    (check "maintenance.backup.passwordCredentialPath" (cfg.maintenance.backup.passwordCredentialPath or null))
    (check "maintenance.backup.offsite.passwordCredentialPath" (cfg.maintenance.backup.offsite.passwordCredentialPath or null))
    (check "observability.crowdsec.enrollKeyFile" (cfg.observability.crowdsec.enrollKeyFile or null))
  ];
in
lib.mkIf cfg.enable {
  assertions = secretChecks ++ hostCreds ++ [
    {
      assertion = !(cfg.secrets.autoGenerate or false);
      message = ''
        [mediNix] secrets.autoGenerate writes plaintext keys. Off.
        Seal with 57-maintenance/medinix-seal-secret.sh and set the option to the .encrypted path.
      '';
    }
    {
      assertion =
        !cfg.maintenance.backup.enable
        || (cfg.maintenance.backup.passwordCredentialPath != null
            && creds.isSealedPath cfg.maintenance.backup.passwordCredentialPath);
      message = ''
        [mediNix] backup.enable needs maintenance.backup.passwordCredentialPath
        pointing at a .encrypted/.cred blob. passwordFile is leftover plaintext.
      '';
    }
  ];
}
