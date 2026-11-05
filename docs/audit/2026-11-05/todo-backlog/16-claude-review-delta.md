# Claude-Review Delta — S/M/L-Fixes gegen Ist-Stand

Stand: 2026-11-04 (Commit `392eb07`)

**M3 und L1 sind geschlossen** (`ffea59e`, `5fc2932`, `392eb07`). Die
verbleibenden `○` sind M4, M5, X4 — M5 ist der 62-Dateien-Sweep (W3-3).

> **Quellenlage:** Das Audit-Dokument selbst liegt **nicht** im Repo (kein
> `docs/audit/2026-11-04/`). Diese Tabelle ist deshalb **ausschließlich aus
> Repo-Messungen** gefüllt, gegen die Kurzbeschreibungen aus der Review-Tabelle.
> Wo die Kurzbeschreibung ohne den Review-Text mehrdeutig ist, steht `⚠ unklar`
> statt einer geratenen Bewertung.

Legende: `✅ erledigt` · `○ offen` · `⚠ teilweise / unklar`

---

## S-Fixes (alle < 30 min)

| # | Fix (Kurzfassung) | Ist-Stand | Beleg (Commit/Datei:Zeile) |
|---|---|---|---|
| S1 | nixmeta_check.py 3-Tupel | ✅ | `scripts/nixmeta_check.py:150` (`return [...], [], []`), Aufrufer `:266`, `:288` entpacken 3 Werte |
| S2 | STATUS += example/template | ✅ | `scripts/nixmeta_check.py:43` → `{"active","deprecated","draft","example","template"}` |
| S3 | 5xx-service.example.nix Import-Pfade | ✅ | `docs/examples/5xx-service.example.nix:106` bleibt bewusst relativ — die Blueprint-Regel steht jetzt in ADR-0000 §14.2 (Commit `d16a03d`): beim Kopieren nach `5X-*/` lösen sich die Pfade gegen den Zielordner auf |
| S4 | 591 `enabledOf` → `observability.ntfy` | ⚠ unklar | `59-guardrails/591-cross-domain.nix:23` liest weiter `config.medinix.manifest.${n}.enable or false`. Absicherung neu über Assertion `:193-195`. Ob das der gemeinte Fix war: ohne Review-Text nicht entscheidbar |
| S5 | 4× `docs/examples/*.nix` status | ✅ | alle vier `docs/examples/{simple,vpn-confinement,mergerfs-tiering,5xx-service.example}.nix:6` → `status: example` |
| S6 | default.nix `folder` + `links.adr` | ✅ | `default.nix:5` (`folder: "."`), `:9-10` (`links.adr: ADR-0000`) |
| S7 | 503 doppeltes `links:` + ADR-0003 | ✅ | `50-core/503-host-integration.nix:22-23` — genau **ein** `links:`-Block, `adr: ADR-0003` (Commit `9b0e75a`) |
| S8 | 502 adr ADR-5020 → ADR-0000 | ✅ | `50-core/502-host-settings.nix:10` `adr: ADR-0000` (Commit `9b0e75a`) |
| S9 | Redundantes `adr:` entfernen | ✅ | `9b0e75a` räumte 4 Dateien, `d16a03d` die restlichen 29. `grep -rl "^# adr:" --include='*.nix' .` → **0** |
| S10 | registry.nix Header | ⚠ unklar | `50-core/registry.nix:1-11` hat `status`, `kind: library`, `complexity`, `links.adr` — aber **kein** `provides:`/`requires:`. „Lifecycle-Felder" (Commit-Text `9b0e75a`) nicht auffindbar |
| S11 | ADR-5020/5030 deprecated | ✅ | `docs/adr/ADR-5020-knowledge-extraction-pipeline.md:5`, `ADR-5030-flake-module-patterns.md:5` → `status: deprecated` (Commit `9627aae`) |
| S12 | ADR-0010 → `packages/arr-provision/` | ✅ | `docs/adr/ADR-0010-*.md:50` nennt `packages/arr-provision/` |
| S13 | repl.nix nach 50-core + where-Helper | ✅ | `50-core/repl.nix` existiert; `:15` `getFlake (toString ./..)`, `:24` `where =` (Commit `5cda609`) |
| S14 | service-factory Null-Guard + Kommentar | ✅ | `50-core/service-factory.nix:68`, `:86`, `:141`, `:170` — vier `stateDir != null`-Guards |
| S15 | check-nixmap.py SCAN_DIRS | ✅ | `scripts/check-nixmap.py:27-38` → `50-core` … `59-guardrails` |
| S16 | BANNED DynamicUser + mkForce + lib | ⚠ teilweise | `50-core/BANNED_TECHNOLOGIES.md:130` DynamicUser-Scope, `:127` mkForce + Test-Ausnahme ✓. **Aber `:39` verweist auf `592-environment.nix` — Datei existiert nicht** (`59-guardrails/` hat nur `591`). Welle 4 |

