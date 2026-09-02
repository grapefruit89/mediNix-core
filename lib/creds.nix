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
# Blobs must not live under storage.mediaRoot (shared GID 5000).
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

  underDir = root: path:
    let
      r = toString root;
      p = toString path;
    in
      r != "" && p != "" && (p == r || lib.hasPrefix (r + "/") p);

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

  checkNotUnderMedia = mediaRoot: name: path: {
    assertion = path == null || path == "" || mediaRoot == null || !(underDir mediaRoot path);
    message = ''
      [mediNix] ${name} sits under storage.mediaRoot (${toString mediaRoot}):
        ${toString path}
      GID 5000 can write the library. Secrets stay in ${storeDir}, never in the tree.
    '';
  };
}
