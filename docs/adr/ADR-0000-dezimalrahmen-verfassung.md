---
id: "0000"
title: "Dezimalrahmen — die Verfassung des Nummernschemas"
domain: 00
status: active
complexity: 2
last_reviewed: 2026-09-23
tags:
  - verfassung
  - dezimalrahmen
  - numbering
links:
  adr: ADR-5043
---

> # ⚠ VERFASSUNG — dieses Dokument darf nicht verlorengehen
> **Es regiert das Nummernschema jedes Projekts in diesem Kosmos** — Nix-Grok,
> mediNix, devNIX und alles Künftige. Die **Regeln** erzwingt
> `decimalFrameworkCheck` im Flake zur Build-Zeit; dieses Dokument trägt die
> Begründung. Textänderungen sind Korrekturen, kein Verlust — jede Fassung
> bleibt in der Git-Historie und im `CHANGELOG.md` abrufbar.
>
> **Verankert in:** `AGENTS.md` (mediNix), `CLAUDE.md` + `README` (devNIX),
> Skill `/devnix-agent:struktur`.

# ADR-0000 — Der Dezimalrahmen

Ein Nummernschema, das auf **jeder Ebene dasselbe bedeutet** — vom System-Root
bis in einen einzelnen Modulordner. Es ist die einzige Entscheidung, die
**projektübergreifend** gilt: alle anderen ADRs regeln *ein* Projekt, diese die
Grammatik *aller*. Wer sie kennt, findet sich in jedem Repo zurecht, ohne es
gelesen zu haben. **Eine Sprache, überall.**

> **Begriffsabgrenzung.** „Anker" meint in diesem Dokument die vier
> **Slot-Anker** (`_0/_1/_2/_9`). Davon zu unterscheiden sind **Semantic
> Anchors** — etablierte Methodik-Begriffe (SSOT, Design by Contract, MECE …),
> mit denen ADRs und Agenten sich präzise verständigen (Abschnitt 11).

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

