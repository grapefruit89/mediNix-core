# Backlog: NixOS KI-Agenten und Tools Vergleich (Hermes WebUI Frickel-Session)

- **Datum:** 2026-10-26
- **Quelle:** `todo/_input/DeepSeek_NixOS-KI-Agenten-und-Tools-Vergleich_20261025-2333.json` (108 Nachrichten)
- **Status:** off-topic / verworfen
- **Thema:** Fehlgeschlagene Einrichtung der Hermes WebUI auf einer minimalen NixOS-Testinstanz

## Kernaussage
Versuch, die `hermes-webui` (NousResearch) auf einem minimalen NixOS-Testsystem (`192.168.2.73`) lauffähig zu machen. DeepSeek verstrickt sich über 100 Nachrichten in imperative Frickeleien (npm, socat, python-socket-forwarder im Hintergrund, virulente venv-Probleme und fehlschlagende Rebuilds), bis der frustrierte Nutzer die Session abbricht und eine saubere Handoff-Übergabe an Claude Code verlangt.

## Bewertung & Grund für Backlog
Reine Tool-Installationssession auf einer externen Test-VM, völlig außerhalb des Scopes von `mediNix-core`. Dient als extremes Anschauungsbeispiel für imperative Anti-Patterns und Tool-Halluzinationen (bestätigt die Notwendigkeit von Block 16: Agent Error Taxonomy), enthält aber keinerlei Code oder Architekturentscheidungen für mediNix-core.
