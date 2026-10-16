# ---
# id: "decimal-framework"
# title: "Decimal Framework All-in-One Engine, Validation & UPG Injection (ADR-0000)"
# domain: 50
# folder: lib
# status: active
# complexity: 2
# last_reviewed: 2026-10-14
# adr: ADR-0000
# ---
{
  config ? { },
  lib,
  ...
}:

let
  mod = a: b: a - (a / b) * b;

  # Eine Ableitungs-Quelle: lib/derive.nix (DRY/SSOT). Engine und Registry nutzen
  # dieselbe Formel — nicht doppelt pflegen.
  df = import ./derive.nix;
  canonicalDecades = df.decadeNames;
  inherit (df) derive;

  # 2. Hard Invariants Validation (Design by Contract: I1 - I4)
  validate =
    name: num:
    let
      decadeDigit = mod (num / 10) 10;
      leafDigit = mod num 10;
    in
    [
      {
        assertion = builtins.isInt num && num >= df.projectDigit * 100 && num < (df.projectDigit + 1) * 100;
        message = "[ADR-0000 I1] What: Service '${name}' has invalid ID '${toString num}'. Expected: ${
          toString (df.projectDigit * 100)
        } <= num <= ${
          toString (df.projectDigit * 100 + 99)
        } (Projektziffer ${toString df.projectDigit}). Fix: Assign a valid service ID in the project decade.";
      }
      {
        assertion = leafDigit != 0;
        message = "[ADR-0000 I2] What: Service '${name}' uses block ID '${toString num}' (ends in 0). Expected: num % 10 != 0. Fix: Slot HD0 is reserved for foundation/options; move to HD1..HD9.";
      }
      {
        assertion = decadeDigit != 0;
        message = "[ADR-0000 I3] What: Service '${name}' (${toString num}) is placed in foundation decade '_0'. Expected: Decade != 0. Fix: Foundation holds structure/options only, never daemons.";
      }
      {
        assertion = decadeDigit != 9;
        message = "[ADR-0000 I4] What: Service '${name}' (${toString num}) is placed in guardrails decade '_9'. Expected: Decade != 9. Fix: Guardrails hold build-time assertions only, never daemons.";
      }
    ];

  # Manifest abstraction (supports decimalFramework or mediNix manifests)
  manifests = config.medinix.manifest or { };
  # ADR-040/L-046: Exporter-Identitaeten sind eine ABSICHT (585 deklariert sie
  # als medinix.exporters); die Konten leitet ausschliesslich die Engine ab.
  exporterIntent = config.medinix.exporters or { };
  activeServices = lib.filterAttrs (_name: meta: meta.enable or false) manifests;
  daemonServices = lib.filterAttrs (
    _name: meta: (meta.enable or false) && (meta.hasDaemon or true)
  ) manifests;
  allActiveIds = lib.mapAttrsToList (_name: meta: meta.num) activeServices;

  # Helper: Determines if a service needs the shared storage group (5000 media)
  requiresMediaGroup =
    meta:
    let
      decade = mod (meta.num / 10) 10;
      defaultByDecade = builtins.elem decade [
        3
        4
        5
        7
      ];
    in
    if meta.needsSharedGroup != null then
      meta.needsSharedGroup
    else if meta.needsMediaGroup != null then
      meta.needsMediaGroup
    else
      defaultByDecade;

  allowedCapabilities = [
    "CAP_NET_BIND_SERVICE"
    "CAP_NET_RAW"
  ];

in
{
  # Expose framework library methods for manual calls if needed
  options.decimalFramework = {
    lib = lib.mkOption {
      default = {
        inherit
          derive
          validate
          canonicalDecades
          allowedCapabilities
          ;
      };
      internal = true;
      readOnly = true;
    };
  };

  config = {
    # 3. Compile-Time Assertions (Uniqueness, Invariants, Role & Capabilities Whitelist)
    assertions =
      lib.concatLists (lib.mapAttrsToList (name: meta: validate name meta.num) daemonServices)
      ++ lib.concatLists (
        lib.mapAttrsToList (name: meta: [
          {
            assertion = !(meta ? role) || meta.role == null || (builtins.isString meta.role && meta.role != "");
            message = "[ADR-0000 I5] What: Service '${name}' declares an empty role string. Fix: Either omit the role field entirely, or declare a non-empty functional role (e.g. 'media-server').";
          }
          {
            assertion =
              let
                capabilities = meta.capabilities or [ ];
              in
              builtins.isList capabilities
              && lib.all (cap: builtins.isString cap && builtins.elem cap allowedCapabilities) capabilities;
            message = "[ADR-0000 Capabilities] What: Service '${name}' requests an unauthorized, malformed, or dangerous capability. Fix: Declare only capabilities from the permitted whitelist: ${lib.concatStringsSep ", " allowedCapabilities}.";
          }
        ]) manifests
      )
      ++ [
        {
          assertion = lib.length allActiveIds == lib.length (lib.unique allActiveIds);
          message = "[ADR-0000 Collision] What: Duplicate service IDs detected among active services. Expected: Strictly injective 3-digit IDs.";
        }
      ];

    # Konten sind rein deklarativ: kein ad-hoc `useradd` (kein Fremd-Konto im 5xxx-Band).
    # Login ist fuer Dienst-Konten bereits gesperrt: `isSystemUser = true` -> die
    # Default-Shell ist `pkgs.shadow` (nologin), und es gibt kein Passwort.
    users.mutableUsers = lib.mkDefault false;

    # 4. UPG & Shared Group Definitions
    users.groups = {
      media = lib.mkDefault { gid = 5000; };
    }
    // lib.mapAttrs (
      _name: meta:
      let
        spec = derive _name meta.num;
      in
      {
        gid = spec.primaryGid;
      }
    ) daemonServices
    // lib.mapAttrs (_n: e: { gid = e.uid; }) exporterIntent;

    users.users =
      lib.mapAttrs (
        name: meta:
        let
          spec = derive name meta.num;
        in
        {
          inherit (spec) uid;
          group = name; # UPG (GID = UID = num * 10)
          extraGroups = lib.optional (requiresMediaGroup meta) "media" ++ (meta.extraGroups or [ ]);
          home = spec.stateDir;
          isSystemUser = true;
        }
      ) daemonServices
      // lib.mapAttrs (n: e: {
        inherit (e) uid;
        group = n;
        isSystemUser = true;
      }) exporterIntent;

    # 5. Systemd Hardening Defaults (UPG, UMask 0002, clean StateDirectory)
    systemd.services = lib.mapAttrs (
      name: meta:
      let
        spec = derive name meta.num;
      in
      {
        serviceConfig = {
          User = lib.mkOptionDefault name;
          Group = lib.mkOptionDefault name;
          UMask = lib.mkOptionDefault "0002";
          StateDirectory = lib.mkOptionDefault name;
          StateDirectoryMode = lib.mkOptionDefault "0750";
          WorkingDirectory = lib.mkOptionDefault spec.stateDir;
        };
      }
    ) daemonServices;
  };
}
