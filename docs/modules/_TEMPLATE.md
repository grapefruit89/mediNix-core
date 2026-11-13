---
title: <ID> — <Dienst> (eine Zeile, was er tut)
---

# <ID> — <Dienst>

**Datei:** `<pfad>.nix` · **Nummer:** <NNN> → Port/UID <NNN>0 · **ADR:** `ADR-<NNN>-<slug>.md`

## 1. Zweck

Ein Satz. Was wäre ohne den Dienst kaputt?

## 2. Warum nicht der naheliegende Weg

Welche Option oder welches Upstream-Modul wurde verworfen, und warum. Belegstelle als
`datei:zeile`. Wenn nichts verworfen wurde: „keine Abweichung" — und den Abschnitt kurz halten.

## 3. Architektur-Muster

Rolle im Rahmen (Manifest-Konsument, Ingress-Organ, Engine-Kunde …), Besitzverhältnisse
(`ownsAccount`), wie die Unit entsteht (Factory, eigener Block, `mkMerge`).

## 4. Fallstricke

| Fallstrick | Wirkung | Schutz |
|---|---|---|
| … | bricht still / bricht laut | Assertion `datei:zeile` / keiner (bewusst) |

## 5. Abhängigkeiten

Was das Modul liest, was es **nicht** liest. Gerichtet: Quelle → Ableitung
(ADR-040). Keine Gegenrichtung.

## 6. Prüfen

Die Befehle, mit denen man den Ist-Zustand belegt. Kein „sollte", kein „vermutlich".

```bash
systemctl show <unit> -p User -p DynamicUser -p StateDirectory
ss -ltnp | grep <port>
```

## 7. Offene Fragen

Was ungeprüft ist. Mit **ungeprüft** markieren und die Gegenprobe nennen, nicht raten.
