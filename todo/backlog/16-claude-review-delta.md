# Claude-Review Delta — S/M/L-Fixes gegen Ist-Stand

Stand: 2026-11-04 (Commit `25e081c`)

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
| S3 | 5xx-service.example.nix Import-Pfade | ⚠ unklar | `docs/examples/5xx-service.example.nix:106` → `import ../50-core/service-factory.nix` löst **im Beispielordner** zu `docs/50-core/…` auf (existiert nicht). Korrekt erst nach Kopie in `5X-*/`. Pfad unverändert → Audit-Befund formal offen, evtl. bewusst (Blueprint) |
| S4 | 591 `enabledOf` → `observability.ntfy` | ⚠ unklar | `59-guardrails/591-cross-domain.nix:23` liest weiter `config.medinix.manifest.${n}.enable or false`. Absicherung neu über Assertion `:193-195`. Ob das der gemeinte Fix war: ohne Review-Text nicht entscheidbar |
| S5 | 4× `docs/examples/*.nix` status | ✅ | alle vier `docs/examples/{simple,vpn-confinement,mergerfs-tiering,5xx-service.example}.nix:6` → `status: example` |
| S6 | default.nix `folder` + `links.adr` | ✅ | `default.nix:5` (`folder: "."`), `:9-10` (`links.adr: ADR-0000`) |
| S7 | 503 doppeltes `links:` + ADR-0003 | ✅ | `50-core/503-host-integration.nix:22-23` — genau **ein** `links:`-Block, `adr: ADR-0003` (Commit `9b0e75a`) |
| S8 | 502 adr ADR-5020 → ADR-0000 | ✅ | `50-core/502-host-settings.nix:10` `adr: ADR-0000` (Commit `9b0e75a`) |
| S9 | Redundantes `adr:` entfernen (5 Dateien) | ⚠ teilweise | Bereinigt in `9b0e75a`: `591`, `541`, `511`, `521`. **29 Dateien** tragen weiterhin top-level `# adr:` **neben** `links.adr:` — z. B. `51-ingress/512-pocket-id.nix:20+22`, `56-exposition/561-seerr.nix`, `default.nix` |
| S10 | registry.nix Header | ⚠ unklar | `50-core/registry.nix:1-11` hat `status`, `kind: library`, `complexity`, `links.adr` — aber **kein** `provides:`/`requires:`. „Lifecycle-Felder" (Commit-Text `9b0e75a`) nicht auffindbar |
| S11 | ADR-5020/5030 deprecated | ✅ | `docs/adr/ADR-5020-knowledge-extraction-pipeline.md:5`, `ADR-5030-flake-module-patterns.md:5` → `status: deprecated` (Commit `9627aae`) |
| S12 | ADR-0010 → `packages/arr-provision/` | ✅ | `docs/adr/ADR-0010-*.md:50` nennt `packages/arr-provision/` |
| S13 | repl.nix nach 50-core + where-Helper | ✅ | `50-core/repl.nix` existiert; `:15` `getFlake (toString ./..)`, `:24` `where =` (Commit `5cda609`) |
| S14 | service-factory Null-Guard + Kommentar | ✅ | `50-core/service-factory.nix:68`, `:86`, `:141`, `:170` — vier `stateDir != null`-Guards |
| S15 | check-nixmap.py SCAN_DIRS | ✅ | `scripts/check-nixmap.py:27-38` → `50-core` … `59-guardrails` |
| S16 | BANNED DynamicUser + mkForce + lib | ⚠ teilweise | `50-core/BANNED_TECHNOLOGIES.md:130` DynamicUser-Scope, `:127` mkForce + Test-Ausnahme ✓. **Aber `:39` verweist auf `592-environment.nix` — Datei existiert nicht** (`59-guardrails/` hat nur `591`) |

**S-Bilanz: 11 ✅ · 0 ○ · 5 ⚠**

---

## M-Fixes (alle < 2 h)

| # | Fix (Kurzfassung) | Ist-Stand | Beleg |
|---|---|---|---|
| M1 | nixmeta_check.py Ratsche 3 | ✅ | Commit `25e081c` — `classify()`, `KIND_OF`, Zonen-/Modul-/folder-Regeln |
| M2 | ADR-5050 profilbasiert neu fassen | ○ offen | `docs/adr/ADR-5050-systemd-hardening-baseline.md:5` → `status: active`, unverändert |
| M3 | python-confined Profil, 541 umstellen | ○ offen | `grep -rn "python-confined" --include='*.nix' .` → 0 Treffer |
| M4 | 591 Assertion Options-Pfad-Auflösung | ○ offen | `59-guardrails/591-cross-domain.nix:95-110` prüft `(svcCfgOf n).User` direkt; keine Options-Pfad-Auflösung |
| M5 | Stale-`lib/` Sweep | ○ offen | **63 Dateien** mit stale `lib/`-Pfaden (ohne `docs/adr/`, `docs/audit/`, `docs/archive/`, `todo/`, `.agents/`, `CHANGELOG.md`) |
| M6 | §14 in ADR-0000 | ✅ | Commit `edb04f3` (7 Kategorien, 2 Zonen, `classify()`-Regeln) |
| M7 | Doku Konvention 4+7 (DynamicUser, Wrapper) | ⚠ unklar | `docs/CONVENTIONS.md` hat §1–§6 + Zusatzabschnitte, **kein §7**; „Wrapper" kommt nicht vor. Ziel ohne Review-Text nicht bestimmbar |
| M8 | ADR-040 §3 Klarstellung | ⚠ unklar | `docs/adr/ADR-040-*.md` hat keine §3-Nummerierung (`Kontext`/`Entscheidung`/`Konsequenzen`/`Import-Konventionen`); stale `lib/`-Referenzen dort weiterhin vorhanden |

