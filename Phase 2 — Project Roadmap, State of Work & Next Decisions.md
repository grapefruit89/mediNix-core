# ARCHITECT DIRECTIVE — Establish the Project Roadmap

## Rolle

Du arbeitest an `mediNix-workbench` als ausführender OpenCode-Agent.

Der Project Owner möchte, dass die Architektur jetzt nicht mehr nur implizit in Chatverläufen existiert.

Wir brauchen eine **persistente Roadmap im Repository**, die jederzeit beantwortet:

1. Was wurde bereits erledigt?
2. Was wurde bewusst entschieden?
3. Was ist noch offen?
4. Was ist blockiert?
5. Was kommt als Nächstes?
6. Welche Entscheidungen sind bereits endgültig und dürfen nicht wieder aufgerollt werden?
7. Welche Punkte sind nur recherchiert, aber noch nicht umgesetzt?
8. Welche Verifikation fehlt noch?

Die Roadmap soll dadurch zum **Arbeitsgedächtnis des Projekts** werden.

---

# 1. Erstelle eine zentrale Roadmap

Lege eine geeignete Datei unter `docs/` an.

Bevorzugt:

```text
docs/ROADMAP.md
```

Falls bereits eine passende Roadmap-Datei existiert, diese verwenden statt eine zweite Roadmap zu erzeugen.

Die Roadmap ist **kein Tagebuch**.

Sie ist ein aktueller Projektzustand.

Keine langen Chat-Nacherzählungen.

---

# 2. Verwende einen eindeutigen Status

Jeder Arbeitspunkt bekommt genau einen Status:

```text
DONE
IN_PROGRESS
NEXT
OPEN
BLOCKED
DEFERRED
DECISION
```

Bedeutung:

### DONE

Technisch umgesetzt und soweit möglich verifiziert.

### IN_PROGRESS

Aktuell laufende Arbeit.

### NEXT

Der nächste geplante Arbeitsschritt.

### OPEN

Noch nicht entschieden oder umgesetzt.

### BLOCKED

Bearbeitung ist wegen einer konkreten externen Voraussetzung nicht möglich.

Beispiel:

```text
nix flake check
→ BLOCKED
→ nix binary unavailable on current host
```

Nicht als PASS darstellen.

### DEFERRED

Bewusst zurückgestellt.

### DECISION

Menschliche/architektonische Entscheidung erforderlich.

---

# 3. Aktuellen Projektstand eintragen

Die Roadmap muss mindestens folgenden Stand korrekt abbilden.

## Phase 0 — OpenCode Foundation

```text
DONE
```

Erledigt:

