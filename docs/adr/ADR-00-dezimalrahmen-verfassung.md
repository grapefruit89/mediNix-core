---
id: "ADR-00-dezimalrahmen-verfassung"
title: "ADR 0000 dezimalrahmen verfassung"
domain: 00
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - general
links:
  adr: ""
  repo-harvest: ""
---
# ---
# id: 0000
# title: "Dezimalrahmen — die Verfassung des Nummernschemas"
# status: "accepted"
# note: "VERFASSUNG — gilt für jedes Projekt, niemals löschen. Vormals ADR-8000 (Umbenennung: Abschnitt 8)"
# date: "2026-07-22"
# supersedes: [8000]
# related: [5042, 5043]
# tags: ["dezimalrahmen", "verfassung", "numbering", "isomorphie", "fraktal", "anker", "ableitung"]
# error_pattern: "dezimalrahmen|verfassung|vier anker|nummernschema|_0|_1|_2|_9|fraktal|fundament|leitplanken|graduier|ableitung|port.*10|uid|gid|projekt.*1000|welche nummer|wohin geh|block-id|container|blatt"
# ---

> # ⚠ VERFASSUNG — dieses Dokument darf niemals verlorengehen
> **Es regiert das Nummernschema jedes Projekts in diesem Kosmos** — Nix-Grok,
> mediNix, devNIX und alles Künftige. Nicht löschen, nicht ersetzen, nur
> ergänzen. Erweist sich ein Teil als falsch: `status` auf `superseded`, den
> Grund dazuschreiben — aber stehen lassen.
>
> **Verankert in:** `AGENTS.md` + `CLAUDE.md` (mediNix), `CLAUDE.md` + `README`
> (devNIX), Skill `/devnix-agent:struktur`. Wer eines davon anfasst, wird
> hierher geführt.

# ADR-0000 — Der Dezimalrahmen

Ein Nummernschema, das auf **jeder Ebene dasselbe bedeutet** — vom System-Root
bis in einen einzelnen Modulordner. Es ist die einzige Entscheidung, die
**projektübergreifend** gilt: alle anderen ADRs regeln *ein* Projekt, diese die
Grammatik *aller*. Wer sie kennt, findet sich in jedem Repo zurecht, ohne es
gelesen zu haben. **Eine Sprache, überall.**

---

## 1. Fraktal und isomorph

Wiederkehrende Themen tauchen in **jedem** Projekt auf — Medien, Dokumente,
Netzwerk, Agenten. Jedes braucht eine Grundlage, einen Zugang, Sicherheit und
Regeln. Genau diese Themen bekommen **feste Slots**, die überall dasselbe
bedeuten.

Die führende Stelle ist der **Namensraum**, die letzte Stelle die **Rolle**:

```
Ebene 1   /modules/      2-stellig   00 · 10 · 20 · … · 90
Ebene 2   /50-media/     3-stellig   500 · 510 · … · 590
Ebene 3   (bei Bedarf)   4-stellig   5510 · 5520 · …
```

Eine Ebene bleibt **flach** (Dateien), bis sie zu groß wird — dann **graduiert**
sie in eine weitere Stelle. So wurde `50-media` → 50-mediNix (500–590) und
`80-agents` → devNIX (800–890).

### Container-Stellen und Blatt-Stellen

Das Fraktal hat eine präzise Grenze, die bisher unausgesprochen war:

- Eine **Container-Stelle** hält Struktur (Dekaden, Domänen, Ordner). Auf ihr
  gelten die **vier Anker** (Abschnitt 2).
- Eine **Blatt-Stelle** hält Dienste. Auf ihr gibt es nur zwei Rollen:
  **`N0` = Block-ID** (das Fundament der Dekade, nie ein Programm) und
  **`N1`–`N9` = Dienste**.

`532` liest sich also: `5` (Container: Projekt mediNix) · `3` (Container:
Dekade Beschaffung) · `2` (Blatt: zweiter Dienst). Die Anker wiederholen sich
auf jeder Container-Stelle — nicht auf der Blatt-Stelle. **Graduiert ein Slot**
(bekommt eine weitere Stelle), wird seine bisherige Blatt-Stelle zur
Container-Stelle, und die Anker gelten dort erneut. So bleibt das Schema fraktal,
ohne dass „531 = Zugang der Beschaffung" behauptet werden muss — das wäre Unsinn
und wurde nie gemeint.

---

## 2. Die vier Anker — überall gleich

