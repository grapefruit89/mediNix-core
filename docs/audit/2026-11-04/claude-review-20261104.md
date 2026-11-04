---
titel: "Claude-Vollprüfung mediNix-core — ADR-0000, NixOS-Konventionen, Fix-Liste"
datum: 2026-11-04
quelle: "Externes Review (Claude/Opus), vom Repo-Eigner am 2026-11-04 übergeben"
status: archiviert
bezug:
  - todo/backlog/16-claude-review-delta.md
  - docs/adr/ADR-0000-dezimalrahmen-verfassung.md
---

# Claude-Vollprüfung mediNix-core (2026-11-04)

> **Herkunft:** Dieses Dokument ist ein **externes Review**, keine repo-interne
> Analyse. Es wurde vom Repo-Eigner am 2026-11-04 übergeben und hier unverändert
> archiviert. Es ist **kein** Gate und **keine** Norm — Befunde daraus werden erst
> nach Prüfung zu Todos oder Fixes (siehe `todo/backlog/16-claude-review-delta.md`).
>
> **`B:nnn`-Referenzen sind im Repo NICHT auflösbar.** Sie zeigen auf Zeilen des
> Eingabe-Bundles `dezimalrahmen-vollstaendig-20261104.md`, das nicht versioniert
> ist. Wer einen `B:`-Verweis prüfen will, braucht dieses Bundle oder muss den
> Befund gegen die heutige Datei neu messen.
>
> **Abschnitt 5 (§14-Vorschlag) ist der Review-Stand, nicht die gültige Fassung.**
> Committet ist die überarbeitete Fassung aus `edb04f3` (7 Kategorien inkl.
> `Tooling-Einstieg`, 2 Zonen, §14.1–§14.5). §14.6/§14.7 aus diesem Vorschlag
> fehlen noch (Batch 2a).
>
> **Nicht im Bundle und daher vom Reviewer ungeprüft:** `52-security/creds.nix`,
> `51-ingress/ingress-access.nix`, `check_adrs.py`, `check_corridor.py`,
> `.agent-state.json`, `592-environment.nix`.

---

Ich lese gerade den Code im Anhang (50-core, Tests, Packages, Checker-Skripte), um die Lücken gegen die Dateien zu prüfen. Die ADRs habe ich schon durch.

Kurz zum Stand: Ich prüfe jetzt die Checks in `flake.nix` (Slot-0-Test, `mkForce`-Stellen, Frameband-Check) sowie `tests/`, `packages/` und `docs/examples/`. Danach schreibe ich die Antwort.

Zwischenstand: Ich prüfe noch, ob die Credentials-Pfade (ADR-0000 §4.4 gegen `521-creds.nix`) stimmen und wie 551 und 561 die Factory nutzen. Danach schreibe ich die Antwort.

Ich habe alles gelesen und stelle jetzt die Auswertung zusammen.

Vorab: `B:nnn` verweist auf die Zeile in `dezimalrahmen-vollstaendig-20261104.md`. Nicht im Bundle und daher ungeprüft: `52-security/creds.nix`, `51-ingress/ingress-access.nix`, `check_adrs.py`, `check_corridor.py`, `.agent-state.json`, `592-environment.nix`. Die Lückenliste hat 15 nummerierte Einträge; Nr. 15 dupliziert Nr. 10.

Der `nixmeta_check.py`-Bug und die Reihenfolge-Abhängigkeit aus dem Block „Außerhalb der 14" sind für Fix S1 und S2 wichtig.

## 1. Kritische Lücken (max 3, priorisiert)

**K1 — Lücke 12, deutlich größer als gemeldet: `lib/` existiert nicht mehr, aber Normen und Vorlage verweisen darauf.**
Die Vorlage ist ein funktionaler Bruch, der Rest sind Norm-Widersprüche.

| | Datei A (Norm/Vorlage) | Datei B (Ist) |
|---|---|---|
| Vorlage | `docs/examples/5xx-service.example.nix` B:7059 `import ../lib/service-factory.nix`; Kommentartabelle nennt `lib/decimal-framework.nix`, `lib/hardening-profiles.nix` | existiert nur als `50-core/service-factory.nix` |
| Import-Norm | ADR-040 B:952, normatives Beispiel `import ../lib/derive.nix` | Module nutzen `../50-core/derive.nix` (B:9316, B:10459) |
| weitere | ADR-0010 B:857, CONVENTIONS B:8224 (`lib/` „Pflicht: ja"), BANNED B:3507, 50-core/AGENTS.md („Source of truth → lib/derive.nix"), ADR-0000 §1.3/§2 (`lib/decimal-framework.nix`) | – |