- OpenCode workbench branch
- `opencode.jsonc`
- permission model
- skill discovery
- formatter configuration
- reference configuration
- root `AGENTS.md`
- OpenCode smoke test
- reference repo als read-only Kontext definiert
```

---

## Phase 1 — Metadata / Tooling Foundation

### 1a — Custom Tools

```text
DONE
```

Vorhanden:

```text
medinix-meta-check
medinix-meta-docs
```

Destruktive/weitreichende Funktionen wie `repair`, `sync-deps`, `build-brain`, `mcp` wurden bewusst nicht als freie Agent-Tools exponiert.

### 1b — NIXMETA cleanup

```text
DONE
```

Erledigt:

- fehlende `provides` ergänzt
- Self-require entfernt
- Filename/ID mismatch korrigiert
- headerlose Dateien behandelt
- NIXMETA-Struktur bereinigt
- keine Nix-Semantik unnötig verändert

---

# Phase 2 — Agent Architecture

## 2a — medinix-discipline

```text
DONE
```

Kern:

```text
Think
Simplify
Surgical
Goal-driven
Root-cause
Verify
```

Zusätzlich:

```text
REAL
PHANTOM
UNRESOLVED
```

Cross-validation.

---

## 2b — medinix-nix

```text
DONE
```

Kern:

```text
cheapest authoritative source first
```

mit Eskalation zu:

```text
local source
→ NixOS/nixpkgs
→ nix eval / nix repl
→ official documentation
```

Nicht als starre Checkliste missverstehen.

---

## 2c — Objective Checks

```text
DONE — WIRING
BLOCKED/UNVERIFIED — ACTUAL NIX EVALUATION
```

Vorhanden:

```text
checks.medinix-meta
checks.medinix-docs
```

`nix flake check` konnte auf dem aktuellen Host mangels `nix` nicht ausgeführt werden.

Diesen Status niemals als PASS darstellen.

---

# 4. Research Architecture

## 2d — Upstream Research Registry

```text
DONE
```

`docs/repository.yaml` ist die Research-Landkarte.

Sie unterscheidet:

```text
official NixOS
module upstream
service upstream
client upstream
SDK
reference-config
documentation
infrastructure candidates
```

Grundregel:

```text
extract patterns, not files
```

---

## 2e — Software Triangulation

```text
DONE
```

15/15 Programme untersucht.

Grundmodell:

```text
mediNix
+
NixOS/nixpkgs package
+
NixOS/nixpkgs module
+
NixOS test
+
upstream application
+
upstream documentation
+
optional Context7
```

Nicht jedes Programm besitzt jeden dieser Bausteine.

---

# 5. Architecture Decisions from Triangulation

## Prowlarr 536

```text
DONE
```

Entscheidung:

```text
mediNix Factory bleibt maßgeblich.
```

Die Nixpkgs-`DynamicUser`-Implementierung ist eine Referenz, aber kein Grund, die mediNix-Factory daran anzugleichen.

GID 5000 ist hier als mediNix-Factory-Invariante zu verstehen, nicht als Prowlarr-spezifische technische Notwendigkeit.

---

## Readarr 534

```text
DONE — RETIRED
```

Wichtig:

```text
RETIRE ≠ DELETE
```

Beibehalten:

- Datei
- Registry-Eintrag
- Decimal Slot 534
- bestehende Daten
- historische Identität

Nicht mehr aktiv als zukünftiger Dienst behandeln.

Keine automatische Migration auf einen Fork.

Eine spätere Migration wäre eine neue Architekturentscheidung.

---

# 6. Determinate Infrastructure

## Phase 2e++

```text
DONE — RESEARCH ONLY
```

In `docs/repository.yaml` dokumentiert:

```text
update-flake-lock
magic-nix-cache
flake-checker
flake-schemas
```

Status:

```text
candidate
candidate
candidate
deferred
```

Wichtig:

Diese Projekte sind **noch nicht installiert und noch nicht Bestandteil der Architektur**.

Insbesondere:

```text
flake-checker ≠ Ersatz für mediNix verification
```

und:

```text
magic-nix-cache ≠ Skill
```

und:

```text
update-flake-lock ≠ Architekturentscheidung
```

---

# 7. Frontmatter Standardization

## CURRENT NEXT TASK

Status:

```text
NEXT
```

Vor `medinix-debug` wird das Frontmatter der Ziel-Skills standardisiert.

Grund:

Die sechs Zielskills sollen einen gemeinsamen **Agent Context Contract** besitzen.

Frontmatter ist dabei ein maschinenlesbares Formular.

Es soll mindestens enthalten:

```text
identity
status
layer
domain
purpose
when_to_use
when_not_to_use
inputs
outputs
authority
research
related
invariants
verification
change_policy
output_contract
```

Research muss standardisiert sein:

```yaml
research:
  upstream:
    repo:
    docs:
    api:
  nixpkgs:
    package:
    module:
    tests:
  reference:
    repos: []
  context7:
    enabled:
    library_id:
```

Leere Felder werden als `null` dargestellt.

Nicht einfach weglassen.

Ziel:

```text
Skill = behavior
Frontmatter = context
repository.yaml = research map
AGENTS.md = project contract
Flake = objective truth
```

---

# 8. Phase 2g — medinix-debug

```text
NEXT
```

Geplanter Inhalt:

- `mkMerge` isolation trap
- isolation-as-LIST
- `IPAddressDeny`
- `RestrictNetworkInterfaces`
- legitimate JIT exceptions
- `MemoryDenyWriteExecute`
- `PrivateDevices`
- Jellyfin/VA-API exceptions
- recursive config rereading trap
- anti-lockout order
- dry-run-first
- root-cause debugging

Keine Hostnamen/IPs/q958-spezifischen Regeln übernehmen.

---

# 9. Phase 2h — medinix-verify

```text
OPEN
```

Ziel:

```text
formatter
→ NIXMETA
→ docs
→ static checks
→ Nix evaluation
→ invariants
→ git diff
```

Ergebnis:

```text
PASS
FAIL
BLOCKED
UNVERIFIED
```

Keine subjektive "looks good"-Verifikation.

---

# 10. Phase 2i — Legacy Skill Migration

```text
OPEN
```

Erst starten, wenn die sechs Zielskills vollständig und getestet sind.

Aktuell existieren ungefähr 26 Legacy Skills.

Nicht einzeln blind migrieren.

Stattdessen:

```text
26 legacy skills
        ↓
