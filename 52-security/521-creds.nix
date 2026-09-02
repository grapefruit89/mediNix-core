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
  notMedia = creds.checkNotUnderMedia (cfg.storage.mediaRoot or null);
  sealed = name: "${creds.storeDir}/${name}.encrypted";

  hostCreds = lib.mapAttrsToList (n: p: check "host.credentials.${n}" p) (cfg.host.credentials or {});

  namedSecrets = {
    "secrets.arrApiKeyFile" = cfg.secrets.arrApiKeyFile;
    "secrets.sonarrApiKeyFile" = cfg.secrets.sonarrApiKeyFile;
    "secrets.radarrApiKeyFile" = cfg.secrets.radarrApiKeyFile;
    "secrets.prowlarrApiKeyFile" = cfg.secrets.prowlarrApiKeyFile;
    "secrets.lidarrApiKeyFile" = cfg.secrets.lidarrApiKeyFile;
    "secrets.readarrApiKeyFile" = cfg.secrets.readarrApiKeyFile;
    "secrets.seerrApiKeyFile" = cfg.secrets.seerrApiKeyFile;
    "secrets.sabnzbdApiKeyFile" = cfg.secrets.sabnzbdApiKeyFile;
    "secrets.jellyfinAdminPasswordFile" = cfg.secrets.jellyfinAdminPasswordFile;
    "secrets.navidromeOidcFile" = cfg.secrets.navidromeOidcFile;
    "secrets.seerrEnvFile" = cfg.secrets.seerrEnvFile;
    "jellyfin.adminPasswordFile" = cfg.jellyfin.adminPasswordFile or null;
    "jellyfin.adminPasswordCredential" = cfg.jellyfin.adminPasswordCredential or null;
    "sabnzbd.serverCredentialFile" = cfg.sabnzbd.serverCredentialFile or null;
    "dns.ddns.cloudflareTokenCredential" = cfg.dns.ddns.cloudflareTokenCredential or null;
    "dns.ddns.tokenCredential" = cfg.dns.ddns.tokenCredential or null;
    "ingress.tls.acmeCredential" = cfg.ingress.tls.acmeCredential or null;
    "vpn.privateKeyCredentialPath" = cfg.vpn.privateKeyCredentialPath or null;
    "maintenance.backup.passwordCredentialPath" = cfg.maintenance.backup.passwordCredentialPath or null;
    "maintenance.backup.offsite.passwordCredentialPath" = cfg.maintenance.backup.offsite.passwordCredentialPath or null;
    "maintenance.backup.offsite.rcloneConfigFile" = cfg.maintenance.backup.offsite.rcloneConfigFile or null;
  };

  secretChecks = lib.mapAttrsToList check namedSecrets;
  mediaChecks = lib.mapAttrsToList notMedia namedSecrets;
in
lib.mkIf cfg.enable {
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

  assertions = secretChecks ++ mediaChecks ++ hostCreds ++ [
    (notMedia "secrets.secretsDir" cfg.secrets.secretsDir)
    {
      assertion = !(cfg.secrets.autoGenerate or false);
      message = ''
        [mediNix] secrets.autoGenerate writes plaintext keys. Off.
        Use 57-maintenance/medinix-seal-secret.sh and LoadCredentialEncrypted.
      '';
    }
    {
      assertion = (cfg.dns.ddns.tokenFile or null) == null;
      message = ''
        [mediNix] dns.ddns.tokenFile is rejected.
        Seal the Cloudflare token and set acmeCredential or cloudflareTokenCredential.
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
    {
      assertion =
        !(cfg.maintenance.backup.offsite.enable or false)
        || ((cfg.maintenance.backup.offsite.passwordCredentialPath or null) != null
            && creds.isSealedPath cfg.maintenance.backup.offsite.passwordCredentialPath);
      message = ''
        [mediNix] offsite.enable needs offsite.passwordCredentialPath as a sealed blob.
      '';
    }
    {
      assertion =
        (cfg.maintenance.backup.passwordFile or "") == ""
        && (cfg.maintenance.backup.offsite.passwordFile or "") == "";
      message = ''
        [mediNix] backup passwordFile paths are rejected. Use passwordCredentialPath.
      '';
    }
  ];
}
