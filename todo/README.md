  # Agent-Anweisung: Chat-Konsolidierung mediNix-core

  ## Absolute Pfade (verbindlich)

  Alle Dateien werden über **absolute Pfade** referenziert. Keine relativen
  Pfade, kein `cd` vorausgesetzt.

  | Rolle                           | Absoluter Pfad                                               |
  | ------------------------------- | ------------------------------------------------------------ |
  | Repo-Root                       | `/home/moritz/repos/mediNix-core`                            |
  | Todo-Root                       | `/home/moritz/repos/mediNix-core/todo`                       |
  | Chat-Input (read-only)          | `/home/moritz/repos/mediNix-core/todo/_input/chat.json`      |
  | Topic-Index (Output)            | `/home/moritz/repos/mediNix-core/todo/_index/topics.json`    |
  | Block-Extrakte (Output)         | `/home/moritz/repos/mediNix-core/todo/blocks/<NN>-<thema>.json` |
  | Rohchunks (Archiv)              | `/home/moritz/repos/mediNix-core/todo/_archive/`             |
  | Aggregiertes Todo (Output)      | `/home/moritz/repos/mediNix-core/todo/plan.json`             |
  | Menschenlesbare Zusammenfassung | `/home/moritz/repos/mediNix-core/todo/decisions.md`          |
  | Backlog (Offene Aufgaben)       | `/home/moritz/repos/mediNix-core/todo/backlog/`              |
  | Done (Erledigte Aufgaben)       | `/home/moritz/repos/mediNix-core/todo/done/`                 |
  | Dieses Dokument                 | `/home/moritz/repos/mediNix-core/todo/README.md`             |
  | JSON-Schema                     | `/home/moritz/repos/mediNix-core/todo/schema.json`           |

  **Code-Referenzen** (nur lesen, niemals schreiben):
  - `/home/moritz/repos/mediNix-core/50-core/*.nix`
  - `/home/moritz/repos/mediNix-core/51-ingress/*.nix`
  - `/home/moritz/repos/mediNix-core/52-security/*.nix`
  - `/home/moritz/repos/mediNix-core/lib/*.nix`
  - `/home/moritz/repos/mediNix-core/docs/**`

---

## Aktueller Fokus: Aufgabe 09 (Modul-Umsortierung nach ADR-0000)

> [!CAUTION]
> **STATUS: ENTWURF / GEPLANT — NICHT AUTOMATISCH OHNE FREIGABE AUSFÜHREN!**
> Aufgaben im Backlog dienen als strukturierte Arbeitsgrundlage und dürfen von KI-Agenten niemals unaufgefordert ohne Review und Freigabe ausgeführt werden.

- **Aktive Aufgabe:** [`todo/backlog/09-modul-umsortierung-nach-adr-0000.md`](/home/moritz/repos/mediNix-core/todo/backlog/09-modul-umsortierung-nach-adr-0000.md)
  - **Inhalt:** `54-transfer` $\rightarrow$ `54-processing`, `572-recyclarr` $\rightarrow$ `537-recyclarr`, `574-provisioning` $\rightarrow$ `538-provisioning`, `575-update-notifier` $\rightarrow$ `588-update-notifier`.
- **Folgeaufgabe:** [`todo/backlog/08-skills-flach-machen-und-projekt-anpassen.md`](/home/moritz/repos/mediNix-core/todo/backlog/08-skills-flach-machen-und-projekt-anpassen.md)
  - **Inhalt:** `agent/skills/` $\rightarrow$ `skills/`, Archivierung von `nix-packaging` und `cross-platform.md`, Neuanlage von `medinix-project.md`, `.claude/skills/`-Symlinks anpassen.
- **Abschluss:**
  - **Aufgabe 10 (Finale Validierung):** Alle Checks grün, `find`-Suche nach übriggebliebenen Artefakten, `git status` sauber, keine toten Symlinks.

### Begründung für die Reihenfolge (Aufgabe 09 vor 08):
- **Aufgabe 09** ändert Module (`54-processing`, `537-recyclarr`, `538-provisioning`, `588-update-notifier`), was `scripts/medinix-meta.py generate-docs` betrifft (Modul-Tabellen in allen `AGENTS.md` werden neu geschrieben).
- **Aufgabe 08** bricht die zwei `.claude/skills/`-Symlinks — diese sollen genau einmal gefixt werden. Wenn Aufgabe 08 zuerst liefe, müssten die Symlinks zweimal angefasst werden. Also strikt 09 vor 08.