Gold extraction
        ↓
6 target skills
        ↓
cross-validation
        ↓
legacy retirement
```

Bekannte Gold-Regeln müssen erhalten bleiben, insbesondere:

- Cross-validation REAL/PHANTOM/UNRESOLVED
- Portability
- Credentials
- Decimal System
- NIXMETA
- Hardening
- Factory
- feature-creep control
- surgical changes
- verification

Legacy-Skills erst löschen, wenn deren relevante Inhalte nachweislich übernommen wurden.

---

# 11. Phase 3 — Verification / Invariant Guard

```text
OPEN
```

Ziel:

Eine Änderung soll langfristig durch eine objektive Kette laufen:

```text
Agent writes
    ↓
formatter
    ↓
NIXMETA
    ↓
docs
    ↓
static checks
    ↓
Nix evaluation
    ↓
invariant verification
    ↓
git diff
    ↓
PASS / FAIL / BLOCKED
```

Die Invariant-Liste soll möglichst aus der tatsächlichen Konfiguration abgeleitet werden.

Keine zweite, widersprüchliche Handbuch-Wahrheit bauen.

---

# 12. Phase 4 — Final Cleanup

```text
DEFERRED
```

Erst nach erfolgreicher Migration.

Geplante Arbeiten:

- Legacy Skills entfernen
- obsolete Knowledge Skills entfernen
- stale host references entfernen
- alte Kanban-/Hermes-/Unraid-/Second-Brain-Sonderpfade entfernen
- widersprüchliche Policies entfernen
- doppelte Regeln eliminieren
- README/INDEX aktualisieren
- vollständiger Cross-Audit
- vollständiger Smoke-Test

---

# 13. Permanenter Decision Log

Die Roadmap soll außerdem eine kurze Tabelle enthalten:

| Decision | Status | Result |
|---|---|---|
| Prowlarr Factory | DONE | Factory bleibt maßgeblich |
| Readarr 534 | DONE | RETIRED, Slot reserviert |
| Context7 | DECIDED | optional reference, nicht authority |
| Research Registry | DONE | routing/index, keine Knowledge Base |
| Determinate tools | DEFERRED/CANDIDATE | noch keine Adoption |
| Frontmatter | NEXT | standardisiertes Formular |
| Legacy migration | OPEN | erst nach 6 Zielskills |

Keine bereits getroffene Entscheidung erneut als offene Frage darstellen.

---

# 14. Neue externe Projekte

Die folgenden vier Links wurden als **Research Inputs** geliefert.

Sie dürfen NICHT automatisch installiert oder in `56-agents` übernommen werden.

Sie müssen klassifiziert werden.

## A — milahu/nixos-config-webui

Das Projekt ist ein browserbasierter Editor für Nix/NixOS-Konfigurationen; GitHub beschreibt es als Web-Editor für Nix-Dateien/NixOS-Konfiguration. Das Repository ist allerdings alt; GitHub zeigt die letzte Aktivität im September 2022.

Behandlung:

```text
REFERENCE ONLY
```

Kein aktueller Architekturbaustein.

Interessant höchstens für:

- WebUI-Ideen
- Nix-Editor UX
- mögliche zukünftige Config-Inspection

Nicht für:

- mediNix Skill
- Verification Authority
- aktuelle NixOS-Architektur

---

## B — vimjoyer/lezer-parser-nix

Das ist technisch interessanter.

Es handelt sich um einen **Lezer Parser / Grammar für die Nix-Sprache**. Das Projekt wird auch von `milahu/nix-eval-js` als Parser-Basis verwendet.

Das ist **kein NixOS-Skill**.

Es könnte langfristig relevant werden für:

```text
Nix parsing
AST
syntax-aware tooling
editor integration
static analysis
custom tooling
```

Aber aktuell:

```text
REFERENCE / FUTURE TOOLING
```

Nicht als Skill übernehmen.

Besonders interessant wäre es erst dann, wenn mediNix irgendwann einen eigenen syntax-aware Analyzer statt grep-basierter Prüfungen benötigt.

Das ist aktuell nicht bewiesen.

---

## C — michalzubkowicz/nixos-management-skill

Das ist der **relevanteste externe Skill** der vier.

Er ist ein umfangreicher NixOS-Management-Skill mit getrennten Dokumenten für:

- Configuration
- VM Management
- Installation
- Image Building
- Impermanence
- LUKS
- Monitoring
- Anti-patterns

und basiert laut Projekt auf NixOS Manual, nix.dev, NixOS Wiki und weiteren Quellen.

Aber:

**NICHT INSTALLIEREN.**

Wir haben bereits entschieden, dass mediNix eine eigene kleine Skill-Landschaft bekommt.

Das Projekt sollte als **Benchmark / Gold-Mining-Quelle** untersucht werden:

```text
Was macht dieser Skill besser?
Welche Regeln fehlen uns?
Welche Inhalte haben wir bereits?
Welche Regeln widersprechen mediNix?
Welche Struktur ist interessant?
```

Danach:

```text
extract pattern
→ mediNix-native formulation
→ ggf. übernehmen
```

Nicht:

```text
copy skill
```

Das Projekt selbst warnt ausdrücklich davor, Skills ungeprüft zu installieren, weil Skills Agentenverhalten und ausgeführte Befehle beeinflussen können.

---

## D — curriedsoftware/nixomatic-skill

Das ist ein völlig anderer Typ.

`nixomatic-skill` beschreibt einen Agent-Skill, der fehlende Software kurzfristig über Nix/nixpkgs bereitstellt und dafür `nix develop` bzw. nixomatic verwendet, ohne das aktuelle System dauerhaft zu verändern.

Interessant für:

```text
ephemeral tooling
development environments
"tool is missing"
```

Aber aktuell **kein Kernbestandteil von mediNix**.

Grund:

mediNix braucht zunächst seine eigene Verifikations- und Architekturdisziplin.

Behandlung:

```text
REFERENCE / CANDIDATE
```

Nicht installieren.

---

## E — mcpmarket NixOS Module Patterns

Das ist eher ein **Pattern-/Skill-Katalog-Eintrag** als eine Primärquelle.

Die Beschreibung verspricht standardisierte NixOS/Home-Manager-Strukturen, Modul-Boilerplate, Package Patterns und machine-specific configuration.

Für mediNix ist das deshalb nur:

```text
LOW-VALUE REFERENCE
```

Wir haben bereits:

```text
Decimal System
NIXMETA
Factory
Hardening Profiles
Portability
Software Triangulation
```

Ein generischer NixOS-Module-Pattern-Skill darf diese lokale Architektur nicht überschreiben.

**Nicht installieren.**

---

# 15. Klassifikation der vier Quellen

Am Ende der Roadmap-Recherche festhalten:

```text
milahu/nixos-config-webui
    → REFERENCE / LEGACY / LOW PRIORITY