**S-Bilanz: 13 ✅ · 0 ○ · 3 ⚠**

---

## M-Fixes (alle < 2 h)

| # | Fix (Kurzfassung) | Ist-Stand | Beleg |
|---|---|---|---|
| M1 | nixmeta_check.py Ratsche 3 | ✅ | Commit `25e081c` — `classify()`, `KIND_OF`, Zonen-/Modul-/folder-Regeln |
| M2 | ADR-5050 profilbasiert neu fassen | ✅ | Commit `d16a03d` — `domain: 50`, `links.adr: ADR-5000`, Decision auf `base` + `networkPolicy.*` umgestellt, `RestrictNetworkInterfaces` als 541-Confined-Regel dokumentiert |
| M3 | python-confined Profil, 541 umstellen | ✅ | Commit `ffea59e` — `networkPolicy.confined` + `python-confined`, 541 wählt bedingt, `mkForce` weg. Eval-Beweis: confined ⇒ kein `IPAddress*`, `RestrictNetworkInterfaces = [ "lo" "wg-medinix" ]` |
| M4 | 591 Assertion Options-Pfad-Auflösung | ○ offen | `59-guardrails/591-cross-domain.nix:95-110` prüft `(svcCfgOf n).User` direkt; keine Options-Pfad-Auflösung |
| M5 | Stale-`lib/` Sweep | ✅ | `1b701f2` (36 aktive Ersetzungen) + `85b9a4c`; danach Kopfzeilen-Politik in CHANGELOG/AUDIT-LEDGER/UPGRADE-MATRIX. Historie bleibt als Beleg. Ursprungsbefund: **62 Dateien** (ohne `docs/adr/`, `docs/audit/`, `docs/archive/`, `todo/`, `.agents/`) mit stale `lib/`-Pfaden; davon nur **1** `.nix` (Template `docs/agents/07-patterns-misc/nixos-dotnet-env-config/templates/arr-settings.nix`). Vor `d16a03d` waren es 63 — ADR-0000 ist frei |
| M6 | §14 in ADR-0000 | ✅ | Commit `edb04f3` (7 Kategorien, 2 Zonen, `classify()`-Regeln) + `d16a03d` (§14.6, §14.7) |
| M7 | Doku Konvention 4+7 (DynamicUser, Wrapper) | ⚠ unklar | `docs/CONVENTIONS.md` hat §1–§6 + Zusatzabschnitte, **kein §7**; „Wrapper" kommt nicht vor. Ziel ohne Review-Text nicht bestimmbar |
| M8 | ADR-040 §3 Klarstellung | ⚠ unklar | `docs/adr/ADR-040-*.md` hat keine §3-Nummerierung (`Kontext`/`Entscheidung`/`Konsequenzen`/`Import-Konventionen`); die 4 `lib/`-Referenzen sind auf `50-core/` umgestellt |

**M-Bilanz: 4 ✅ · 2 ○ · 2 ⚠**

---

## L-Fixes

