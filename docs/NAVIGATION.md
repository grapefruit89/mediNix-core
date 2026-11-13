---
title: NAVIGATION — Aufgabe → Lese-Reihenfolge
---

# NAVIGATION — Aufgabe → Lese-Reihenfolge

[`INDEX.md`](INDEX.md) beantwortet **„welche Frage → welcher Ort"**. Diese Datei
beantwortet **„welche Aufgabe → welche Dateien, in welcher Reihenfolge"**.

**Warum es diese Datei gibt:** Navigationstest am 2026-11-13 — ein frischer Agent,
Start nur bei `INDEX.md`, Aufgabe „neuen Dienst anlegen": **17 Dateien, 3 Fehlgriffe,
6 Ratestellen.** Die Reihenfolge stand nirgends.

Die Pfade sind absolut, damit sie sich kopieren lassen. Markdown-Links bleiben relativ,
weil mkdocs sie sonst nicht auflöst.

---

## 1. Neuen Dienst anlegen

**Reihenfolge** — jede Zeile nennt, was du dort holst, nicht was drinsteht:

1. `/home/moritz/repos/mediNix-core/docs/adr/ADR-0000-dezimalrahmen-verfassung.md` — Slot 0 ist reserviert, Dekaden, Formel
2. `/home/moritz/repos/mediNix-core/50-core/derive.nix` — die **eine** Formel (`port = uid = gid = num × 10`)
3. `/home/moritz/repos/mediNix-core/50-core/registry.nix` — der SSoT-Eintrag (genau eine Zeile)
4. `/home/moritz/repos/mediNix-core/50-core/service-contract.nix` — Manifest-Schema und die Assertions
5. `/home/moritz/repos/mediNix-core/50-core/501-decimal-engine.nix` — wer Konten besitzt, `daemonServices`
6. `/home/moritz/repos/mediNix-core/50-core/service-factory.nix` — Unit-Gerüst, `ownsAccount`
7. `/home/moritz/repos/mediNix-core/50-core/hardening-profiles.nix` — erlaubte Profilnamen
8. `/home/moritz/repos/mediNix-core/58-observability/581-ntfy.nix` — **das vollständige Muster**: Factory + Manifest + Registry in einer Datei
9. `/home/moritz/repos/mediNix-core/docs/adr/ADR-00-nixmeta-v3-header.md` — Pflichtfelder des Headers
10. `/home/moritz/repos/mediNix-core/default.nix` — der Auto-Import: **keine** Importliste pflegen

Die **Dekade** ist das Präfix der Nummer: `589` → `58-observability`. Welche Rolle eine
Dekade hat, steht in ADR-0000 §3 und in der Repo-Landkarte der `AGENTS.md`.

**Fallen** — alle am 2026-11-13 am Code geprüft:

| Falle | Beleg |
|---|---|
| Der Registry-Eintrag muss **eine Zeile** in genau dieser Form sein (`name = mkService "name" 589 "profil" "caddy";`). Sonst bricht der Parser. | `scripts/gen_service_map.py:50-60` → `SystemExit` bei unbekanntem Muster; `scripts/check_manifest_edge.py:19` liest dieselbe Form textuell |
| `mkManifestEntry` ist definiert und exportiert, wird aber **nirgends aufgerufen**. Praxis ist ein flaches Attrset. | `50-core/manifest.nix:67` (Definition), `:173` (Export), 0 Aufrufer im Repo |
| `583`, `584`, `586`, `587`, `588` sind Oneshot-/Timer-Units **ohne** Manifest und **ohne** Registry-Eintrag. Sie sind **kein** Vorbild für einen Dienst mit Port. | `grep 'medinix\.manifest\.'` = 0 in allen fünf Dateien |
| Keine eigene Caddy-Datei anlegen. Der Ingress liest den Manifest-Eintrag. | `51-ingress/ingress-access.nix:30` — `accessGroupOf` = Vhost-Override, sonst Manifest |
| `num` 500–599 wird nur geprüft, wenn ein Manifest-Eintrag existiert. | `50-core/service-contract.nix:427-432` |
| Zwei fast gleiche Enums: `caddyClass` (Registry) hat 4 Werte, `accessGroup` (Manifest) hat 5. `idp` gibt es **nur** in `accessGroup`. | `50-core/registry.nix` (`none/internal/public/stream`) vs. `50-core/manifest.nix:22-28` (`stream/internal/public/idp/none`) |
| Der Registry-Key ist der **nackte** Dienstname, nicht die Datei-ID: `test = mkService "test" 589 …`, Datei `589-test.nix`. In allen 18 Einträgen ist Key = erstes Argument. | `50-core/registry.nix` — 18/18 geprüft |
| `accessGroup = "internal"` erzeugt einen vHost. Ein vHost mit **leerem** `trustedCidrs` ist ein Build-Fehler — es gibt keinen impliziten LAN-Vertrauensbereich. | `default.nix:412-416` |
| `monitoring.enable` ist per Default `true`, `monitoring.type` per Default `"http"`. Ein Manifest-Eintrag ohne `healthPath` bricht deshalb den Build. | `50-core/service-contract.nix:140` (enable), `:152` (type), `:163-169` (healthPath) |
| Die neue Datei wird automatisch geladen — aber nur, wenn sie `XX-domain/NNN-*.nix` heißt. | `default.nix:26-27` — „Auto-imports every XX-domain/NNN-*.nix module … No hardcoded import list" |
| Eine Modulseite (`docs/modules/<id>-<dienst>.md`) ist **nicht** Pflicht — kein Check verlangt sie. | kein Treffer für `docs/modules` in `scripts/` und `.github/` |

