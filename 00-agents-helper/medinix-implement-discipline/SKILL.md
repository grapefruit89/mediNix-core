---
name: medinix-implement-discipline
category: devops
description: "Use when implementing or modifying any mediNIX-core (or NixOS mediNix) code — modules, options, assertions, or docs. Enforces: read-first (Karpathy), ponytail 7-rung decision ladder (YAGNI/minimal), KISS/Pareto, and NixOS idioms (registry, factory, dezimalrahmen, portable, no-netns). Prevents hallucinated code, scope creep, and host-name leaks. Load this at the start of EVERY mediNIX task."
---

# mediNix Implement Discipline

Verhaltens-Skill für mediNix-core / Hermes.
Ziel: korrekte, minimale, portable NixOS-Änderungen — ohne Halluzination und ohne Overbuild.

## Priorität (bei Konflikt gewinnt die höhere Nummer)

1. Safety / Invarianten / Fail-closed
2. Ist-Code lesen und belegen
3. YAGNI + Pareto (minimaler Eingriff, maximaler Nutzen)
4. KISS (so einfach wie möglich, so hart wie nötig)
5. NixOS- / mediNix-Idiom
6. Surgical (nur betroffene Stellen)

Sicherheit darf der Faulheit nie geopfert werden.

---

## Phase A — Kontext zuerst (Karpathy)

Vor jedem Patch:

1. Auftrag in 1–2 Sätzen: Ziel + explizites Nicht-Ziel.
2. Relevante Dateien öffnen und lesen (nicht aus dem Gedächtnis):
   - `lib/registry.nix`
   - `lib/service-factory.nix` / `lib/hardening-profiles.nix` (wenn Services)
   - betroffene `NNN-*.nix`
   - Optionen in `default.nix`
3. Ist-Zustand mit Beleg nennen (Datei + was schon existiert).
4. Annahmen und Unklarheiten explizit machen; bei echter Ambiguity nachfragen.
5. Überkomplizierte Wege aktiv verwerfen (z. B. netns).

Ohne Phase A kein Code.

---

## Phase B — Entscheidungsleiter (Ponytail / YAGNI)

Nach dem Lesen, vor dem Schreiben — Stufen der Reihe nach:

1. Braucht es überhaupt eine Änderung? → sonst stop.
2. Existiert das Verhalten schon (Modul, Option, Timer, Assert)? → wiederverwenden / einschalten.
3. Reicht NixOS-Bordmittel, Factory, Registry, bestehendes Pattern? → nutzen.
4. Reicht eine kleine Ergänzung in einer bestehenden Datei? → dort ändern.
5. Geht es in wenigen Zeilen / einem `mkIf`? → so.
6. Spekulativ („später nützlich“, generisches Framework)? → nicht bauen.
7. Erst dann: neues Modul/Abstraktion — und nur das Minimum.

Pareto: 20 % Eingriff für 80 % Wirkung bevorzugen.
KISS: keine zweite Architektur neben Registry/Factory.

---

## Phase C — mediNix- / NixOS-Idiom

- Deklarativ über `grapefruitMedia.*`-Optionen; keine Host-IPs/Namen als Default.
- Registry = SSoT für Port/UID/GID (Port = Num×10, UID = Port, GID = 5000).
- Unit-Namen = plain (`sonarr.service`); StateDirectory darf Port-Suffix haben.
- Portabel: keine q958 / m7c5 / 192.168 / privado als Modul-Wahrheit.
- Kein netns, kein `NetworkNamespacePath`.
- VPN: RestrictNetworkInterfaces + Policy-Routing-Logik an `vpn.interface`; Host liefert Interface.
- DNS: Sandbox-resolv nur aus `vpn.dnsServers`; leer + confinement → Assert.
- Secrets: nie Inhalt loggen, nie in Cmdline; Pfade über Optionen.
- Fail-closed: kaputte Security-Kombi → `assertions`, Eval bricht.
- Host-Pflichten nur in einer `ADMIN-HANDOFF.md`.

---

## Phase D — Surgical

- Nur Dateien anfassen, die zum Auftrag gehören.
- Kein Nebenbei-Refactor, kein Massen-Format, kein „tote Dateien löschen“ ohne Auftrag.
- Nur eigenen, durch *diese* Änderung obsolet gewordenen Code aufräumen.

---

## Phase E — Prüfbare Abnahme

Fertig nur wenn z. B.:
- Optionen konservativ, Verhalten über Option steuerbar
- confinement ohne interface/dns → Eval-Fehler (wo vorgesehen)
- rg auf private Host-Namen in *.nix sauber (nur generische examples)
- Unit-/StateDir-Konventionen eingehalten
- ADMIN-HANDOFF höchstens Minimal-Schnittstelle
- kurzer CHANGELOG bei sichtbarem Verhalten

**Verifikation (TDD-light, kein Ritual):**
- Wo ein Nix-Check-Host verfügbar ist: `nix eval` / `nix flake check` nach dem Patch ausführen.
- Betroffene Assertions benennen (nicht nur "Patch gelesen → fertig" behaupten).
- Kein "fertig" allein aus dem eigenen Patch-Review — echte Eval schlägt mehr als Lesen.
- Kein Check-Host / q958 AUS: ehrlich melden "Check nicht gelaufen — P0 bleibt offen". Nicht fake-grün.

---

## Antwortstil (Caveman-light)

- Knapp. Kein Geplänkel, kein Höflichkeitsroman.
- Erst Report-Format (Ist/Lücke/Plan/Nicht/Abnahme), dann Diff/Befehl.
- Erklärungen nur wenn für Abnahme oder Trade-off nötig.
- Code bleibt unangetastet — nur Prosa kürzer. KISS auf Kommunikationsebene.

---

## Report-Format (Pflicht vor dem Patch)

Ist:     <Datei/Verhalten mit Beleg>
Lücke:   <was wirklich fehlt>
Plan:    <minimale Änderung, Dateiliste>
Nicht:   <bewusst weggelassen>
Abnahme: <1–3 prüfbare Kriterien>
Nach dem Patch: geänderte Dateien + Einschalt-Optionen + Host-Rest (wenn nötig).

---

## Nie tun

- netns / NetworkNamespacePath
- private Host-Namen oder LAN-IPs als Default
- Secrets loggen oder in Cmdline
- Medien-Library löschen / „smarte“ GC ohne enge Grenzen
- neues Framework, solange Factory/Registry/Option reichen
- Behauptungen ohne Datei-Beleg

---

## Schnellbeispiele

| Auftrag | Diszipliniert | Falsch |
|---------|---------------|--------|
| SQLite optimieren | 542 + Option erweitern | neues Meta-Timer-Framework |
| VPN härten | Rules an UID + vpn.interface | netns |
| DNS | dnsServers + Bind + Assert | stubby fest ins Modul |
| Unit-After kaputt | plain sonarr.service | alles auf name-port umbenennen |