vimjoyer/lezer-parser-nix
    → TECHNICAL REFERENCE / FUTURE TOOLING

michalzubkowicz/nixos-management-skill
    → HIGH-VALUE RESEARCH / GOLD-MINING

curriedsoftware/nixomatic-skill
    → OPTIONAL TOOLING REFERENCE

mcpmarket/nixos-module-patterns
    → LOW-VALUE GENERIC REFERENCE
```

**Keine Installation. Keine direkte Übernahme.**

---

# 16. Abschluss der Roadmap-Aufgabe

Nach Erstellung/Aktualisierung der Roadmap:

```text
git diff --check
```

Dann die Roadmap selbst gegen den tatsächlichen Repository-Zustand prüfen.

Insbesondere darf die Roadmap nicht behaupten:

```text
Nix verification = DONE
```

solange `nix flake check` nicht tatsächlich ausgeführt wurde.

Danach OpenCode-Smoketest:

> "What is done, what is next, what is blocked, and which decisions are already final?"

Die Antwort muss aus der Repository-Roadmap ableitbar sein.

Erst wenn dieser Test funktioniert:

```text
NEXT → Frontmatter standardization
```

und danach:

```text
medinix-debug
```

beginnen.

---

# Architect Rule

Die Roadmap selbst wird zur **Single Source of Truth für den Projektfortschritt**.

Nicht der Chat.

Nicht das Gedächtnis des Agents.

Nicht eine alte TODO-Liste.

Nicht einzelne Commit-Messages.

Wenn eine Phase abgeschlossen ist, wird sie dort markiert.

Wenn eine Entscheidung gefallen ist, wird sie dort festgehalten.

Wenn etwas blockiert ist, wird der konkrete Grund dort festgehalten.

Wenn später ein neuer Agent die Session übernimmt, muss er durch `AGENTS.md → ROADMAP.md` innerhalb weniger Minuten verstehen können, **wo das Projekt steht und warum**.