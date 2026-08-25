# ---
# id: "PATTERN-08-mcp-second-brain"
# title: "Concept: mediNix Second Brain (SQLite + MCP)"
# domain: 56
# folder: 56-agents/08-mcp-second-brain
# status: active
# complexity: 4
# last_reviewed: 2026-08-25
# links:
#   adr: ""
# ---

# Architektur-Konzept: Das KI "Second Brain" (SQLite + MCP)

Dieses Dokument beschreibt die Architektur für ein lokales, hochperformantes Wissensnetzwerk (Knowledge Graph) für das `mediNix-core` Projekt. Ziel ist es, LLM-Agenten (wie Antigravity) einen sofortigen, semantischen und strukturellen Überblick über die gesamte Codebasis zu geben, ohne dass sie manuell Dateien durchsuchen (`grep`) müssen.

## 1. Das Grundprinzip (SSoT vs. Index)

Wir trennen die Speicherung streng nach Zielgruppen:
1. **Single Source of Truth (SSoT):** Alle `.nix` und `.md` Dateien auf der Festplatte. Sie werden von Menschen und KIs bearbeitet, über Git versioniert und enthalten detaillierte YAML-Header (`provides`, `requires`, `context7`).
2. **Der Index (Second Brain):** Eine lokale SQLite-Datenbank (`second-brain.sqlite`). Sie ist ein reines Lese-Konstrukt (Compiled Index), das regelmäßig aus der SSoT generiert wird. Sie ist optimiert für die blitzschnelle Befragung durch KIs.

## 2. Die Architektur-Komponenten

### Komponente A: Der Ingestor (Python Scanner)
Ein Python-Skript (z.B. als Pre-Commit-Hook oder per Cronjob), das das gesamte Repository scannt:
- **Parsen:** Es liest alle YAML-Header aus (extrahiert Relationen wie *X requires Y*).
- **Chunking:** Es zerlegt den Code und die Markdown-Doku in sinnvolle Absätze.
- **Speichern:** Es schreibt die Daten in die SQLite-Datenbank und baut den FTS5-Index (Full Text Search) auf.
- **Vektorisieren (Zukunft):** Generiert Embeddings der Text-Chunks (via `sqlite-vec`), um semantische Suchen ("Wer macht hier Proxy-Sachen?") zu ermöglichen.

### Komponente B: Das Datenbankschema (SQLite)
Die Datenbank hat drei Haupt-Tabellen:
1. `modules` (id, path, domain, title, status, context7_query) -> Metadaten-Übersicht.
2. `dependencies` (source_id, target_id, type) -> Bildet den Graphen ab (provides/requires).
3. `chunks_fts` (Virtual Table FTS5) -> Beinhaltet den rohen Text der Dateien für rasend schnelle Keyword-Suchen.

### Komponente C: Der MCP-Server
Ein kleiner Python-Server (`mcp_medinix_brain`), der das Model Context Protocol (MCP) spricht und der KI folgende Tools (`tools`) zur Verfügung stellt:
- `brain_search(keyword)`: Nutzt FTS5, um blitzschnell Dateien zu finden, die ein Konzept erwähnen.
- `brain_get_dependencies(module_id)`: Nutzt SQL-Joins, um sofort aufzulisten: "Wer hängt von Caddy ab?" und "Wovon hängt Caddy ab?".
- `brain_get_context7_hint(module_id)`: Gibt sofort die perfekte Dokumentations-Abfrage für den Context7-Server zurück, bevor die KI den Code anfasst.

## 3. Der Workflow (Ein Tag im Leben des Agenten)

1. Der User sagt: *"Füge Jellyseerr zum Killswitch hinzu."*
2. Der Agent ruft `brain_get_dependencies("526-vpn-killswitch")` auf.
3. Der MCP-Server antwortet: *"Aktuell hängen SABnzbd und Prowlarr dran. Hier ist der Dateipfad."*
4. Der Agent ruft `brain_search("Jellyseerr port")` auf.
5. Der MCP-Server antwortet: *"Gefunden in 555-jellyseerr.nix (Zeile 15): Port 5055."*
6. Der Agent editiert zielsicher die Datei `526-vpn-killswitch.nix`.

## 4. Vorteile dieser Architektur
- **Zero Hallucination:** Die KI weiß sofort, wie die Architektur zusammenhängt.
- **Token-Sparsamkeit:** Anstatt ganze Dateien zu lesen, bekommt die KI nur die relevanten Chunks aus der FTS5-Datenbank.
- **Robustheit:** Die echten Dateien (`.nix`) bleiben menschenlesbar und versionierbar.
- **Obsidian-Kompatibilität:** Dieselbe SQLite-Datenbank könnte man trivial nutzen, um Visualisierungen (Knowledge Graphs) in einem Web-Dashboard oder für Obsidian zu generieren.

---
**Nächster Schritt zur Implementierung:**
Schreiben des Ingestor-Skripts `build_brain.py` und initialisieren der `second-brain.sqlite` Datenbank mit FTS5-Support.