**M-Bilanz: 2 ✅ · 4 ○ · 2 ⚠**

---

## L-Fixes

| # | Fix | Ist-Stand | Beleg |
|---|---|---|---|
| L1 | hardeningProfile Single-Source | ○ offen | `50-core/registry.nix:29` und `:45` setzen `hardeningProfile = profile`, aber `50-core/service-factory.nix:20-24` liest das Feld **nicht** (Kommentar: „profile is passed explicitly by the caller, not read from registry"). Deklariert ≠ wirkt |

**L-Bilanz: 0 ✅ · 1 ○ · 0 ⚠**

---

## Befunde aus Sektion 1 (Kritische Lücken + Außerhalb)

| # | Befund | Ist-Stand | Beleg |
|---|---|---|---|
| K1 | Lücke 12 (`lib/` in Normen) | ⚠ teilweise | ADR-0000 ist **frei** (0 Treffer `lib/decimal-framework`), aber 63 Dateien außerhalb ADR/Audit/Archiv/Todo tragen stale Pfade |
| K2 | Lücke 11 (ADR-5020 vs. BANNED) | ✅ | `ADR-5020:5` → `status: deprecated` (Commit `9627aae`) |
| K3 | Lücke 9 (ADR-5050) | ○ offen | identisch mit M2 |
| X1 | 591 `enabledOf` fail-open | ⚠ teilweise | `591:23` `…enable or false` (fail-open im Ausdruck) bleibt; Assertion `591:193` verlangt `enable` für jeden Eintrag in `config.medinix.manifest` — Einträge außerhalb dieses Attributs bleiben ungeprüft |
| X2 | Gate-Bug Return/STATUS | ⚠ unklar | `nixmeta_check.py` gibt konsistent 3-Tupel zurück, `STATUS` vollständig (siehe S1/S2) → wahrscheinlich erledigt, ohne Review-Text nicht belegbar |
| X3 | repl.nix `getFlake`/`where` | ✅ | `50-core/repl.nix:15` (`toString ./..`), `:24` (`where`) |
| X4 | 591 `factoryViolations` liest Ableitungen | ○ offen | `591:95-110` prüft `(svcCfgOf n).User`, `config.users.users.${n}` — also **abgeleitete** Werte. ADR-040: „Guardrails lesen nie das Abgeleitete, das sie prüfen" |

**K/X-Bilanz: 2 ✅ · 2 ○ · 3 ⚠**

---

## Gesamtbilanz

| Block | ✅ | ○ | ⚠ | Zeilen |
|---|---:|---:|---:|---:|
| S | 11 | 0 | 5 | 16 |
| M | 2 | 4 | 2 | 8 |
| L | 0 | 1 | 0 | 1 |
| K/X | 2 | 2 | 3 | 7 |
| **Summe** | **15** | **7** | **10** | **32** |

---

## §14.6 / §14.7 — Befund

Die committete Fassung enthält **nur §14.1 bis §14.5**:

```
255: ### 14.1 Die sieben Kategorien
296: ### 14.2 Zonen für Beispiele und Vorlagen
307: ### 14.3 Header-Felder pro Kategorie
326: ### 14.4 Prüfung durch `nixmeta_check.py` (Ratsche 3)
344: ### 14.5 Was §14 nicht regelt
```

**§14.6 und §14.7 fehlen** — Korrektur 2 aus der Review-Diskussion steht noch aus
(Batch 2a). Kein Widerspruch im Text: §14.5 schließt die Sektion derzeit sauber ab.

---

## Zusätzliche Befunde aus dieser Messung (nicht im Review enthalten)

| Befund | Beleg |
|---|---|
| `BANNED_TECHNOLOGIES.md:39` verweist auf `592-environment.nix` — existiert nicht | `ls 59-guardrails/` → nur `591-cross-domain.nix`, `AGENTS.md`, `README.md` |
| 29 Dateien mit doppeltem `adr:`-Feld (S9 nur zu 4/33 erledigt) | siehe S9 |
| `registry.nix` deklariert `hardeningProfile`, der Konsument ignoriert es | siehe L1 |