**Nicht ableitbar, also Entscheidung:** welches Hardening-Profil (`base`, `network`, …) zu
welchem Diensttyp passt. `50-core/hardening-profiles.nix` liefert die Sets, aber keine
Zuordnungsregel — die vorhandenen `registry.nix`-Aufrufe sind der einzige Anhaltspunkt.

**Abnahme:** `bash /home/moritz/repos/mediNix-core/scripts/verify.sh` grün — darunter
`check_manifest_edge` (Registry ↔ Manifest) und `gen_service_map --check`.

---

## 2. Ingress-Zugang eines Dienstes ändern

**Reihenfolge:**

1. `/home/moritz/repos/mediNix-core/51-ingress/ingress-access.nix` — die Auflösung: Vhost-Override gewinnt, sonst Manifest
2. `/home/moritz/repos/mediNix-core/51-ingress/511-caddy.nix` — wer den vHost rendert (managed vs. dediziert)
3. `/home/moritz/repos/mediNix-core/51-ingress/AGENTS.md` — Rolle der Domäne, bekannte Klemmen

**Falle:** `accessGroup` hat den Default `null`. Ein Vhost-Eintrag ohne `accessGroup`
(z. B. nur `landing = true`) ist deshalb **kein** Override — er fällt auf das Manifest zurück
(`ingress-access.nix:33-37`). Wer „nichts ändern" will, muss das Manifest ändern.

**Abnahme:** `medinix`-Knopf für den Bereich, danach `verify.sh` grün.

---

## 3. Credential versiegeln und anwenden

**Reihenfolge:**

1. `/home/moritz/repos/mediNix-core/52-security/creds.nix` — der Pfad-Vertrag (`systemd-creds`)
2. `/home/moritz/repos/mediNix-core/52-security/521-creds.nix` — die Optionen und der `sealed`-Helper
3. `/home/moritz/repos/mediNix-core/scripts/medinix-seal-secret.sh` — wie versiegelt wird
4. `/home/moritz/repos/mediNix-core/53-acquisition/arr-key-sync.nix` — **das Muster für den Verbraucher** (`ExecStartPre` schreibt den Klartext dorthin, wo die App ihn liest)
5. `/home/moritz/repos/mediNix-core/docs/AUDIT-LEDGER.md` — L-051: warum `*_FILE` nicht greift

**Falle:** `*_FILE` ist eine Docker-Entrypoint-Konvention. Das NixOS-Paket startet das
Binary direkt und ignoriert sie. Gemessen auf q958: Env gesetzt, App nutzt ihren eigenen
Key, API-Test mit dem versiegelten Wert → HTTP 401 (`AUDIT-LEDGER.md` L-051).

**Abnahme:** `systemctl cat <unit>` zeigt `LoadCredentialEncrypted`, und ein API-Aufruf
mit dem versiegelten Wert antwortet 200.

---

## 4. Dienst debuggen

**Reihenfolge:**

1. `/home/moritz/repos/mediNix-core/docs/RUNBOOK.md` §3 (Unit down) und §5 (Symptom-Playbooks)
2. `medinix triage <bereich|service|symptom>` — arbeitet die Playbook-Kette ab
3. erst danach `journalctl` von Hand

**Falle:** `medinix triage` ist der Knopf, nicht `journalctl -u` als erster Griff
(`RUNBOOK.md:19-22`). Die Playbooks sind maschinenlesbar aus `runbook.json` generiert.

---

## Pflege

Neue Aufgabe = neuer Abschnitt, in derselben Form: nummerierte Reihenfolge mit absolutem
Pfad, Tabelle der Fallen **mit Beleg**, Abnahme. Keine Aufgabe ohne Messung aufnehmen —
die Reihenfolge muss aus einem Test oder aus dem Code kommen, nicht aus dem Gefühl.
