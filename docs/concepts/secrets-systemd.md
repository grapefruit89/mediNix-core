---
title: Secrets Management
type: Concept
last_reviewed: 2026-10-17
---
# Secrets Management

**Concept — Architektur-Absicht, kein Beweis.** Diese Seite beschreibt, *wie*
Secrets zu den Services gelangen. Die verbindliche Wahrheit über Optionen und
Defaults steht im Nix-Code; Runtime-Verhalten beweist nur Runtime-Evidenz.

**Scope dieses Concepts:**

```text
Concept = wie Secrets an Services übergeben werden
NICHT   = wo jedes Secret erzeugt, gespeichert und rotiert wird
```

Letzteres ist eine Composition-Boundary-Frage (Host / Gesamtsystem), keine
mediNix-interne Eigenschaft.

- **LoadCredentialEncrypted (sealed-only)** — REAL: Der Transport ist systemds
  `LoadCredentialEncrypted` — **nicht** das unverschlüsselte `LoadCredential`.
  Der Contract verlangt einen *systemd-creds-Blob* (`*.encrypted` / `*.cred`
  bzw. `credstore.encrypted`), Default-Ablage `/var/lib/medinix/secrets`
  (`lib/creds.nix`, Modul `52-security/521-creds.nix`). Klartext-Pfade werden
  per Assertion abgewiesen: `secrets.autoGenerate` ist fest aus, ein
  `dns.ddns.tokenFile` oder `maintenance.backup.passwordFile` bricht den Build.
  Blobs dürfen nicht unter `storage.mediaRoot` liegen (GID 5000 schreibbar).
- **Versiegeln statt verwalten** — REAL: Secrets werden vorab versiegelt
  (`scripts/medinix-seal-secret.sh`, `systemd-creds encrypt --name=…`); der Code
  liest nur den Pfad. `LoadCredentialEncrypted` ist damit ein *Transport*, kein
  vollständiges Secrets-Management-System (Erzeugung/Rotation bleiben Host-Sache).
- **Host-gelieferte Credentials** — REAL: Der Host liefert Credentials
  deklarativ, das Modul konsumiert sie: `medinix.host.credentials` (Name → Pfad
  auf ein TPM-versiegeltes `.cred`) und `medinix.security.loginKeys` für den
  Root-Login (`L-047`, „Publish, don't apply", ADR-0003 §1). Additiv, kein
  `mkForce`.
- **Stufe TPM** — DESIGN / INTENT: Bevorzugt ist die TPM-Anbindung der
  Versiegelung (`systemd-creds encrypt --with-key=tpm2+host`). Das ist eine
  Host-Fähigkeit, keine mediNix-Garantie — „TPM2 wird verwendet" wäre eine
  stärkere Aussage als „die Architektur sieht es vor".
- **Kein sops** — ENTSCHEIDUNG: Weder `sops-nix` noch `agenix`
  (`lib/creds.nix`: „No sops-nix, no agenix."; ADR-521). systemd-Credentials
  sind der native, TPM-fähige Weg für einen Single-Node-Homelab.

## Concept → Contract → Invariant → Implementation → Test

- **Concept** — Architekturentscheidung / gewünschtes Verhalten (diese Seite).
- **Contract** — präzise, überprüfbare Schnittstelle.
- **Invariant** — muss immer gelten (siehe Assertions/Tests).
- **Implementation** — Nix / systemd / Caddy / usw.
- **Test** — beweist einen *Teil* davon.

Eine Markdown-Datei ist nicht dadurch SSoT, dass sie sich so nennt.
