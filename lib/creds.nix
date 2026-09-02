# ---
# id: "creds"
# title: "systemd-creds path contract"
# domain: 50
# last_reviewed: 2026-09-02
# ---
# LoadCredentialEncrypted only accepts a systemd-creds blob.
# Eval cannot open the host file, so we require a sealed *name*:
#   *.encrypted  *.cred  …/credstore.encrypted/…  …/medinix/secrets/*.encrypted
# Plain /var/lib/media-secrets/foo is rejected.
# No sops-nix, no agenix.
{ lib }:

rec {
  storeDir = "/var/lib/medinix/secrets";

  isSealedPath = path:
    let p = toString path;
    in
      p != ""
      && (
        lib.hasSuffix ".encrypted" p
        || lib.hasSuffix ".cred" p
        || lib.hasInfix "/credstore.encrypted/" p
        || lib.hasInfix "/etc/credstore.encrypted/" p
      );

  check = name: path: {
    assertion = path == null || path == "" || isSealedPath path;
    message = ''
      [mediNix] ${name} is not a systemd-creds blob:
        ${toString path}
      Seal it:
        echo -n SECRET | sudo systemd-creds encrypt --name=${name} - ${storeDir}/${name}.encrypted
      or: 57-maintenance/medinix-seal-secret.sh ${name}
      Then point the option at that .encrypted / .cred path.
      LoadCredentialEncrypted will not accept a plaintext file.
    '';
  };
}
