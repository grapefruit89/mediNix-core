---
title: Secrets Management
type: Concept
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

- **LoadCredential** — REAL: Bevorzugter Transport für Secrets ist systemds
  `LoadCredential`. In den Modulen etabliert.
- **Stufe TPM** — DESIGN / INTENT: Hardware-gestützte Sicherheit via TPM2 wird
  *angestrebt, wo möglich*. Das ist (noch) keine garantierte Eigenschaft jedes
  Pfades — „TPM2 wird verwendet" wäre eine stärkere Aussage als „die Architektur
  kann es später nutzen".
- **Kein sops-Zwang** — ENTSCHEIDUNG: Modulen wird kein `sops-nix` aufgezwungen,
  wenn einfache systemd-Credentials ausreichen; SOPS ist oft Overkill für
  einfache Passwörter aus der Host-Provisionierung. Achtung: `LoadCredential`
  ist ein *Transport*, kein vollständiges Secrets-Management-System.

## Concept → Contract → Invariant → Implementation → Test

- **Concept** — Architekturentscheidung / gewünschtes Verhalten (diese Seite).
- **Contract** — präzise, überprüfbare Schnittstelle.
- **Invariant** — muss immer gelten (siehe Assertions/Tests).
- **Implementation** — Nix / systemd / Caddy / usw.
- **Test** — beweist einen *Teil* davon.

Eine Markdown-Datei ist nicht dadurch SSoT, dass sie sich so nennt.
