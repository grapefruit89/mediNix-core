---
title: Module — Semantik je Dienst
---

# Module — eine Seite pro Dienst

Diese Ebene beantwortet **warum**, nicht **was**. Den Code liest man in der `.nix`-Datei;
hier steht, was man beim Ändern wissen muss und was nicht im Code steht.

## Abgrenzung (damit nichts doppelt gepflegt wird)

| Frage | Ort |
|---|---|
| Was macht der Dienst technisch? | `58-observability/582-gatus.nix` |
| Welche Rolle hat die Domäne? | `58-observability/AGENTS.md` — generiert aus den NIXMETA-Headern |
| Warum ist es so entschieden? | `docs/adr/ADR-582-…` |
| Wie greifen die Schichten 50–59 ineinander? | `docs/arch/` |
| **Warum nicht der naheliegende Weg? Welche Fallstricke? Was hängt woran?** | **hier** |

## Wann eine Seite entsteht

Nicht für jede Datei. Eine Seite lohnt, wenn mindestens eines zutrifft:

- es gibt eine bewusste Abweichung von der naheliegenden Lösung
  (Beispiel: `services.gatus` wird nicht benutzt, siehe [`582-gatus.md`](582-gatus.md)),
- eine Reihenfolge ist nicht egal (Manifest vor Endpunkt),
- ein Fehler ist still — der Build bleibt grün, aber der Dienst fehlt im Dashboard.

**Der Musterfall ist [`582-gatus.md`](582-gatus.md).** 46 Module und 1 Seite ist der
richtige Anfang — nicht 46. Eine neue Seite entsteht erst, wenn ein Agent an dieser
Stelle nachweislich falsch abbiegt.

## Aufbau

[`_TEMPLATE.md`](_TEMPLATE.md) kopieren, sieben Abschnitte füllen, Datei nach der
Modul-ID benennen (`582-gatus.md`).

## Pflege

Der Index in [`../INDEX.md`](../INDEX.md) wird von `docs/generate_index.py` erzeugt —
nicht von Hand eintragen. CI prüft das (`.github/workflows/docs-index.yml`:
Generator laufen lassen, dann `git diff --exit-code`).