| Slot | Rolle | Frage | Inhalt |
|---|---|---|---|
| **`_0`** | **Fundament** | Womit arbeiten wir? | `CLAUDE.md`, Options-`default.nix`, `docs/`, `registry` — **Wissen und Struktur, keine Dienste** |
| **`_1`** | **Zugang** | Wie kommt man rein? | Reverse-Proxy, mDNS, Routing, Auth-Eingang |
| **`_2`** | **Sicherheit** | Wie geschützt? | Firewall, TLS, VPN-Confinement, Auth-Mechanik |
| **`_9`** | **Leitplanken** | Was muss alles einhalten? | Assertions, Verbote, globale Invarianten |

Wer `_2` sieht, weiß Sicherheit — im System-Root (`20`), in mediNix (`520`),
überall. Ein Projekt **populiert nur die Anker, die es hat**; ein leerer Anker
ist reserviert, kein Fehler.

**Präzisierung zu `_0`:** Frühere Fassungen sagten „Wissen, kein Code". Das war
ungenau — das aggregierende `default.nix` mit den Options-Deklarationen *ist*
Code. Die scharfe Regel lautet: **`_0` hält Wissen und Struktur, niemals
Dienste.** Kein Programm, kein Daemon, keine systemd-Unit entsteht aus `_0`.
Options-API, Registry, Doku: ja. `services.*`: nein.

---

## 3. Die freie Mitte — `_3` bis `_8`

Sechs Slots gehören der Domäne selbst, in logischer Reihenfolge. Hier gibt es
**keine** projektübergreifende Bedeutung: `_5` heißt im System-Root „Medien", in
mediNix „Wiedergabe", anderswo etwas Drittes. Das ist der Ort für das, was ein
Projekt einzigartig macht. Unbelegte Mitte-Slots sind Reserve — sie werden nicht
aufgefüllt, um Lücken zu vermeiden; die Lücke *ist* die Information „hier ist
Platz".

---

## 4. Ableitungen — was aus der Nummer folgt

Die Nummer ist die einzige Wahrheit. Alles Weitere wird aus ihr abgeleitet, und
**alle Größen tragen die Projektziffer vorne** — man liest eine Zahl und weiß
sofort das Projekt.

**Ableitungsquelle ist ausschließlich die dreistellige Dienstnummer**
(Projekt · Dekade · Dienst). Zweistellige Root-Slots und vierstellige
Ebene-3-Nummern leiten **nichts** ab — sie nummerieren Struktur, keine Dienste.
Ohne diese Regel kollidierten Ebene-3-Ableitungen (`5510 × 10 = 55100`) mit
Ephemeral-Port-Bereichen und sprengten das UID-Band.

| Größe | Regel | `sonarr` (532) | Band |
|---|---|---|---|
| **Port** | Nummer × 10 | `5320` | `Hxx0` |
| **UID** | Nummer × 10 | `5320` | `Hxx0` |
| **GID** | Projekt × 1000 | `5000` | `H000` |

„Rest" = die zwei Ziffern nach der Projektziffer (Dekade + Dienst): aus `532`
wird `32`. Alles an mediNix ist ein 5-er — Gruppe `5000`, Benutzer `5xx0` (identisch zum Port), Ports
`5xx0`. Bei devNIX `8000` / `8xx0` / `8xx0`.

in `5000`, damit Jellyfin Sonarrs Dateien liest), die UID *einzeln* (`5110`,
`5320`, …) für Prozess-Isolation. Dieselbe führende Ziffer, aber **nie dieselbe
Zahl** — eine eigene GID pro Dienst wäre der Docker-PUID/PGID-Fehler
(`Permission denied`).

**Drei Transformationen, weil jeder Zielraum eigene Grenzen hat:**

- **Port** (`× 10`): jedes Projekt landet in seinem eigenen Tausender-Band,
  nie privilegiert (Beweis: Abschnitt 5).
- **UID** (`× 10`): **UID und Port sind identisch.** Das sorgt für maximale 
  Einfachheit und Isomorphie (Ordnernummer == UID == Port). Das Band `H110`–`H990`
  liegt sicher zwischen System-IDs (<1000) und DynamicUsers (61184+). Die Registry 
  **reserviert** das Band pro Projekt und erklärt es per Assertion zur Invariante,
  damit nie ein menschliches Konto hineinzählt.
- **GID** (`× 1000`): projektweit geteilt, oberhalb aller statischen
  NixOS-System-GIDs (< 1000).

