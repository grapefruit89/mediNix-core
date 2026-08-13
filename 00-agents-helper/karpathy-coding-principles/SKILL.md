---
name: karpathy-coding-principles
description: "LLM coding errors avoid: think simplify surgical goal."
---

# Karpathy Coding Principles

Verhaltensregeln gegen typische LLM-Coding-Fehler (Quelle: multica-ai/andrej-karpathy-skills, CLAUDE.md).
Tradeoff: bias toward caution over speed. Bei trivialen Tasks: Urteil nutzen.

Vier Prinzipien (aktiv bei jeder Implementierungsaufgabe):

## 1. Think Before Coding
- Annahmen explizit machen. Bei Unsicherheit fragen, nicht raten.
- Mehrere Interpretationen vorhanden → präsentieren, nicht still auswählen.
- Einfacherer Weg existiert → sagen. Push back wenn gerechtfertigt.
- Etwas unklar → stoppen, benennen was verwirrt. Fragen.

## 2. Simplicity First
- Minimaler Code der das Problem löst. Nichts Spekulatives.
- Keine Features über das Angefragte hinaus.
- Keine Abstraktionen für single-use Code.
- Keine "Flexibilität"/"Configurability" die nicht angefragt war.
- Keine Error-Handling für unmögliche Szenarien.
- 200 Zeilen wo 50 reichen → rewrite.

Frage: "Would a senior engineer say this is overcomplicated?" Wenn ja → simplify.

## 3. Surgical Changes
- Nur anfassen was der Task verlangt. Eigenen Mist selbst aufräumen.
- Kein "Verbessern" von adjacent code/comments/formatting.
- Kein Refactor von nicht-kaputtem Code.
- Existierenden Style matchen, auch wenn man es anders machen würde.
- Unrelated dead code → erwähnen, nicht löschen.
- Wenn Änderungen Orphans erzeugen: nur DIESE imports/vars/functions entfernen.
- Test: jede geänderte Zeile muss sich auf die User-Anfrage zurückverfolgen lassen.

## 4. Goal-Driven Execution
- Erfolg definieren bevor man loslegt. Bis zur Verifikation loopen.
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"
- Multi-step: Plan mit verify pro Step:
  ```
  1. [Step] → verify: [check]
  2. [Step] → verify: [check]
  ```

## Wann das greift
Aktiv bei jeder Implementierungsaufgabe. Besonders bei mediNix-core: Annahmen zu
Port/UID/GID/Profil explizit machen, nicht blind harte Werte raten, nur betroffene
Module patchen, nixos-decimal-audit nach jedem Commit.

## Erfolgs-Indikator
Weniger unnötige Diff-Zeilen, weniger Rewrites wegen Overcomplication, Klärungsfragen
kommen VOR der Implementierung statt nach dem Fehler.