| # | Fix | Ist-Stand | Beleg |
|---|---|---|---|
| L1 | hardeningProfile Single-Source | ✅ | `5fc2932` (Registry-Werte ehrlich: 513 `network`, 582 `base`) + `392eb07` (Fabrik liefert `profiles.${profile}` per `mkDefault`, Registry-Default `registry.${name}.hardeningProfile or "base"`). `service-factory.nix:25` las die Registry schon vorher — die Kante ist alt, nur das Feld wurde ignoriert |

**L-Bilanz: 1 ✅ · 0 ○ · 0 ⚠**

---

## Befunde aus Sektion 1 (Kritische Lücken + Außerhalb)

| # | Befund | Ist-Stand | Beleg |
|---|---|---|---|
| K1 | Lücke 12 (`lib/` in Normen) | ✅ | ADR-0000 ist **frei** (0 Treffer `lib/decimal-framework`, §14.7 dokumentiert die Konkordanz), aber 62 Dateien außerhalb ADR/Audit/Archiv/Todo tragen stale Pfade (identisch mit M5) |
| K2 | Lücke 11 (ADR-5020 vs. BANNED) | ✅ | `ADR-5020:5` → `status: deprecated` (Commit `9627aae`) |
| K3 | Lücke 9 (ADR-5050) | ✅ | identisch mit M2, erledigt in `d16a03d` |
| X1 | 591 `enabledOf` fail-open | ⚠ teilweise | `591:23` `…enable or false` (fail-open im Ausdruck) bleibt; Assertion `591:193` verlangt `enable` für jeden Eintrag in `config.medinix.manifest` — Einträge außerhalb dieses Attributs bleiben ungeprüft |
| X2 | Gate-Bug Return/STATUS | ⚠ unklar | `nixmeta_check.py` gibt konsistent 3-Tupel zurück, `STATUS` vollständig (siehe S1/S2) → wahrscheinlich erledigt, ohne Review-Text nicht belegbar |
| X3 | repl.nix `getFlake`/`where` | ✅ | `50-core/repl.nix:15` (`toString ./..`), `:24` (`where`) |
| X4 | 591 `factoryViolations` liest Ableitungen | ○ offen | `591:95-110` prüft `(svcCfgOf n).User`, `config.users.users.${n}` — also **abgeleitete** Werte. ADR-040: „Guardrails lesen nie das Abgeleitete, das sie prüfen" |

**K/X-Bilanz: 3 ✅ · 1 ○ · 3 ⚠**

---

## Gesamtbilanz

| Block | ✅ | ○ | ⚠ | Zeilen |
|---|---:|---:|---:|---:|
| S | 13 | 0 | 3 | 16 |
| M | 4 | 2 | 2 | 8 |
| L | 1 | 0 | 0 | 1 |
| K/X | 3 | 1 | 3 | 7 |
| **Summe** | **21** | **3** | **8** | **32** |

**Offene `○`: M4 (591 Options-Pfad), M5 (62-Dateien-Sweep), X4 (591 liest Ableitungen).**

---

## §14.6 / §14.7 — erledigt

Die frühere Fassung dieses Abschnitts meldete beide Unterabschnitte als fehlend.
Sie existieren seit `d16a03d`:

```
368: ### 14.6 Auslegungsregeln
376: ### 14.7 Pfad-Konkordanz (`lib/` → `50-core/`)
```

---

## Zusätzliche Befunde aus dieser Messung (nicht im Review enthalten)

| Befund | Beleg |
|---|---|
| `BANNED_TECHNOLOGIES.md:39` verweist auf `592-environment.nix` — existiert nicht | `ls 59-guardrails/*.nix` → nur `591-cross-domain.nix`. Welle 4 |
| ~~29 Dateien mit doppeltem `adr:`-Feld~~ | erledigt in `d16a03d` (`grep` → 0) |
| ~~`registry.nix` deklariert `hardeningProfile`, der Konsument ignoriert es~~ | erledigt in `5fc2932` |