Die Blaupause trägt den Titel „Kopiere diese Vorlage für jeden neuen Dienst". Wer sie kopiert, bekommt einen Eval-Fehler.

**K2 — Lücke 11: ADR-5020 gegen BANNED_TECHNOLOGIES.**
- **Datei A:** ADR-5020 B:791 schreibt einen Vector-Store aus `embeddings.npy`, einem bge-Embedding-Modell und `vec-mcp` vor. Der Status ist `active`.
- **Datei B:** BANNED B:3429 verbietet „LLM Vector-DBs / RAG Plugins" ausdrücklich, auch „heavy Python ML dependencies". Ersatz ist `AGENTS.md` plus `grep`. BANNED nennt sich „absolute law, no exceptions".
- **Widerspruch:** Dieselbe Funktion ist gleichzeitig vorgeschrieben und verboten. Agenten bekommen widersprüchliche Anweisungen.
- **Prüfer ist blind:** `check_banned_technologies.py` matcht nur `import chromadb` und `pkgs.faiss`. ADR-5020 schließt Chroma ausdrücklich aus und fällt deshalb nie auf.
- **Folgeschaden:** `502-host-settings.nix` verlinkt B:3061 `links.adr: ADR-5020`, obwohl es dort fachlich um Domain und Host geht.

**K3 — Lücke 9: ADR-5050 gegen `hardening-profiles.nix`. Es ist mehr als eine andere Direktive.**
- **Datei A:** ADR-5050 B:673 nennt `RestrictNetworkInterfaces = ["lo"]` als Baseline für alle Dienste. B:680 behauptet „Factory-enforced" für alle.
- **Datei B:** `hardening-profiles.nix` hat in `base` (B:2252) `RestrictAddressFamilies` und in `networkPolicy.internet` ein `0.0.0.0/0`-Allow.
- **Falsch verallgemeinert:** `RestrictNetworkInterfaces` gibt es real nur in 541, und nur bei VPN-Confinement als `["lo", vpnIf]` (B:9436ff). ADR-5050 macht aus dieser Sonderregel eine Baseline. Als Baseline würde sie jeden LAN-/WAN-Dienst brechen.
- **Falsch bei „Factory":** 541, 551 und 561 komponieren `profiles.*` und `memoryPolicy.*` direkt (B:9532, B:9873, B:10037), ohne Factory.
- **Dangling:** ADR-5410 steht nicht im `llm-index.json`.
- **Warum es zählt:** `591` zitiert ADR-5050 als Autorität in seiner Fehlermeldung. Wer dem ADR folgt, baut falsche Härtung.

**Außerhalb der 14 (beim Prüfen gefunden, teils gewichtiger):**
- **X1, stiller Fail-open in 591.** `enabledOf` (B:10461) liest `cfg.${n}.enable`. Die ntfy-Option liegt aber unter `medinix.observability.ntfy` (B:10311). `config.medinix.ntfy.enable or false` ist damit immer `false`. ntfy fehlt in `enabledPortable` (B:10463), also prüfen Leak-Port- und Wildcard-Bind-Guard ntfy nie. `pocket-id` ist dafür als Sonderfall verdrahtet, ntfy nicht. Verifiziert nur für ntfy; die anderen Registry-Namen laufen über Module außerhalb des Bundles.
- **X2, Gate-Bug mit Reihenfolge-Falle.**
  - **Crash statt Meldung:** `nixmeta_check.py` B:7382 und B:7384 geben `return [..]` statt des 3-Tupels zurück. Ungültiges YAML endet im `ValueError: not enough values to unpack`, nicht in einer Meldung.
  - **Rot-Falle:** `STATUS` (B:7322) kennt weder `example` noch `template`. Wer Lücke 5 oder 6 zuerst fixt, färbt `checks.nixmeta-check` rot.
