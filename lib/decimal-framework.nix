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
{ config ? { }, lib, ... }:

let
  mod = a: b: a - (a / b) * b;

  # Universal 10-slot taxonomy mapping
  canonicalDecades = {
    "0" = "foundation";
    "1" = "access";
    "2" = "security";
    "3" = "ingestion";
    "4" = "processing";
    "5" = "core-app";
    "6" = "exposition";
    "7" = "maintenance";
    "8" = "observability";
    "9" = "guardrails";
  };

  # 1. SSOT Derivation Function
  derive =
    name: num:
    let
      projectDigit = num / 100;
      decadeDigit = mod (num / 10) 10;
      leafDigit = mod num 10;
      derivedId = num * 10;
      sharedGid = projectDigit * 1000;
    in
    {
      inherit name num;
      id = num;
      port = derivedId;
      uid = derivedId;
      primaryGid = derivedId; # User Private Group (UPG)
      group = name;
      inherit sharedGid; # H000 (e.g., 5000 for mediNix)
      stateDir = "/var/lib/${name}";
      decadeIndex = decadeDigit;
      decadeName = canonicalDecades.${toString decadeDigit} or "unknown";
      inherit projectDigit leafDigit;
    };

  # 2. Hard Invariants Validation (Design by Contract: I1 - I4)
  validate =
    name: num:
    let
      decadeDigit = mod (num / 10) 10;
      leafDigit = mod num 10;
    in
    [
      {
        assertion = builtins.isInt num && num >= 100 && num <= 999;
        message = "[ADR-0000 I1] What: Service '${name}' has invalid ID '${toString num}'. Expected: 3-digit integer (100 <= num <= 999). Fix: Assign a valid 3-digit service ID.";
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
  manifests = config.decimalFramework.manifest or config.medinix.manifest or { };
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
    if meta ? needsSharedGroup then
      meta.needsSharedGroup
    else if meta ? needsMediaGroup then
      meta.needsMediaGroup
    else
      defaultByDecade;

  allowedCapabilities = [
    "CAP_NET_BIND_SERVICE"
    "CAP_NET_RAW"
  ];

in
{
  # Expose library functions directly if imported as a regular attrset/function
  inherit
    derive
    validate
    canonicalDecades
    allowedCapabilities
    mod
    ;

  # Expose framework library methods for manual calls if needed
  options.decimalFramework = {
    lib = lib.mkOption {
      default = {
        inherit derive validate canonicalDecades allowedCapabilities;
      };
      internal = true;
      readOnly = true;
    };
  };

  config = {
    # 3. Compile-Time Assertions (Uniqueness, Invariants, Role & Capabilities Whitelist)
    assertions =
      lib.concatLists (lib.mapAttrsToList (name: meta: validate name meta.num) daemonServices)
      ++ lib.concatLists (lib.mapAttrsToList (name: meta: [
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
      ]) manifests)
      ++ [
        {
          assertion = lib.length allActiveIds == lib.length (lib.unique allActiveIds);
          message = "[ADR-0000 Collision] What: Duplicate service IDs detected among active services. Expected: Strictly injective 3-digit IDs.";
        }
      ];

    # 4. UPG & Shared Group Definitions
    users.groups =
      {
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
      ) daemonServices;

    users.users = lib.mapAttrs (
      name: meta:
      let
        spec = derive name meta.num;
      in
      {
        inherit (spec) uid;
        group = name; # UPG (GID = UID = num * 10)
        extraGroups = lib.mkIf (requiresMediaGroup meta) [ "media" ];
        home = spec.stateDir;
        isSystemUser = true;
      }
    ) daemonServices;

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
