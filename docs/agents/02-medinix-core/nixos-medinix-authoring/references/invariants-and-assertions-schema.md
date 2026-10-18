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

PITFALL: Eine Assertion mit `assertion = true` ist ein No-Op (feuert nie). Echte
Invariante prüft Messbares - heute direkt am Ort, z.B. so (Muster aus
`59-guardrails/591-cross-domain.nix`):
```nix
{
  assertion =
    let r = import ../lib/registry.nix { inherit lib; };
    in lib.all (svc: svc.port == null || svc.port == svc.num * 10) (lib.attrValues r.services);
  message = ''
    [mediNix/591] Ein Registry-Port verletzt Port = Num * 10.
    Was: <betroffener Dienst>
    Warum: Der Dezimalrahmen ist die eine Ableitungsquelle (ADR-0000).
    Wie: Dienstnummer im Registry-Eintrag korrigieren.
  '';
}
```

## Wo Assertions heute leben (Stand 2026-10-17)

**Kein zentrales Register.** Das frühere 59X-Schema (`590-registry.nix` mit
`invariants`/`errors` + `mkInvariant`/`mkError`; `591-ingress`, `592-security`,
`594-transfer`, `597-maintenance`, `599-cross-domain`) wurde mit `533126e`
("Comprehensive architecture and audit fixes") **verworfen**. `mkInvariant` kommt im
Repo nicht mehr vor, und ADR-0003 §3 verbietet ein solches Register ausdrücklich.

Geltende Praxis:
- **Cross-Domain-Garantien** → `59-guardrails/591-cross-domain.nix` (der einzige Ort mit
  mehreren Domänen im Blick: Dezimalrahmen, Ports, Wildcard-Binds, Store-Pfade).
- **Alles andere** → `assertions` **inline** in dem Modul, dessen Option geprüft wird.
- Gating: `lib.mkIf cfg.enable` bzw. `cfg.<dienst>.enable` — `cfg.security.enable` als
  Gate für fremde Assertions ist ein Fehler.
- Message-Format (ADR-5043): Was/Warum/Wie + Modul-Locator, z. B. `[mediNix/517] …`.
  `INV-01 … INV-SECRET` bleiben **Namen in Prosa**, keine Codes zum Nachschlagen.
- Regressionen: `checks.mediNix-negative-*` in `flake.nix` (per `expectAssertion`).

## Workflow: "Zeige Dateien vor dem Commit" (User-Präferenz)
Bei größeren Modul-Neuschöpfungen/Refactors: Inhalt im Chat zeigen, Commit/Push
erst NACH expliziter Freigabe ("Kein Commit ohne Sichtprüfung"). Bei reinen
Bugfixes/kleinen Patches reicht "gepusht (hash)".
