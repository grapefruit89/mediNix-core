# ---
# id: "595-storage-guardrails"
# title: "Storage Tiering Guardrails (59-guardrails)"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-18
# links:
#   adr: ADR-5710
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
  reg = import ./590-registry.nix { inherit lib; };
  st  = cfg.storage;

  hasCold = st.backends ? cold;
  hasHot  = st.backends ? hot;
in
lib.mkIf cfg.enable {
  assertions = [
    # STG-001: cold ohne hot ergibt kein sinnvolles Tiering
    (reg.mkError "STG-001" (!(hasCold && !hasHot)))

    # INV-STG-01: Kein Backend-Pfad im Nix-Store
    (reg.mkInvariant "INV-STG-01"
      (lib.all (p: !(lib.hasPrefix "/nix/store/" p))
        (lib.attrValues st.backends)))

    # INV-STG-02: mediaRoot nicht im Nix-Store
    (reg.mkInvariant "INV-STG-02"
      (!(lib.hasPrefix "/nix/store/" (toString st.mediaRoot))))
  ];
}