Isomorphie heißt **nicht** „alle Zahlen gleich", sondern: *alles aus der einen
Nummer, jede Größe passend transformiert, alle mit derselben führenden Ziffer.*
Das ist **sinnvolle Isomorphie** (ADR-5042).

---

## 5. Die Strukturbeweise — der Rahmen schützt sich selbst

Zwei Garantien folgen nicht aus Vorsicht, sondern aus den Regeln selbst.

### 5.1 GID und UID kollidieren nie

Die GID ist `H000`. Kann ein Benutzer je die `H000` bekommen? **Strukturell
nein.** `H000` hieße „Rest = `00`" (im alten Schema) bzw. Nummer `H00` (im neuen). 
Und `H00` ist die Block-ID des Projekts, nach Abschnitt 2 **niemals ein
Programm**. Zusätzlich hält die gesamte `_0`-Dekade (`H00`–`H09`) keine Dienste.
Kein Dienst wohnt je auf `H0X`, also bekommt kein Benutzer je eine UID unter
`H110`. Die `H000` bleibt der Gruppe **exklusiv — garantiert durch die
struktur, nicht durch Disziplin.**

### 5.2 Kein abgeleiteter Port ist je privilegiert

Die kleinste mögliche Dienstnummer eines Projekts `H` ist `H11` — denn die
`_0`-Dekade hält keine Dienste (kleinste Dekade: 1) und `N0` ist nie ein Dienst
(kleinster Dienst: 1). Kleinster Port also `H110`. Für jedes Projekt `H ≥ 1`
gilt `H110 ≥ 1110 > 1023` — nie privilegiert. Und `H = 0`? Der Namensraum 0
ist das Fundament des Ganzen (Abschnitt 8) — Wissen, keine Dienste, keine
Ports. **Dieselben zwei Regeln, die die GID schützen, halten auch jeden Port
aus dem privilegierten Bereich.** Obergrenze: größte Dienstnummer `999` →
Port `9990 < 65535`; Kollision mit dem Linux-Ephemeral-Band (default ab 32768)
ist ausgeschlossen, weil dreistellige Quellen maximal `9990` erzeugen.

### 5.3 Unix-Sockets — Regel reserviert

Falls je gebraucht: `/run/{projekt}/{nummer}.sock`. Derzeit unterstützt kein
Dienst HTTP-über-Unix-Socket (auf q958 geprüft: die *arr binden nur TCP). Die
Regel steht bereit, wird aber nicht angewandt.

---

## 6. Das System-Root folgt dem Rahmen bereits

Nix-Grok hat das Muster gebaut, bevor es benannt war:

```
00-core          _0  Fundament     ✓ Anker
10-network       _1  Zugang        ✓ Anker
20-security      _2  Sicherheit    ✓ Anker
30-storage       ┐
40-observability │
50-media  → 50-mediNix   _3–_8  Domänen (frei)
60-apps          │
70-home-automation
80-agents → devNIX ┘
90-policy        _9  Leitplanken   ✓ Anker
```

Vier Anker, sechs Domänen. Der Rahmen ist keine Erfindung, sondern die schon
vorhandene Ordnung — nur explizit gemacht.

---

## 7. Beispiel: ein Dokumenten-Projekt (`_4`)

Zur Veranschaulichung, **nicht** als Bauauftrag:

```
40-documents/  → (graduiert zu einem Repo, 4xx)   GID 4000
  400  Fundament    CLAUDE.md, registry, docs      womit arbeiten wir
  410  Zugang       Reverse-Proxy, SSO             wie kommt man rein
  420  Sicherheit   Zugriffsschutz                 wie geschützt
  430  Erfassung    paperless-ngx                  was rein
  440  Ablage       nextcloud, opencloud           wo liegt es
  490  Leitplanken  Assertions                     was einhalten
```

Wer mediNix kennt, liest das ohne Anleitung.

---

## 8. Warum diese Verfassung die 0000 trägt (vormals 8000)

Die frühere Nummer `8000` war ein Namensraum-Fehler, den die Verfassung selbst
aufdeckt: `8` ist devNIX. `8000` ist damit devNIX' eigener `_0`-Slot — die
Block-ID *eines* Projekts. Ein Dokument, das **alle** Projekte regiert, darf
nicht im Fundament-Slot eines einzelnen wohnen; sonst kollidiert es mit devNIX'
eigenem Fundament und widerspricht seiner eigenen Slot-Semantik.