Wir teilen die GID projektweit (in `5000`, damit Jellyfin Sonarrs Dateien liest), die UID *einzeln* (`5110`,
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

### Invarianten (erzwungen, nicht nur beschrieben)

Zwei Regeln sind **hart**. Sie stehen hier nicht als Konvention, sondern werden
von `decimalFrameworkCheck` (`flake.nix`) zur Build-Zeit geprüft:

- **I1 — Dienste sind immer dreistellig** (Projekt · Dekade · Dienst). Zwei- und
  vierstellige Nummern nummerieren Struktur und leiten **nichts** ab. Ohne I1
  bräche der Obergrenzen-Beweis in 5.2, weil vierstellige Quellen `99900`
  erzeugen könnten.
- **I2 — Projektziffer ist ausschließlich die erste Ziffer** (mediNix = `5`,
  devNIX = `8`). Der Ordnername `50-media` trägt Projektziffer `5` + Block `0`;
  für die GID zählt nur die `5` → `5000`, nicht `50000`.

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
Struktur, nicht durch Disziplin.**

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

## 8. Warum diese Verfassung die 0000 trägt

Die reine Nummer ist **`0000`** — die Block-ID der Wurzel. Namensraum `0` ist
auf jeder Ebene das Fundament, und `N00` ist nie ein Programm, immer Wissen.
Die Verfassung besetzt damit den Slot, den ihre eigenen Regeln für diese Art
Inhalt reservieren, an der Spitze des Baums.

Die Migration von der früheren `8000` (einem Namensraum-Fehler) sowie sämtliche
Vorfassungen sind in `CHANGELOG.md` archiviert (Abschnitt „Doku-Sanierung:
ADR-0000").

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

## 11. Semantic Anchors — die etablierten Begriffe hinter dem Rahmen

Dieses Dokument ist kein Sonderfall: Es setzt bekannte Methodik um. Wer die
Namen kennt, versteht es ohne Anleitung — im Team wie im Modell. Die Anchor-Namen
verdichten die Absicht; sie sind Vokabular, keine Pflicht (proportional anwenden).

| Prinzip im Dokument | Semantic Anchor |
|---|---|
| „Die Nummer ist die einzige Wahrheit" (Abschnitt 4) | **SSOT** — Single Source of Truth |
| I1/I2, `decimalFrameworkCheck` (Abschnitt 4) | **Design by Contract** — Invarianten |
| Vier Slot-Anker + freie Mitte, keine Lücken (Abschnitt 2/3) | **MECE** — überschneidungsfrei, vollständig |
| Container-Stelle vs. Blatt-Stelle (Abschnitt 1) | **Separation of Concerns** |
| „Eine Sprache, überall" (Einleitung, Abschnitt 10) | **Ubiquitous Language** (DDD) |
| „Wiedererkennung ohne Nachschlagen" (Abschnitt 10) | **ISO/IEC 25010** — Verständlichkeit/Maintainability |
| „Abgelehnt"-Tabelle (Abschnitt 9) | **Pugh-Matrix** / Decisional Balance Sheet |
| Dieses Dokument selbst | **ADR (Nygard)** / **MADR** |


---

## 12. Anhang — Anchor-Schicht (Stufe 2 & 3)

> Diese Anhänge sind **projektweit** — sie gelten für das ganze Repo, nicht nur für
> diese Verfassung. Falls sie später ausgelagert werden, bieten sich an:
> `docs/arch/` (A1–A3, A5), `docs/MIGRATION.md` (B1), `CONTRIBUTING.md` (B2),
> `docs/WORKBENCH.md` (B3), `docs/ONBOARDING.md` (B4).
>
> Vokabular-Grundlage: **Semantic Anchors** — siehe Abschnitt 11.

---

### A1. arc42 + C4 — Architektur-Doku benannt

Die Architektur-Doku existiert (`docs/arch/`, `docs/architecture.md`) — sie ist
nur nicht auf die etablierte Kapitelstruktur gemappt. **arc42** macht sie
anschlussfähig; **C4** gibt den Diagrammen eine feste Abstraktionsebene.

| arc42-Kapitel | Vorhandenes Dokument |
|---|---|
| 1. Einführung & Ziele | `docs/README.md`, `50-core/MANIFEST.md`, `docs/arch/ARCH-50-architecture-principles.md` |
| 2. Randbedingungen | `AGENTS.md`, `docs/NO-CONTAINERS.md` |
| 3. Kontext & Abgrenzung | `docs/arch/ARCH-50-architecture-blueprint.md`, `ARCH-50-service-manifest.md` |
| 4. Lösungsstrategie | `docs/arch/ARCH-50-master-index.md`, `ARCH-50-architecture-principles.md` |
| 5. Bausteinsicht | `docs/arch/ARCH-50-base-configuration.md`, Domänen `51`–`59` |
| 6. Laufzeitsicht | `docs/arch/ARCH-50-3-stage-boot-pipeline.md` |
| 7. Verteilungssicht | Service-Map in `docs/README.md`, `ARCH-50-master-sources.md` |
| 8. Querschnittskonzepte | `docs/concepts/*`, `ARCH-50-nixhome-layer.md` |
| 9. Architekturentscheidungen | `docs/adr/` (ADR-0000 … ADR-577) |
| 10. Qualitätsanforderungen | `docs/arch/ARCH-58-sre-quality.md`, `docs/guides/GUIDE-58-seven-quality-gates.md` |
| 11. Risiken & Technische Schulden | `docs/arch/ARCH-57-impermanence-storage.md`, `ROADMAP.md`, „Phase 2"-Roadmap |
| 12. Glossar | `docs/INDEX.md`, `docs/repository.yaml` |

**C4 (Diagramme, `C4-PlantUML`-Stdlib, nicht Mermaid):**
- **Context:** Host (q958) · WAN/Cloudflare · Client — plus `_1`/`_2`-Ingress-Grenze.
- **Container:** NixOS-Host · systemd-Services · Caddy-Ingress · `systemd-creds`.
- **Component:** `lib/service-factory.nix`, `lib/registry.nix`, `51-ingress`, `59-guardrails`.
- **Code:** nur wo nötig (z. B. die Assertion-Kette in `591-cross-domain.nix`).


---

### A2. ISO/IEC 25010 + Quality Attribute Scenarios — Qualität messbar

`ARCH-58-sre-quality.md` und `GUIDE-58-seven-quality-gates.md` beschreiben
Qualität bereits. **ISO/IEC 25010** gibt ihr die Standard-Achsen, **Quality
Attribute Scenarios** machen sie prüfbar (Zielwert statt Adjektiv).

**Achsen-Zuordnung (Auszug):**

| ISO/IEC 25010 | mediNix-Versprechen | Belegstelle |
|---|---|---|
| Wartbarkeit / Verständlichkeit | „Wiedererkennung ohne Nachschlagen" | ADR-0000 §10 |
| Zuverlässigkeit / Fehlertoleranz | „fail-closed", `config.assertions` | `AGENTS.md`, `59-guardrails` |
| Wartbarkeit / Modularität | „dendritic modules", drop-a-file | `GUIDE-50-dendritic-modularization.md` |
| Sicherheit | Tri-State-Grenze, kein `mkForce` | `docs/NO-CONTAINERS.md`, ADR-0000 |
| Portabilität | keine Hardcoded-IPs/Hostnamen | `AGENTS.md` (K.O.-Kriterium) |
| Betriebs-/Übertragbarkeit | zero containers, systemd-native | `docs/NO-CONTAINERS.md` |

**Quality Attribute Scenarios (6-teilig: Quelle · Reiz · Artefakt · Umgebung · Reaktion · Maß):**

- **QAS-1 (Wartbarkeit):** *Neuer Agent* liest `docs/INDEX.md` → findet für einen
  Service die kanonische Seite → **in ≤ 2 Hops, ohne Chat-Historie**. Beleg: `llm-index.json`.
- **QAS-2 (Zuverlässigkeit):** *Host-Admin* setzt einen `mkForce`-Override → Build
  bricht ab → **0 ungeschützte Konfigurationen werden ausgeliefert**. Beleg: `config.assertions`.
- **QAS-3 (Sicherheit):** *Angreifer* erreicht einen internen Port von außen →
  Verbindung wird geblockt → **0 interne Dienste aus dem WAN erreichbar**. Beleg: `52-security`, `51-ingress`.
- **QAS-4 (Portabilität):** *Anderer Host* übernimmt das Modul-Set → Deployment
  läuft ohne Quellcode-Änderung → **0 hardcoded IPs/Hostnamen im Modulbaum**.


---

### A3. STRIDE — Bedrohungsmodell für den `_2`-Slot

Der `_2`-Slot (Sicherheit) hat Module (`520`, `521`, `525`, `526`) und einen
BSI-Audit (`docs/compliance/bsi-it-grundschutz-audit.md`), aber **kein
STRIDE-Modell**. STRIDE gibt jedem Element feste Bedrohungs-Klassen; jede
Mitigation referenziert eine Threat-ID.

| Element | STRIDE | Beispiel-Threat | Mitigation (Beleg) |
|---|---|---|---|
| Caddy-Ingress (511) | **S**poofing | fremder Host-Header | forward-auth erzwingen (ADR-511-caddy) |
| Pocket-ID (512) | **S**poofing | OIDC-Token-Fälschung | Signaturprüfung, `512-pocket-id` (ADR-512) |
| Pocket-ID (512) | **I**nfo-Disclosure | Metadaten-Leak | LINDDUN-Prüfung (s. u.) |
| Cloudflare-DNS (513) | **T**ampering | DNS-Antwort manipuliert | DNSSEC/TLS, ADR-513-cloudflare-dns |
| VPN-Killswitch (526) | **I**nfo-Disclosure | DNS-Leak / IP-Leak | Fail-closed Killswitch, ADR-526 |
| `systemd-creds` (521) | **I**nfo-Disclosure | Klartext im Store | INV-SECRET: kein `/nix/store/`-Präfix (ADR-521) |
| Landingpage (518) | **R**epudiation | Honeypot ohne Log | Audit-Logging, ADR-518 |
| ganze Fläche | **D**enial of Service | Boot ohne Netz | `584-post-boot-watchdog`, `583-runtime-guard` |
| alle Module | **E**levation of Privilege | Rechte-Eskalation | Jailed Services (ADR-52-privesc-audit-hardening) |

**LINDDUN (Privacy, für Pocket-ID/Identity):** Linking · Identifying ·
Non-repudiation · Detecting · Data disclosure · Unawareness · Non-compliance —
je Punkt prüfen, ob Pocket-ID nur die nötigen Claims speichert.

**Format:** Threats erhalten IDs (`T-001…`), Mitigations referenzieren sie
(Standard-Muster, siehe Semantic-Anchors-Contract „Crosscutting Concepts").


---

### A4. Design by Contract + Fitness Functions — die Guardrails

Die `59X`-Assertions sind **Fitness Functions**: ausführbare Architektur-Regeln,
die den Build brechen. **Design by Contract** liefert das Vokabular
(Vorbedingung · Invariante · Nachbedingung).

- **Invarianten (Build-Zeit):** `config.assertions` in `591-cross-domain.nix`
  = die harten Verträge (GID-Exklusivität, unprivilegierte Ports, INV-SECRET).
- **Vorbedingungen:** Option-Schemata (`default.nix`) — was ein Aufrufer liefern muss.
- **Nachbedingungen:** `flake.nix`-Checks + `tests/smoke-test.nix` — was nach dem Build gilt.

**Property-Based Testing (Lücke):** Die Kern-Invarianten lassen sich als
*Properties* über den ganzen Nummernraum prüfen, nicht nur an einem Beispiel:

- *Für jede Dienstnummer `n` (100 ≤ n ≤ 999):* `port(n) == n*10` **und**
  `uid(n) == port(n)` **und** `port(n) > 1023` **und** `port(n) < 65535`.
- *Für alle Paare `(a,b)`, `a≠b`:* `uid(a) ≠ uid(b)` (Prozess-Isolation).
- *Für alle `n`:* `gid(n) == 5000` (projektweit geteilt, nie pro Dienst).

Heute prüft `tests/smoke-test.nix` die Port-Isomorphie an einem Fall — ein
Generator über `100..999` deckt den ganzen Raum ab (und fängt `9990 < 65535`).


---

### A5. Diátaxis — Doku-Typen trennen

`docs/` mischt heute Typen (guides · learn · concepts · patterns · arch · examples).
**Diátaxis** trennt vier Zwecke sauber; **arc42** bleibt für Architektur.

| Diátaxis-Typ | Frage | mediNix-Ordner |
|---|---|---|
| **Tutorial** | „Bring mich rein" | `docs/learn/` |
| **How-to** | „Löse mein Problem" | `docs/guides/` |
| **Reference** | „Was ist Fakt" | `docs/patterns/`, `docs/adr/`, `docs/repository.yaml` |
| **Explanation** | „Warum so" | `docs/concepts/`, `docs/arch/` |

Regel: **arc42 = Architektur** (Kapitel, §1) · **Diátaxis = Nutzer/Doku**
(Ordner). `docs/architecture.md` sollte ein Zeiger auf die arc42-Karte sein, kein
zweiter Baum.


---

### A6. Offene Entscheidungen — Architektur & Sicherheit

1. **Sprache:** `docs/adr/README.md` sagt „English only from here". Diese
   Stufe-2-Texte sind deutsch (wie ADR-0000). Für `52-security/` und `docs/arch/`
   auf Englisch umstellen?
2. **Diagramme:** C4 als PlantUML einchecken (rendert `mkdocs`?) oder nur verlinken?
3. **Property-Test:** Nix-Evaluierung (langsam) oder `lib/registry.nix` → JSON → Python-Check?

---

### B1. Migrations-Anchors — die Umnummerierung

Die Migration auf den Dezimalrahmen **läuft bereits** (git zeigt die Renames
`ADR-00-…-en → ADR-0000-…`, `ADR-51-… → ADR-513-…`, `ADR-57-… → ADR-571-…`).
Genau dafür gibt es etablierte Verfahren — sie machen aus „wir benennen um" einen
beherrschbaren Prozess.

| Migrations-Schritt | Anchor | Konkret |
|---|---|---|
| Alt → Neu inkrementell ersetzen, nie Big-Bang | **Strangler Fig** | Alte Nummern bleiben referenzierbar, bis nichts mehr auf sie zeigt |
| Erst Vorbedingungen, dann Umbenennen | **Mikado Method** | Versuch die Umbenennung → was bricht (`llm-index.json`, `INDEX.md`, Querverweise) → revert → Vorbedingung zuerst. Build nie rot stehen lassen |
| Erst EIN vollständiger Durchlauf | **Walking Skeleton** | Ein ADR komplett umbenannt (inkl. Index + Querverweise), dann skalieren |
| Domäne für Domäne | **Thin Vertical Slice** | `51-ingress` (510er) grün, dann `52-security` (520er) … nie alles gleichzeitig |
| Offene Design-Frage klären | **Spike Solution** | z. B. 4-stellige Ebene-3-Nummern: Timebox-Experiment, Code wegwerfen |
| Übergabe mitten in der Migration | **Hemingway Bridge** | „Was fertig, was offen, was als Nächstes" — als Note, nicht im Kopf |

**Regel:** Jeder Slice endet grün (`nix flake check` + `docs-index.yml`), bevor der
nächste beginnt. Das ist die Migrations-Fassung von fail-closed.


---

### B2. Prozess-Anchors

| Regel | Anchor | Ist-Stand im Repo |
|---|---|---|
| Commit-Format | **Conventional Commits** | teils gelebt (`fix(flake):`, `docs(compliance):`) — Lücken: `WCR-003:`, `Architecture:` |
| Branch → PR → grüner main | **GitHub Flow** | CI existiert (`.github/workflows/flake-check.yml`, `docs-index.yml`); Regel fehlt schriftlich |
| Wann ist „fertig" | **Definition of Done** | `AGENTS.md` §Verification (5 Schritte) + `docs/review-checklist.md` (`[A]`/`[T]`/`[M]`) |
| Versionierung | **SemVer** | Manifest „v2.0", Workbench-Baseline `1.1 → 1.2` — Schema nicht festgeschrieben |

**Definition of Done = die `[A]/[T]/[M]`-Taxonomie.** `review-checklist.md` trennt
schon *Eval-Assertion* (`[A]`), *Automatisierter Test* (`[T]`), *Menschliches
Urteil* (`[M]`) — das ist eine DoD mit Fitness-Function-Charakter. Regel:
`[A]`/`[T]` gehören in den Build, nicht in eine manuelle Liste.

**Conventional-Commits-Lücke schließen:** `CONTRIBUTING.md` fehlt komplett (Recon).
Ein kurzes Dokument + ein commit-msg-Gate macht den Stil erzwingbar statt zufällig.


---

### B3. Text-Anchors

| Zweck | Anchor | Wo |
|---|---|---|
| Jeder ADR beginnt mit der Kernaussage | **BLUF** | ADR-0000 macht es schon (der Callout oben) — Regel festschreiben |
| Konklusion zuerst, dann Stützen | **Pyramid Principle** (Minto) | ADR-0000 §5 (Beweise) ist pyramidal aufgebaut |
| Deutsche Texte | **Gutes Deutsch nach Wolf Schneider** | ADR-0000, `README.md`, `CHANGELOG.md` |
| Englische Texte | **Plain English (Strunk & White)** | `AGENTS.md`, `docs/adr/README.md` |
| Maschinen-/Fehlertexte | **Simplified Technical English (ASD-STE100)** | die Assertion-Messages aus ADR-5043 (`What/Why/Fix`, ein Satz, imperativ) |
| CHANGELOG-Einträge | **Inverted Pyramid** | wichtigstes zuerst |

**Kern-Verbindung:** ADR-5043 schreibt für jede Assertion `What / Why / Fix` vor —
das *ist* Simplified Technical English, nur unbenannt. Wer den Namen kennt, hält
den Standard leichter ein (und er ist für Konsumenten sofort verständlich).


---

### B4. Wissens-Anchors

| Prinzip | Anchor | Beleg im Repo |
|---|---|---|
| Die Verfassung ist die „Theorie" des Systems | **Mental Model (Naur)** | ADR-0000 selbst; ADR-5043 „Every Bug = Invariant" = Theorie-Pflege |
| Wissen schrittweise ausliefern | **Progressive Disclosure** | `INDEX.md` → `llm-index.json` → per-Folder `AGENTS.md` → Skill |
| Doku nach Zweck trennen | **Diátaxis** | siehe Stufe 2 §5 |
| Übergabe mitten in Arbeit | **Hemingway Bridge** | Workbench-Baselines (`WCR-001`, `WCR-003`) sind genau das |

**Naur ist der stärkste Treffer.** „Programming as Theory Building": Das Programm
ist nicht der Code, sondern die Theorie, die das Team trägt. Die mediNix-Verfassung
ist diese Theorie — explizit gemacht. ADR-5043 §5 („Every Bug = Invariant") ist
der Mechanismus, der die Theorie gegen Verlust schützt. Damit erklärt sich, warum
die Verfassung „nicht verlorengehen darf": ihr Verlust = Verlust des Systems.


---

### B5. Offene Entscheidungen — Arbeitsweise

1. **`CONTRIBUTING.md` anlegen?** (Recon: fehlt komplett) — oder in `AGENTS.md` integrieren?
2. **Commit-Gate:** commit-msg-Hook (lokal) oder CI-Check (`.github/`) — oder beides?
3. **Sprache der Prozess-Doku:** EN (wie `AGENTS.md`/`docs/adr/README.md`) oder DE (wie `CHANGELOG.md`/ADR-0000)?
4. **SemVer-Geltungsbereich:** Modul-Set, Verfassung und Workbench-Baseline getrennt versionieren — oder ein Schema für alles?