- **X3, Fallstrick in der Entscheidung „repl.nix → 50-core".**
  - **Pfad bricht:** `builtins.getFlake (toString ./.)` (B:6287) zeigt dann auf `50-core/`.
  - **Dead Helper:** Der Helfer `where` ist schon heute tot. `nixosConfigurations.check` ist in `flake.nix` nur ein `let`-Binding, kein Output (B:6300).
  - **Doku:** CONVENTIONS listet `repl.nix` als Root-Pflichtdatei.
- **X4, Doku-Klarstellung.** `591.factoryViolations` liest `config.users.*` und `systemd.services.*` innerhalb von `assertions`. Das widerspricht ADR-040 §3 und dem Kommentar derselben Datei. Es ist aktuell grün und eine Senke, daher Klarstellung statt Umbau.

## 2. Bewusste Abweichungen

- **L1 (Dateien außerhalb 50–59):** bewusst, §14 löst es. Im Bundle sehe ich 11 solche Dateien. Das Template `arr-settings.nix` (B:49) steht nur in der Liste, die 13. Datei kenne ich nicht. Zusätzlich gibt es in 50–59 unnummerierte Nicht-Modul-Dateien, die Lücke 1 nicht zählt (`derive`, `registry`, `manifest`, `memory-policy`, `hardening-profiles`, `service-factory`, `service-contract`, `ingress-access`, `creds`, `arr-settings`). §14 deckt sie mit ab.
- **L2 (501 im „Daemon-Slot"):** bewusst. §2 selbst ordnet die Engine `_0` zu. 501 ist ein Modul (options plus config, per Glob auto-importiert), keine Library. Der Widerspruch steckt nur im Wortlaut von §1 („HD1–HD9 = services/tasks"), nicht in §2. Die Auslegungsregel steht in §14.6.
- **L4 (`folder: "."`):** konsistent mit der Praxis. Alle Nicht-Modul-Dateien nutzen den repo-relativen Pfad (`"tests"`, `"packages/arr-provision"`, `"docs/examples"`, `"."`). Nur ADR-00 sagt „Ordnername" und gehört nachgeschärft.
- **L13 (tests außerhalb):** bewusst nach §3. Nuance: Nur `smoke-test.nix` ist ein NixOS-Modul. `vm-smoke-test.nix` ist eine Funktion `{ pkgs, inputs }:` auf `runNixOSTest`.
- **L14 (packages):** bewusst. `status: active` ist korrekt, denn `status` beschreibt den Lebenszyklus, nicht die Kategorie. Es fehlt nur `kind`.
- **10 Dienst-Module ohne `sources`:** akzeptable, maschinell erzwungene Schuld (`check_sources.py`, B:7650). Neue Fälle werden rot. Ich würde zuerst 532–536 abbauen, weil sie der Arr-Kern sind.

## 3. Kosmetische Lücken

- **L3:** `default.nix` hat `folder: 50-core` (B:4957) und ein leeres `links:` (B:4963). Richtig ist `folder: "."` plus `links.adr`.
- **L5:** Die 4 Beispiele brauchen `status: example`, aber erst nach dem Checker-Fix X2.
- **L6:** Das Template braucht `status: template`. Checker und ADR-00 kennen den Wert noch nicht.
- **L7:** `registry.nix` braucht `status`, `complexity` und `links.adr`. Das beantwortet deine offene Frage mit Ja. Die generierte Karte zeigt sonst `registry | unknown | -/5` (B:3344), und ADR-00 verlangt Header für „EVERY .nix file". Der Checker ist nicht der Maßstab. Dass der Checker nur `NNN-` prüft, stimmt nur für Ratsche 2. Die Kernfelder prüft er für alle `.nix`-Dateien.
- **L8, Prämisse zu zwei Dritteln falsch.**
  - **501 und `hardening-profiles`:** 501 (B:2857–2859) und `hardening-profiles` (B:2186–2188) haben `links.adr` plus ein top-level `adr:`. Das sind verschiedene Schlüssel, also gültiges YAML, nur redundant.
  - **503 ist der echte Fall:** Es hat einen echten doppelten Schlüssel `links:` (B:3217 und B:3228). PyYAML nimmt stillschweigend den letzten, strikte Parser lehnen ab. Dazu behauptet 503 `systemd_hardened: true` (B:3227) ohne Dienst.
  - **521 ist riskanter:** Es hat widersprüchliche Werte, `adr: ADR-5000` (B:8974) gegen `links.adr: ADR-521` (B:8975).
  - **Gleiches Doppelmuster:** `591`, `541`, `511` und `default.nix`.