---

## Backlog — offene Aufgaben

- **Dateinamen-Konvention:** Aktive Aufgaben liegen als Markdown-Dateien unter `/home/moritz/repos/mediNix-core/todo/backlog/NNN-kebab-case-titel.md`.
- **Reihenfolge-Regel:** Das Nummern-Präfix (`NN-` / `NNN-`) bestimmt die verbindliche Abarbeitungsreihenfolge (`09` vor `08`).
- **Status-Regel:** Die aktuell aktive Aufgabe wird in `/home/moritz/repos/mediNix-core/todo/README.md` unter `## Aktueller Fokus` geführt.
- **Done-Regel:** Erledigte Aufgaben wandern nach erfolgreichem Abschluss und Review per `git mv` nach `/home/moritz/repos/mediNix-core/todo/done/NNN-kebab-case-titel.md` (sie werden niemals gelöscht).
- **Neue-Aufgaben-Regel:** Neue Vorhaben oder Refactoring-Aufgaben landen immer direkt als Spezifikation in `/home/moritz/repos/mediNix-core/todo/backlog/` (keine neuen Root-Ordner, keine fliegenden Zettel, kein reines Chat-Gedächtnis).
- **Session-Start-Regel für Agenten:** Bei Start jeder neuen Session liest der Agent zuerst `/home/moritz/repos/mediNix-core/todo/README.md` (Abschnitt `## Aktueller Fokus`) und die entsprechende Backlog-Spezifikation unter `/home/moritz/repos/mediNix-core/todo/backlog/`, um den Kontext und die Arbeitsschritte vollständig aufzunehmen.

---

  ## Rolle
  Du bist ein Code-Review- und Konsolidierungs-Agent. Du bekommst einen
  rohen Chat-Export (`/home/moritz/repos/mediNix-core/todo/_input/chat.json`).
  Deine Aufgabe ist NICHT, Code zu ändern. Deine Aufgabe ist, den Chat
  themenweise zu lesen, den Ist-Zustand des Codes zu messen, den Diff zu
  bewerten und das Ergebnis als strukturierte JSON abzulegen – so, dass
  kein Wissen verloren geht.

  ## Verdict-Konvention (verbindlich)

`verdict` bewertet die **Änderung**, nicht den Zustand.

| Situation | `verdict` |
|---|---|
| Änderung wird vorgeschlagen, die den Code **verbessert** | `better` |
| Änderung wird vorgeschlagen, die den Code **verschlechtert** | `worse` |
| **Status Quo bleibt** (nichts ändert sich) | `neutral` |
| Nicht bewertbar (Code fehlt, Kontext fehlt) | `unknown` |

**Beispiel korrekt:**
- „mDNS/515 wird entfernt" → `better` (Änderung)
- „NixOS bleibt Basis" → `neutral` (Status Quo)

**Beispiel falsch:**
- „NixOS bleibt Basis" → `better` ❌ (keine Änderung)

## Message-ID-Konvention (verbindlich)

`message_ids` verwendet **0-indexierte Array-Indizes** in
`/home/moritz/repos/mediNix-core/todo/_input/chat.json`.

| Nachricht im Chat | `id`-Suffix | Array-Index |
|---|---|---|
| 1. Nachricht | `_1` | `0` |
| 73. Nachricht | `_73` | `72` |
| 126. Nachricht | `_126` | `125` |

Diese Konvention gilt für:
- `_index/topics.json` (Keys `"0"` bis `"125"`)
- `blocks/*.json` (`message_ids`, `source_message_ids`)

Der Pilot-Block `blocks/05-mdns-vs-blocky.json` wurde auf diese Konvention
korrigiert (`[72..79]` statt `[73..80]`).

