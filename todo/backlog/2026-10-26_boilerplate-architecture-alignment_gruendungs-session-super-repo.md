# Backlog: NixOS Boilerplate Architecture Alignment (Gründungs-Session Super-Repo)

- **Datum:** 2026-10-26
- **Quelle:** `todo/_input/DeepSeek_NixOS-Boilerplate-Architecture-Alignment_20261025-2335.json` (102 Nachrichten)
- **Status:** redundant (bereits im Fundament implementiert)
- **Thema:** Konsolidierung von 4 Vorläufer-Repositories in das Super-Repo (mediNix-core)

## Kernaussage
Historische Alignment-Session, in der die Grundgesetze des heutigen mediNix-core geschmiedet wurden:
1. **1:1:1 Isomorphismus:** Jedes Modul erhält ein zugeordnetes ADR und Doku (heute: Docs-Trias, Block 25).
2. **Operational Dependency Order (ODO):** Dezimalpräfixe 00..90 spiegeln die Boot- und Abhängigkeitsreihenfolge wider (heute: ADR-0000).
3. **NIXMETA YAML-Header:** Maschinenlesbarer Header `# ---` statt ausführbarer Nix-Attrsets (heute: ADR-00).
4. **Technologie-Verbote:** Ausschluss von Docker, Nginx, Uptime Kuma, MariaDB (heute: `50-core/BANNED_TECHNOLOGIES.md`).
5. **Agenten-Steuerung:** Single-Step-Modus zur Vermeidung von Endlos-Kompression und Loop-Drift (heute: Agent Error Taxonomy, Block 16).

## Bewertung & Grund für Backlog
Fundamentale historische Sitzung, deren Ergebnisse bereits vollständig im bestehenden Code- und Doku-Bestand aufgegangen sind. Alle darin beschlossenen Regeln sind längst verbindliche Verfassung von mediNix-core. Keine neuen offenen Todos.
