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
{ config, lib, ... }:

let
  cfg = config.medinix;
  creds = import ../lib/creds.nix { inherit lib; };
  check = creds.check;
  sealed = name: "${creds.storeDir}/${name}.encrypted";

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
  # Win over option defaults under /var/lib/media-secrets/ (plaintext leftovers).
  medinix.secrets = {
    secretsDir = lib.mkDefault creds.storeDir;
    arrApiKeyFile = lib.mkDefault (sealed "arr-apikey");
    sonarrApiKeyFile = lib.mkDefault (sealed "sonarr-apikey");
    radarrApiKeyFile = lib.mkDefault (sealed "radarr-apikey");
    prowlarrApiKeyFile = lib.mkDefault (sealed "prowlarr-apikey");
    lidarrApiKeyFile = lib.mkDefault (sealed "lidarr-apikey");
    readarrApiKeyFile = lib.mkDefault (sealed "readarr-apikey");
    seerrApiKeyFile = lib.mkDefault (sealed "seerr-apikey");
    sabnzbdApiKeyFile = lib.mkDefault (sealed "sabnzbd-apikey");
    jellyfinAdminPasswordFile = lib.mkDefault (sealed "jellyfin-admin");
    navidromeOidcFile = lib.mkDefault (sealed "navidrome-oidc");
    seerrEnvFile = lib.mkDefault (sealed "seerr-env");
    autoGenerate = lib.mkDefault false;
  };

  assertions = secretChecks ++ hostCreds ++ [
    {
      assertion = !(cfg.secrets.autoGenerate or false);
      message = ''
        [mediNix] secrets.autoGenerate writes plaintext keys. Off.
        Use 57-maintenance/medinix-seal-secret.sh and LoadCredentialEncrypted.
      '';
    }
    {
      assertion =
        !cfg.maintenance.backup.enable
        || (cfg.maintenance.backup.passwordCredentialPath != null
            && creds.isSealedPath cfg.maintenance.backup.passwordCredentialPath);
      message = ''
        [mediNix] backup.enable needs passwordCredentialPath as a .encrypted/.cred blob.
        passwordFile is plaintext and is not accepted.
      '';
    }
  ];
}