Die reine Nummer ist **`0000`**: die Block-ID der Wurzel. Namensraum `0` ist
auf jeder Ebene das Fundament — und `N00` ist nie ein Programm, immer Wissen.
Die Verfassung besetzt damit exakt den Slot, den ihre eigenen Regeln für genau
diese Art Inhalt reservieren, an der Spitze des Baums. **Sie instanziiert sich
selbst.** Nebeneffekt: der Port-Beweis in 5.2 („H = 0 leitet nie ab") bekommt
seinen Bewohner.

*Migration:* Referenzen auf „ADR-8000" in `AGENTS.md`, `CLAUDE.md`, READMEs und
im Skill auf `0000` umstellen; eine Weiterleitungsnotiz unter der alten Nummer
belassen (`superseded by 0000`), gemäß der eigenen Regel „nie löschen".

---

## 9. Abgelehnt

| Vorschlag | Grund |
|---|---|
| **Drei Anker** (Sicherheit als Domäne) | Sicherheit kehrt in jedem Projekt wieder → fester Slot wie Fundament/Zugang |
| **Sicherheit auf `_1`** | `_1` ist überall „Zugang"; bräche die Isomorphie |
| **`_9` = Sicherheit statt Leitplanken** | `20-security` (Mechanik) und `90-policy` (Assertions) sind zwei Dinge; `_2` Mechanik, `_9` Verfassung |
| **UID = 1000 + Nummer** (`1532`) | Führte mit `1` statt der Projektziffer; bräche „Projektziffer vorne" |
| **GID pro Dienst** (isomorph) | Zerstört den gemeinsamen Bibliothekszugriff — `Permission denied` |
| **Verschachtelte Ordner** `510/511-x.nix` | Bricht den flachen Auto-Import und zerlegt funktionierende Fabriken |
| **`_0` mit Dienst-Code füllen** | `_0` ist Wissen und Struktur; Dienste in die Mitte |
| **Anker auf der Blatt-Stelle** („531 = Zugang der Beschaffung") | Blatt-Stellen kennen nur Block-ID und Dienste (Abschnitt 1); Anker gelten auf Container-Stellen |
| **Ableitungen aus 2- oder 4-stelligen Nummern** | Nur die dreistellige Dienstnummer leitet ab; sonst Port-/UID-Band-Kollisionen (Abschnitt 4) |
| **Verfassung als 8000** | devNIX' Fundament-Slot; Namensraum-Kollision — jetzt 0000 (Abschnitt 8) |

---

## 10. Konsequenzen

- **Wiedererkennung ohne Nachschlagen** — `_2` ist Sicherheit, `5xxx` ist mediNix, überall.
- **Neue Projekte starten mit Skelett** — vier Anker vorgegeben, nur die Mitte füllen.
- **Wissen ist übertragbar** — eine Grammatik über alle Repos.
- **Garantien statt Disziplin** — GID-Exklusivität und unprivilegierte Ports
  folgen aus der Struktur (Abschnitt 5), nicht aus Sorgfalt.
- **Preis:** bestehende Projekte, die den Rahmen annehmen, müssen umnummerieren
  (mediNix: ADR-5043). In der Entwicklungsphase billig, später teuer.

---

## 11. Herkunft und Versionsgeschichte

Aus einer Brainstorm-Reihe des Repo-Eigentümers (Juli 2026), Slot für Slot gegen
die Wirklichkeit auf q958 geprüft. Meilensteine: der Vier-Anker-Schluss (als
`20-security` und `90-policy` sich als zwei Dinge erwiesen), die GID-Regel
`Projekt × 1000`, und der Kollisionsbeweis über die `N00`-Regel — alle drei vom
Eigentümer, hier verifiziert und begründet.

Konsolidiert am 2026-07-22 aus vier Vorfassungen; deren Widersprüche sind
aufgelöst (Protokoll: `KONSOLIDIERUNG.md`):

| Vorfassung | Status | Auflösung |
|---|---|---|
| `8000-dezimalrahmen.md` (ohne Ableitungen) | superseded | vollständig hierin aufgegangen |
| `8000-clean.md` (mit Ableitungen) | superseded | Basis dieser Fassung; Präzisierungen §1/§2/§4/§5/§8 |
| `ableitungen.md` (UID = 1000 + Nummer) | **verworfen** | UID-Formel widersprach „Projektziffer vorne" — siehe Abgelehnt |
| `ableitungen2.md` (UID = Projekt × 1000 + Rest) | superseded | in §4/§5 aufgegangen |
