# mediNix-core Agents

Dieses Verzeichnis enthält die orchestrierten KI-Skills für das mediNix-core Projekt.
Die Skills sind nach einem klaren Dezimalrahmen organisiert (01 bis 07).

## 🗂️ Struktur & Kategorien

- **`01-discipline/`**: Verhaltens- und Prozess-Disziplin (z.B. `medinix-implement-discipline`).
- **`02-medinix-core/`**: Kern-Authoring-Regeln (Dezimalrahmen, Conventions, `medinix-module-author`).
- **`03-gates-audits/`**: Quality Gates und Code-Audits (`medinix-build-gate`, `medinix-audit-suite`).
- **`04-knowledge-vector/`**: Die Wissensextraktions-Pipeline (`medinix-knowledge-pipeline`).
- **`05-ops-deploy/`**: Host-spezifische Ops-Scripte (Achtung: oftmals unportabel).
- **`06-kanban/`**: Kanban-Orchestrierung.
- **`07-patterns-misc/`**: Vermischte Patterns und CI-Gates.
- **`shared/`**: Gemeinsame Werkzeuge (`scripts/`) und Referenzen (`references/`), die von den Skills genutzt werden.

## 🛠️ Loading Matrix (Wann lade ich was?)

Nutze die folgende Matrix, um zu entscheiden, welche Skills für welchen Task relevant sind:

### 1. "Baue ein neues Service-Modul / Integriere Code"
Lade in dieser Reihenfolge:
1. `medinix-implement-discipline` (Für das Behavior & Anti-Halluzination)
2. `medinix-module-author` (Für die Modul-Regeln)

### 2. "Ich bin fertig und will committen"
Lade:
1. `medinix-build-gate` (Führt dich durch Context7, Portability und Audit)
2. `medinix-audit-suite` (Die eigentlichen Scan-Tools)

### 3. "Wir haben Eval- oder Build-Fehler"
Lade:
1. `medinix-implement-discipline` (Denke nach, bevor du blind fixt)
2. `medinix-debug-nix`

### 4. "Extrahiere Chat-JSON in den Vector-Store" ODER "Suche im Vector-Store"
Lade:
1. `medinix-knowledge-pipeline` (Regelt den Build- UND Retrieval-Prozess)

### 5. "Mache einen Architektur-Review / Feature-Creep-Check"
Lade:
1. `medinix-feature-creep-audit`
2. `medinix-governance`
