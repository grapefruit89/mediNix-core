# Invarianten vs Assertions + 59X-Schema (mediNix-core)

## Invarianten vs Assertions — HARTE User-Korrektur
User: "Invarianten! Genau das richtige Wort." Der Unterschied ist Architektur-Level:
- **Assertion** = prüft KONFIGURATIONS-Bedingung zum Build-Zeitpunkt, bricht bei
  falsch. Einmalig. (User hat was falsch gesetzt.)
- **Invariante** = Systemgarantie die IMMER gilt, unabhängig von Konfiguration.
  Beschreibt Eigenschaft des Systems, die bei JEDER Änderung erfüllt sein muss.
  Verletzung = Architektur-Bruch, nicht Konfigurationsfehler.

mediNix Invarianten (INV-01..07 + INV-SECRET):
- INV-01 Port = Num × 10 (via registry.services prüfbar)
- INV-02 alle Dienste binden 127.0.0.1 (Runtime-Garantie, statisch `true`)
- INV-03 GID 5000 = media für alle Registry-Services
- INV-04 usenet-confinement → vpn.interface ≠ "" UND vpn.dns ≠ []
- INV-05 kein Secret im Nix-Store (/nix/store/)
- INV-06 stream-Dienste niemals ohne TLS WAN-erreichbar
- INV-07 kein Dienst mit /dev/dri-Bedarf hat PrivateDevices = true
- INV-SECRET kein Secret-Pfad im Nix-Store (cloudflareTokenCredential,
  sabnzbd.serverCredentialFile, jellyfin.adminPasswordCredential)

PITFALL: Invariante mit `assertion = true` ist ein No-Op (feuert nie). Echte
Invariante prüft Messbares, z.B.:
```nix
(reg.mkInvariant "INV-01"
  (let r = import ../lib/registry.nix { inherit lib; };
   in lib.all (svc: svc.port == null || svc.port == svc.num * 10)
        (lib.attrValues r.services)))
```

## 59X-Assertions-Schema (ADR-0000 konform)
`59-guardrails/` Mapping 59X = Assertions für Domain 5X:
- `590-registry.nix` = SSoT: `invariants` + `errors` + Helper
  `mkInvariant`/`mkError`/`mkErrorDoc`. KEINE Config-Blöcke, nur Daten.
- `591-ingress` (TLS/AUTH), `592-security` (SEC), `594-transfer` (VPN),
  `597-maintenance` (DNS), `599-cross-domain` (INV-01..07) importieren 590,
  rufen `reg.mkError`/`reg.mkInvariant` auf. Domains ohne Assertions = leere Stubs.
- Gating: `lib.mkIf cfg.enable { ... }` — NICHT `cfg.security.enable` (Bug A!).
- Hilfsdienste (emergency-user, backup-ssh) in `59-guardrails/ops/`
  (`59A1-`, `59A2-`) außerhalb des 59X-Schemas.
- KEIN `cfg.services.X.enable` — flaches `cfg.X.enable` (Bug B!).
- Message MUSS ADR-Link enthalten (siehe medinix-assertion-quality).

## Workflow: "Zeige Dateien vor dem Commit" (User-Präferenz)
Bei größeren Modul-Neuschöpfungen/Refactors: Inhalt im Chat zeigen, Commit/Push
erst NACH expliziter Freigabe ("Kein Commit ohne Sichtprüfung"). Bei reinen
Bugfixes/kleinen Patches reicht "gepusht (hash)".
