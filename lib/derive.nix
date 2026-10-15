# ---
# id: "derive"
# title: "Decimal-Framework Ableitung (eine Formel fuer Registry UND Engine)"
# domain: 50
# folder: "lib"
# status: active
# complexity: 1
# last_reviewed: 2026-10-16
# links:
#   adr: ADR-0000
# ---
# Einzige Quelle der Dezimalrahmen-Formel (ADR-0000 §4): `lib/registry.nix` UND
# `lib/decimal-framework.nix` importieren sie, statt sie doppelt zu pflegen (DRY/SSOT).
rec {
  # Projektziffer (num / 100). Alle mediNix-Dienste liegen in 5xx (ADR-0000).
  projectDigit = 5;
  # H000 — geteilte Ablage, NUR als supplementary Gruppe (nie Primaergruppe).
  sharedGid = projectDigit * 1000;

  # Universelle 10-Slot-Taxonomie (ADR-0000 §3).
  decadeNames = {
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

  decadeOf = num: (num / 10) - (num / 100) * 10;
  leafOf = num: num - (num / 10) * 10;

  # Ableitung: Port = UID = Primaer-GID = num*10 (UPG, ADR-0000 §4).
  derive = name: num: {
    inherit name num;
    port = num * 10;
    uid = num * 10;
    primaryGid = num * 10;
    stateDir = "/var/lib/${name}"; # ADR-0000 §9: ohne Port-Suffix
    inherit projectDigit sharedGid;
    decadeIndex = decadeOf num;
    decadeName = decadeNames.${toString (decadeOf num)} or "unknown";
  };
}
