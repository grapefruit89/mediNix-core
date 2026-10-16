# ---
# id: "501-decimal-engine"
# title: "Decimal Framework Engine & Global Identity Injection (ADR-0000)"
# domain: 50
# folder: 50-core
# status: active
# complexity: 1
# last_reviewed: 2026-10-16
# links:
#   adr: ADR-0000
# adr: ADR-0000
# ---
# Warum diese Datei existiert (gemessen 2026-10-16): `default.nix` importiert
# automatisch NUR `XX-domain/NNN-*.nix` (builtins.readDir + isModuleDir) und aus
# `lib/` explizit allein `service-contract.nix`. Diese Datei ist damit der EINZIGE
# Weg, ueber den lib/decimal-framework.nix in die Modulliste kommt - eine explizite
# Referenz auf 501 gibt es nicht. Loeschen wuerde die Engine aus jedem Build nehmen.
# Der Engine-eigene Header traegt selbst `adr: ADR-0000`.
{ ... }:
{
  imports = [ ../lib/decimal-framework.nix ];
}