- **L10/15 (ADR-5030):** direkter Widerspruch zu ADR-0000 §1 (flacher 2-Ebenen-Baum) und zum Repo (B:742–757). Er ist aber nirgends operativ, nur 503 verlinkt ihn (B:3229). Meine Empfehlung zur offenen Frage: archivieren, nicht umschreiben. Der Inhalt steht schon in ADR-0000 §1, ADR-040, `default.nix` und CONVENTIONS, und ein Umschreiben erzeugt eine Zweitfassung (CONVENTIONS „Zeiger-Regel"). „Archivieren" heißt hier: `status: deprecated` im Front-Matter und im `llm-index.json` setzen und eine „Superseded by"-Zeile ergänzen. Die Datei bleibt liegen, es wird nichts gelöscht oder verschoben.

## 4. NixOS-Konventionen

| # | Klasse | Befund und Empfehlung |
|---|---|---|
| 1 Dreifache Buchführung | **(b)** | Die Nummer lebt einmal: `derive.nix` → Registry, und Module ziehen `num` per `inherit (reg) num` (B:10391ff). Das Manifest ist eine typisierte Projektion, die Optionen sind Nutzerabsicht. ADR-040 und `check_manifest_edge.py` sichern das. Echte Doppelfelder sind `caddyClass` (Registry) gegen `accessGroup` (Manifest) und `hardeningProfile` (Registry) gegen `profile =` im Modul. Der Factory-Header behauptet „profile selected in registry", der Code liest das Feld nicht. Fix: Gleichheits-Assertion in 591 oder das Feld streichen (vorher nach Lesern greppen). |
| 2 service-factory | **(b)** | Standardmuster „Funktion liefert Config-Fragment", im Header dokumentiert. `systemctl cat` zeigt die Unit ohnehin, es geht nur die Herkunft in `nixos-option` verloren. Echte Mängel: Der Nicht-`hardeningOnly`-Zweig wirft bei `stateDir = null` (`removePrefix` auf null), obwohl `null` der Default ist. Dazu ist „ALL via factory" in ADR-5050 falsch. Optional: Unit-Key `X-MediNix-Origin` für die Herkunft. |
| 3 `mutableUsers = mkDefault false` | **(b)** | Überschreibbar und dokumentiert in `security.loginKeys` (B:5664) und im 501-Kommentar. Die nixpkgs-Assertion verhindert einen Lockout. Das ist für deklarative Server üblich, kein Anti-Pattern. Ein Satz in ADR-0003 oder CONVENTIONS genügt (nicht ADR-0000). |
| 4 `DynamicUser` | **(c)** | Die Prämisse ist falsch: `alert-ntfy@` nutzt `DynamicUser = true` (B:10344). cloudflare-ddns hat über die Factory ein festes Konto. Feste Konten sind gewollt (UID=Port=num×10, UPG, `media` nur supplementary, Peer-Isolation per Pfad). Die Begründung steht aber nur als Kommentar in 581 (B:10377). Zusätzlich widerspricht BANNED sich selbst: B:3416 und B:3507 nennen DynamicUser als Ersatz. Dokumentieren: Rationale plus Ausnahmeliste (`alert-ntfy@`, zustandslos). Die BANNED-Zeilen korrigieren und `alert-ntfy@` mit Profil `script` härten. |
| 5 `mkForce`-Reste | **(a)** | BANNED §2 verbietet `mkForce` ausnahmslos (B:3504). Im Modulcode gibt es nur 541 (`IPAddressDeny/Allow = mkForce []`, B:9558f). Die Aufgabe ordnet das fälschlich 511 zu. Die flake.nix-Treffer sind Test-Fixtures. Ursache: `serviceConfig`-Listen werden konkateniert, ein plain `[]` löscht nichts. Fix: eigenes Profil `python-confined` ohne `IPAddress*`. In BANNED „Tests ausgenommen" ergänzen. |
| 6 `StateDirectory` gegen `stateDir` | **(b)** | Die Prämisse ist falsch. Die Factory emittiert `StateDirectory = removePrefix "/var/lib/" stateDir`. `stateDir` ist nur der absolute Nix-Pfad für `ReadWritePaths`, `BindPaths` und tmpfiles. Es ist eine Konvention, kein Handlungsbedarf. |
| 7 `services.sabnzbd` + `medinix.sabnzbd` | **(c)** | Das Wrapper-Muster über ein Upstream-Modul ist idiomatisch. Die Assertions greifen aber nur unter `mkIf cfg.enable`. Ein Host, der `services.sabnzbd.*` selbst setzt, koppelt still. Der H30-Kommentar erklärt `stateDir`, aber der Vertrag fehlt. Dokumentieren: `medinix.<svc>.enable` ist der einzige Schalter, und `services.<svc>.*` gehört mediNix, solange der Dienst aktiv ist. |

## 5. §14 „Datei-Klassifikation" (Vorschlag für ADR-0000)

```markdown
## 14. Datei-Klassifikation

*Quelle: Vollprüfung 2026-11-04. Diese Sektion klassifiziert jede `.nix`-Datei des Repos.
Sie ändert keine Zahlen, Slots oder Invarianten aus §1–§13.*

### 14.1 Grundsatz

Jede `.nix`-Datei gehört **genau einer** von sechs Kategorien. Die Kategorie folgt aus der
**Konsumform** (wer lädt die Datei, und wie), nicht aus ihrem Inhalt. Der Header-Schlüssel
`status` beschreibt den Lebenszyklus und ist orthogonal zur Kategorie (`kind`).

Eine `.nix`-Datei außerhalb 50–59 braucht eine dieser sechs Kategorien und muss in der
zugehörigen Zone liegen (§14.3), sonst ist sie ein Verstoß. Innerhalb 50–59 gilt dasselbe
für alles, was nicht `NNN-*.nix` heißt.

### 14.2 Die sechs Kategorien

**Modul** (`kind: module`)
- Pfad: `5X-*/NNN-*.nix`, Datei-Dekade == Ordner-Dekade. Das schließt `500`, `502`, `503` ein
  (Dekade `_0`, daemonfrei nach I3).
- Pflichtfelder: Basis-8 (§14.4). `kind` ist implizit und darf entfallen.
- Import-Regel: Wird ausschließlich per Auto-Import-Glob von `default.nix` geladen. Kein
  `imports = [ … ]` auf andere Module. Libraries nur explizit per `import ../50-core/<x>.nix { … }`.
  Daemons nur nach I1–I4. Liest nur Quellen (ADR-040).

**Library** (`kind: library`)
- Pfad: `5X-*/<name>.nix` **ohne** `NNN-`-Präfix, bevorzugt `50-core/`. Auch `50-core/repl.nix`
  (Foundation-Tooling).
- Pflichtfelder: Basis-8 + `kind` + `provides`.
- Import-Regel: Nur per `import <pfad> { … }` (bzw. `nix repl --file`), nie in `imports`. Reine
  Funktionen oder Daten, keine top-level `options`/`config`. Ein `NNN-`-Präfix ist verboten, die
  Datei würde sonst als Modul auto-importiert. Abhängigkeiten sind azyklisch.

**Engine** (`kind: engine`)
- Pfad: geschlossene Liste `50-core/501-decimal-engine.nix`, `50-core/service-contract.nix`.
  Erweiterung nur per ADR-Änderung.
- Pflichtfelder: Basis-8 + `kind` + `provides` + `requires`.
- Import-Regel: Modulsignatur. 501 wird per Glob geladen, `service-contract.nix` per
  explizitem Eintrag in `default.nix`. Die Engine leitet Konten und Defaults für alle Dienste ab,
  besitzt aber selbst nie einen Daemon (I3).

**Package** (`kind: package`)
- Pfad: `packages/<name>/*.nix`.
- Pflichtfelder: Basis-8 + `kind` + `provides` (Attribut unter `packages.*`).
- Import-Regel: Nur per `pkgs.callPackage` aus `flake.nix`. Daten wie `registryJson` kommen als
  Argumente, kein `config`, kein Pfadzugriff auf `5X-*`.

**Test** (`kind: test`)
- Pfad: `tests/*.nix`.
- Pflichtfelder: Basis-8 + `kind` + `checks` (konsumierende Flake-Checks).
- Import-Regel: Nur über `checks.*` in `flake.nix`, entweder als NixOS-Modul im Test-`nixosSystem`
  oder als `runNixOSTest`-Funktion. `lib.mkForce` ist in Fixtures erlaubt. Nie von Modulen oder
  `default.nix` importiert.

**Root-Config** (`kind: root-config`)
- Pfad: geschlossene Liste `flake.nix`, `default.nix` (Nix-Constraint). Kein weiteres `.nix` im Root.
- Pflichtfelder: Basis-8 + `kind`, `folder: "."`.
- Import-Regel: `flake.nix` verdrahtet `checks`, `packages` und `devShells`. `default.nix` enthält nur
  Options-Schema und Auto-Import.

### 14.3 Zonen für Beispiele und Vorlagen

`docs/examples/**/*.nix` tragen `status: example`, `docs/agents/**/templates/**/*.nix` tragen
`status: template`. Sie sind modul- oder library-förmig (`kind` nach Signatur), aber nicht Teil
des Modulbaums und werden nie importiert. `example` und `template` sind nur unter `docs/**` zulässig.
Relative Importpfade in Beispielen müssen gegen die Repo-Wurzel auflösbar sein.

### 14.4 Header-Felder

- **Basis-8 (ADR-00):** `id`, `title`, `domain`, `folder`, `status`, `complexity`, `last_reviewed`, `links.adr`.
- **`folder`:** Verzeichnis relativ zur Repo-Wurzel, `.` für die Wurzel. Für `5X-*` ist das der
  Ordnername.
- **`status`:** `active | deprecated | draft | example | template`.
- **`kind`:** Pflicht für jede `.nix`, die nicht implizit Modul ist. Explizit angegeben muss es zur
  Zone passen.
- **`links.adr`:** Das top-level `adr:` entfällt.

### 14.5 Prüfung durch `scripts/nixmeta_check.py` („Ratsche 3")

1. Strikter YAML-Loader: doppelte Schlüssel sind ein Fehler. Fehlerpfade liefern das 3-Tupel.
2. `classify(path)` wertet fest geordnet aus (erster Treffer gewinnt): Root-Liste → Engine-Liste →
   `^5\d-[^/]+/\d{3}-…\.nix$` (Modul) → `^5\d-[^/]+/[^/]+\.nix$` (Library) → `packages/` → `tests/` →
   `docs/examples/` → `docs/agents/**/templates/`. Kein Treffer ergibt „unklassifiziert", ein Verstoß.
3. Ein deklariertes `kind` muss dem klassifizierten entsprechen. Fehlt es, ist das nur beim
   impliziten Modul zulässig.
4. Pflichtfelder je Kategorie. Fehlendes landet im Ratsche-Backlog (`nixmeta-baseline.txt`, darf nur
   schrumpfen). Ratsche 3 gilt zunächst hart für alle Nicht-`NNN-`-Dateien.
5. Konsistenz: `folder == relpath(dirname)` für alle Dateien. `status` aus dem erlaubten Set.
   `example` und `template` sind zonengebunden (`docs/examples` ⇒ `example`).
6. Heuristiken je Kategorie: Library ohne top-level `options`/`config`. Modul ohne `imports =`.
   Package ohne `config.medinix`. Relative `import`-Pfade müssen existieren.
7. Ausgabe: Zählung je Kategorie. `check-nixmap.py` leitet seine Scan-Ordner aus den Zonen ab statt
   aus einer Handliste.

### 14.6 Auslegungsregeln

- §1 „HD1–HD9 = services/tasks" gilt für die Dekaden 1–8. In `_0` bedeutet HD1–HD9 Foundation-Slots
  (Engine, Host-Module), nie Daemons (I3).
- I1 ist projektbezogen: `H00 ≤ num ≤ H99`. Die Beweise in §5 gelten für den Gesamtraum.

### 14.7 Pfad-Konkordanz (`lib/` ist aufgelöst)

`lib/decimal-framework.nix` → `50-core/501-decimal-engine.nix` (Engine) + `50-core/derive.nix` (Formel);
`lib/registry.nix`, `lib/derive.nix`, `lib/service-factory.nix`, `lib/service-contract.nix`,
`lib/hardening-profiles.nix`, `lib/memory-policy.nix` → `50-core/<gleicher Name>`;
`lib/arr-provision/` → `packages/arr-provision/`. Wo §1.3, §2 oder §4 `lib/…` nennen, gilt diese
Konkordanz.
```

## 6. Fix-Liste

Reihenfolge: **S1 vor S2 vor S5/S6**, sonst wird `checks.nixmeta-check` rot.

**S (< 30 min)**
- S1: `nixmeta_check.py` B:7382/7384 → `return [..], [], []`.
- S2: `nixmeta_check.py`: `STATUS += {example, template}` plus Zonenregel (`docs/examples` ⇒ `example`, `templates/` ⇒ `template`); ADR-00 entsprechend ergänzen.
- S3: `docs/examples/5xx-service.example.nix`: `../lib/…` → `../50-core/…` und die Kommentartabelle korrigieren. **Zuerst, funktionaler Bruch.**
- S4: `591` `enabledOf`: ntfy → `observability.ntfy` (wie `pocket-id` als Sonderfall).
- S5: `docs/examples/*.nix` (4 Dateien) → `status: example`; das Template → `status: template`.
- S6: `default.nix` → `folder: "."`, `links.adr` setzen.
- S7: `503`: doppelten `links:` vereinen, `systemd_hardened` auf `false`, `adr` von ADR-5030 weg (ADR-0003 vorschlagen, gegen `check_adrs.py` verifizieren).
- S8: `502`: `links.adr` weg von ADR-5020.
- S9: Redundantes top-level `adr:` entfernen in 501, `hardening-profiles`, `591`, `541`, `511`; bei `521` auf `ADR-521` entscheiden.
- S10: `registry.nix`: `status`, `complexity`, `links.adr` ergänzen.
- S11: ADR-5020 und ADR-5030: `status: deprecated` (Front-Matter und `llm-index.json`) plus „Superseded by". Keine Löschung, kein Verschieben.
- S12: ADR-0010 B:857 → `packages/arr-provision/`.
- S13: `repl.nix`: `toString ./..`, `folder: "50-core"`, `where` reparieren oder streichen, CONVENTIONS-Rootliste anpassen.
- S14: `service-factory`: Null-Guard für `stateDir` im Nicht-`hardeningOnly`-Zweig.
- S15: `check-nixmap.py` B:7973–7981: `56-exposition` und `59-guardrails` ergänzen (derzeit ungescannt).
- S16: BANNED: DynamicUser-Zeilen (B:3416, B:3507), `lib/registry.nix`, `mkForce`-Scope „Tests ausgenommen", `links: ""`.

**M (< 2 h)**
- M1: `nixmeta_check.py` Ratsche 3 (§14.5) mit strikter Duplicate-Key-Prüfung, Fixture-Tests und Baseline.
- M2: ADR-5050 neu fassen: profilbasierte Baseline (`base` + `networkPolicy.*`), `RestrictNetworkInterfaces` als Confined-Regel (nur 541), „via Factory oder direkte Komposition".
- M3: `python-confined`-Profil und 541 darauf umstellen. Damit entfällt `mkForce`. Volle Prüf-Leiter laufen lassen (ADR-040 §4).
- M4: `591`: Assertion, dass jeder Registry-Dienst mit Port auf einen existierenden Options-Pfad auflöst, plus Negativtest.
- M5: Stale-`lib/`-Sweep in ADR-040, 50-core/AGENTS.md (Handteil), CONVENTIONS §4, `check_sources.py`-Docstring. Verifizieren per `grep -rn "lib/"`.
- M6: §14 in ADR-0000 einfügen. CONVENTIONS §4 (Whitelist: `lib/` raus, `packages/`, `tests/`, Libraries in `5X-*` rein).
- M7: Doku zu Konvention 4 und 7 (DynamicUser-Rationale plus Ausnahme, Wrapper-Vertrag) in ADR-0002/0003.
- M8: ADR-040 §3: Klarstellung, dass Senken (`assertions`, `checks`) Ableitungen lesen dürfen; verboten ist nur die Rückwirkung in Quellen.

**L (halber Tag)**
- L1: `hardeningProfile` als Single-Source. Factory, 541, 551 und 561 lesen es aus der Registry. Das schließt Konvention 1 und macht ADR-5050 wahr. Betrifft 532–536, 541, 551–553, 561, 581 und die volle Prüf-Leiter.