## Eiserne Regeln

  1. **Nicht blind einfügen.** Du änderst KEINE Datei außerhalb von
     `/home/moritz/repos/mediNix-core/todo/`. Kein
     `/home/moritz/repos/mediNix-core/51-ingress/*.nix`, kein
     `/home/moritz/repos/mediNix-core/50-core/*.nix`, kein
     `/home/moritz/repos/mediNix-core/lib/*`.

  2. **Erst lesen, dann verstehen, dann prüfen.** Für jede Code-Referenz
     im Chat: die tatsächliche Datei unter dem absoluten Pfad lesen. Wenn
     sie fehlt: `code_ref_status: "missing"`.

  3. **Der Code ist die Wahrheit, der Chat ist die Begründung.** Bei
     Widerspruch: beide Seiten dokumentieren (`contradiction: true`).

  4. **Bei Unsicherheit: `unknown`.** Nicht raten.

  5. **Nichts löschen.** Rohchunks nach
     `/home/moritz/repos/mediNix-core/todo/_archive/`, nicht löschen.

  6. **Keine Secrets.** Keine Passwörter/Tokens/Keys in die JSONs.
     Nur `secret_mentions: [{what, path, value_redacted: true}]`.

  7. **Ein Block = eine JSON.** Pflichtfelder: `block_id`, `title`,
     `topics`, `message_ids`, `summary`, `decisions`, `open_questions`,
     `corrections`, `rejected`, `next_steps`.

  8. **Topic-Hopping ist Pflicht.** Nicht sequenziell. Erst Topic-Index,
     dann pro Thema filtern.

  9. **Absolute Pfade in jedem `file`-Feld.** Keine relativen Pfade wie
     `51-ingress/515-mdns.nix`, sondern immer
     `/home/moritz/repos/mediNix-core/51-ingress/515-mdns.nix`.

  ## Phasen

  ### Phase 0: Inventar
  - `/home/moritz/repos/mediNix-core/todo/_input/chat.json` laden,
    `jq 'length'` zählen.
  - Rollen prüfen: `user`/`assistant`, `contents[].type == "text"`.

  ### Phase 1: Topic-Index bauen
  - Jede Nachricht mit 1–3 Themen taggen. Seed-Themen:
    arch-vs-nixos, config-review-51-ingress, crowdsec-scan-ban,
    caddy-catch-all, mdns-vs-blocky, dns-wan-ip-provider,
    credentials-systemd-creds, pqc-hndl, firewall-nftables,
    kernel-hardening, power-management, 51-tree-struktur,
    adr-dezimalrahmen, lib-vs-50-core.
  - Output: `/home/moritz/repos/mediNix-core/todo/_index/topics.json`
    mit `{ "message_id": [...topics] }`.

  ### Phase 2: Pro Thema filtern
  - Für jedes Thema: message_ids sammeln, in
    `/home/moritz/repos/mediNix-core/todo/blocks/<NN>-<thema>.json`
    als `message_ids` eintragen.
  - Keine vollen Nachrichten kopieren – nur IDs. Rohdaten bleiben in
    `/home/moritz/repos/mediNix-core/todo/_input/chat.json`.

  ### Phase 3: Pro Block analysieren
  1. Alle Nachrichten des Blocks lesen (per message_ids aus
     `/home/moritz/repos/mediNix-core/todo/_input/chat.json`).
  2. Jede Code-Referenz prüfen: Datei unter absolutem Pfad lesen,
     Ist-Zustand extrahieren.
  3. Entscheidungen extrahieren mit Status:
     decided | proposed | rejected | open.
  4. Verdict pro Entscheidung:
     better | worse | neutral | unknown.
     Immer mit `rationale` und `trade_offs: {pro, con}`.
  5. Korrekturen dokumentieren (from → to).
  6. Verworfenes dokumentieren (idea + reason).
  7. Offene Fragen + next_steps (mit Priorität).
  8. Ausgabe nach
     `/home/moritz/repos/mediNix-core/todo/blocks/<NN>-<thema>.json`.

  ### Phase 4: Konsolidieren
  - `/home/moritz/repos/mediNix-core/todo/plan.json` schreiben:
    alle todos aggregiert.
  - `/home/moritz/repos/mediNix-core/todo/decisions.md` schreiben:
    menschenlesbare Zusammenfassung.

  ### Phase 4b: Anti-Pattern-Register
  Aggregiere alle `rejected[]`-Einträge aus allen Blöcken in
  `/home/moritz/repos/mediNix-core/todo/antipatterns.md`.
  Format pro Eintrag:
  - ID (A-NN)
  - Idee (aus `rejected[].idea`)
  - Warum verworfen (aus `rejected[].reason`)
  - Quelle (Block-ID)

  ### Phase 4c: Snippet-Register
  Aggregiere alle `better`-Entscheidungen mit `proposed_change` in
  `/home/moritz/repos/mediNix-core/todo/snippets.md`.
  Format pro Eintrag:
  - ID (S-NN)
  - Code-Snippet (aus `code_refs[].proposed_change`)
  - Quelle (Block-ID, Decision-ID)
  - Warum besser (aus `rationale`)

  ### Historisches Backlog (Wissens-Archiv für Chat-Exzerpte)
  Ideen, Analysen oder Chat-Exzerpte, die keine neuen Blöcke in `todo/blocks/` erzeugen (weil sie redundant zu bereits dokumentierten Entscheidungen sind, veraltete Vorgänger-Repositories betreffen oder als off-topic verworfen wurden), landen strukturiert in `/home/moritz/repos/mediNix-core/todo/_archive/history-backlog/`.
  - **Warum:** Wissen und historische Diskussionspfade bewahren, ohne den aktiven Plan/Block-Baum mit Rauschen zu belasten (Zero-Knowledge-Loss-Prinzip).
  - **Format:** Eine Markdown-Datei pro Thema (`<datum>_<chat>_<thema>.md`) plus zentraler Katalog in `/home/moritz/repos/mediNix-core/todo/_archive/history-backlog/_index.json`.

  ### Phase 5: Archivieren
  - Rohchunks in `/home/moritz/repos/mediNix-core/todo/_archive/`
    belassen.

  ## Quality Gates (Block ist erst "done", wenn …)
  - [ ] Jede decision hat status, verdict, rationale.
  - [ ] Jede code_ref hat status (exists/missing) + current_state.
  - [ ] Jede code_ref.file ist ein absoluter Pfad.
  - [ ] Jede correction hat from + to.
  - [ ] Jede rejected hat reason.
  - [ ] Keine Secrets in der JSON.
  - [ ] plan.json ist valide JSON.

  ## Verbindliche Agenten-Regeln (Quelle: blocks/16-agent-error-taxonomy.json)
  1. **Gate berechnet ≠ Gate erzwungen:** Kein Git-Commit bei rotem Eval oder fehlschlagendem Gate — auch wenn „nur Doku" geändert wurde.
  2. **Keine Spekulation bei Tool-Aufrufen:** Attributpfade, Optionen und Typen vorab gegen `nix eval` oder `options.json` validieren, nicht aus dem Gedächtnis.
  3. **Pipes & Exit-Codes absichern:** In Shell-Pipes `set -o pipefail` erzwingen; Exit-Codes vor Folgeaktionen explizit prüfen. Trailing-Commas ausschließen.
  4. **Scheiben-Messen vermeiden:** Mehrere unabhängige Statusabfragen in einem Lauf bündeln (`sys-triage`, multi-path Checks), nicht sequenziell tröpfeln.
  5. **Plan vor Code-Änderung:** Vor Code-Änderungen Plan zeigen (Freshness Gate + erwartete Konflikte).

  ## Startbefehl
  Lies /home/moritz/repos/mediNix-core/todo/README.md und
  /home/moritz/repos/mediNix-core/todo/schema.json.
  Führe Phase 0 + 1 aus (Inventar + Topic-Index).
  Bearbeite dann Block 05 (mdns-vs-blocky) als Pilot.
  Stoppe danach und warte auf Review.

  ## Nicht-Ziele
  - Keine Code-Änderungen.
  - Keine neuen ADRs.
  - Keine Dateien außerhalb von
    /home/moritz/repos/mediNix-core/todo/ anfassen.
    ## Phase 5: Self-Archive
Siehe /home/moritz/repos/mediNix-core/todo/PHASE5.md
Referenz-Implementierung: /home/moritz/repos/mediNix-core/todo/phase5-archive.py
Trigger: erst wenn alle Blöcke fertig und plan.json + decisions.md geschrieben sind.

    ## Phase 6: Code-Abgleich (nach Phase 5)
Für jeden Block in `done/<chat-id>/blocks/`:
- Jeden `code_ref` mit `verified: false` prüfen
- `current_state` gegen echten Code verifizieren
- `proposed_change` gegen echten Code prüfen (schon umgesetzt?)
- Konflikte dokumentieren

Output: `/home/moritz/repos/mediNix-core/todo/done/<chat-id>/code-diff.md`
Format pro Änderung:
- Datei (absolut)
- Zeile / Bereich
- Ist-Zustand (aus Code)
- Soll-Zustand (aus `proposed_change`)
- Status (offen / umgesetzt / Konflikt)
