---
id: "0000"
title: "Decimal Framework — the Constitution of the Numbering Scheme"
domain: 00
status: active
complexity: 2
last_reviewed: 2026-11-04
tags:
  - constitution
  - decimal-framework
  - numbering
  - upg
links:
  adr: ADR-5043
---

> # ⚠ CONSTITUTION — this document must not be lost
> **It governs the numbering scheme of every project in this cosmos** — Nix-Grok,
> mediNix, devNIX and everything to come. The **rules** are enforced at build time
> by `decimalFrameworkCheck` and `50-core/501-decimal-engine.nix`; this document carries the rationale.
> Text changes are corrections, not loss — every version remains retrievable in the
> Git history and in `CHANGELOG.md`.
>
> **Anchored in:** `AGENTS.md` (mediNix), `CLAUDE.md` + `README` (devNIX),
> skill `/devnix-agent:struktur`.

# ADR-0000: The Decimal Framework

A numbering scheme that means **the same thing at every level** — from the system
root down to a single module folder. It is the only decision that applies
**across projects**: all other ADRs govern *one* project, this one governs the
grammar of *all*. Whoever knows it finds their way in any repo without having read
it. **One language, everywhere.**

---

## 1. Two-Level Tree & Meaningful Isomorphism

The decimal framework organizes all system modules in a strict, fixed **two-level tree**:

```
Level 1 (Container)   2-digit   00 · 10 · 20 · … · 90    Structure, domains & decades
Level 2 (Leaf)        3-digit   511 · 512 · … · 589      Concrete service modules
Derived (Runtime)     4-digit   5110 · 5120 · … · 5890   Port / UID / UPG-GID (NO folder level!)
```

Four-digit numbers are **never** architectural levels, folder tiers, or sub-modules;
they are exclusively derived runtime attributes ($\text{Port} = \text{UID} = \text{GID}_{\text{UPG}} = \text{ID} \times 10$).
Level-3 folder graduation does not exist; the module layout remains strictly flat and two-tiered.

### Container slots and leaf slots

The decimal structure maintains a sharp boundary between structure and runtime services:

- A **container slot** (2-digit, `D0` or `HD`) holds structural grouping (decades,
  domains, directories). On container slots the **universal 10-slot taxonomy** applies (Section 2 & 3).
- A **leaf slot** (3-digit, `HDS`) holds concrete service daemons and modules. On
  leaf slots there are only two roles:
  - **`HD0` = block ID** (the foundation/options of the decade, never a program or daemon).
  - **`HD1`–`HD9` = services / tasks** (deployable systemd units or build-time policies).

So `532` reads as: `5` (namespace: project mediNix) · `3` (decade: Ingestion / Acquisition) · `2` (leaf: second acquisition service).

### §1.3 Fraktales Ordnungsprinzip (Universelle Grammatik)

Der Dezimalrahmen fungiert nicht nur als Verfassung für NixOS-Dienstmodule, sondern als universelle, fraktale Grammatik für die gesamte Dateisystem- und Repository-Ordnung. Dieselbe dekadische Systematik ordnet reine Hilfsfunktionen (`50-core/`), Architektur-Dokumente (`docs/adr/`), Skripte und Credentials (`/var/lib/medinix/secrets/`) entlang der funktionalen Pipeline von Foundation (`_0`) bis Guardrails (`_9`). Die strengen Modul- und Runtime-Invarianten (keine Daemons in `_0`/`_9`, $\text{Port} = \text{UID} = \text{num} \times 10$) gelten dabei ausschließlich für ausführbare Dienstmodule und binden Nicht-Modul-Artefakte nicht. Dadurch bleibt das gesamte System über alle Abstraktionsebenen hinweg intuitiv navigierbar und frei von unstrukturierten Sonderordnern. (Quelle: Chat 1 Block 12 D-12-01).

---

## 2. The Structural Boundary Slots (`_0`, `_1`, `_2`, `_9`)

Four boundary slots frame every project and system root identically. Die Slots sind
**Rollen**, keine Ordner — welche Datei welche Rolle trägt, regelt §14
(Datei-Klassifikation).

| Slot | Role | Question | Content & Daemon Invariant |
|---|---|---|---|
| **`_0`** | **Foundation** | What do we work with? | Engine, Registry, Options-Schema. Dateien: `50-core/*` (Foundation), `50-core/501-decimal-engine.nix` (Engine), `50-core/registry.nix` (SSoT). Root-Doku (`CLAUDE.md`, `default.nix`) ist **Root-Config** (§14), nicht Teil von `_0`. **Strictly structure & engine, NEVER daemons.** |
| **`_1`** | **Access** | How do you get in? | Reverse proxy, DNS, ACME, identity provider, mDNS, edge defenses |
| **`_2`** | **Security** | How is it protected? | Host firewall (`nftables`), VPN killswitch, `systemd-creds` |
| **`_9`** | **Guardrails** | What must everything comply with? | Compile-time assertions (`config.assertions`), global invariants — **NEVER daemons** |

**`_1`/`_2` boundary:** `_1` governs **the entire ingress and access path** — proxy, IdP, DNS, ACME, mDNS, and edge defenses. `_2` protects **the host and egress boundary** — sealed credentials, VPN confinement, host firewall, kernel hardening.

---

## 3. Universal Functional 10-Slot Taxonomy (`_0` to `_9`)

There is **no arbitrary "free middle"**. Across every project in the cosmos (`mediNix`, `devNIX`, `40-documents`), all ten decades (`_0` through `_9`) follow a strict, universal functional pipeline from input to observability and guardrails.

### Abstraction Level (Invariant)

The decimal framework recognizes exclusively **functional roles, never software names**. The column *"Illustrative Examples (never prescriptive)"* lists concrete implementations solely for illustration — they are never a prerequisite for the assignment of a slot. When a service is assigned to `_1`, it is because it fulfills the role **Access** (e.g. reverse proxy, identity provider, DNS resolver, ACME client), not because it is named "Caddy" or "Pocket-ID". Any software that fulfills the architectural role is permissible — even if it is not mentioned in any table.

| Slot | Canonical Role | Universal Function | Illustrative Examples (never prescriptive) | Daemons Allowed? |
|---|---|---|---|---|
| **`_0`** | **Foundation** | Structure, Engine, Registry, Docs | e.g. baseline architecture, options schema, agent constitution | **NO** (`decade != 0`) |
| **`_1`** | **Access** | Ingress, Reverse-Proxy, DNS, IdP, mDNS | e.g. reverse proxy, identity provider, DNS resolver, ACME client | YES (`H11`–`H19`) |
| **`_2`** | **Security** | Host-Firewall, nftables, VPN-Killswitch, Creds | e.g. host firewall, VPN confinement, sealed credential broker | YES (`H21`–`H29`) |
| **`_3`** | **Ingestion** | Input, Sources, Indexers, Scanners, Acquisition | e.g. indexer, metadata scanner, acquisition downloader | YES (`H31`–`H39`) |
| **`_4`** | **Processing** | Transformation, Download Processing, Mover, Build | e.g. download processor, storage mover, pipeline | YES (`H41`–`H49`) |
| **`_5`** | **Core UI / App** | **Primary Purpose of the Flake** | e.g. media streaming engine, primary application workspace | YES (`H51`–`H59`) |
| **`_6`** | **Exposition** | Request Catalogs, API Gateways, External Delivery | e.g. request catalog, API gateway, external delivery | YES (`H61`–`H69`) |
| **`_7`** | **Maintenance** | Backup, SQLite-WAL, GC, Storage-Tiering | e.g. state backup, SQLite checkpointing, garbage collection | YES (`H71`–`H79`) |
| **`_8`** | **Observability** | Monitoring, Push-Alerts, Telemetry, Health | e.g. status monitoring, push-alerting, telemetry | YES (`H81`–`H89`) |
| **`_9`** | **Guardrails** | Compile-Time Assertions, Global Invariants | e.g. cross-domain compile-time assertions, schema & AST gates | **NO** (`decade != 9`) |

Unoccupied slots remain empty reserves; they are never repurposed for unrelated functions.

**Rollenname ≠ Ordnername:** Der Ordner heißt `53-acquisition`, die Rolle heißt `ingestion` — Synonym. Bindend ist die Rolle in der Tabelle, nicht der Verzeichnisname.

---

## 4. Derivations & User Private Groups (UPG)

**The sole source of derivation is the three-digit service number** (`HDS`: project · decade · service, where $H \in [1..9]$, $D \in [1..8]$, $S \in [1..9]$).

| Quantity | Formula | Example: `532` (Ingestion) | Band | Purpose & Isolation Boundary |
|---|---|---|---|---|
| **Port** | $\text{num} \times 10$ | `5320` | `Hxx0` | Internal HTTP loopback / upstream binding |
| **UID** | $\text{num} \times 10$ | `5320` | `Hxx0` | Dedicated process execution user |
| **Primary GID (UPG)** | $\text{num} \times 10$ | `5320` | `Hxx0` | User Private Group for `/var/lib/<name>` (`StateDirectoryMode 0750`) |
| **Shared GID** | $\lfloor\text{num} / 100\rfloor \times 1000$ | `5000` | `H000` | Shared storage group (`SupplementaryGroups` only!) |
| **State Directory** | `"/var/lib/${name}"` | `/var/lib/<service>` | — | Clean canonical state path without port suffixes |
| **Decade Index** | $\lfloor\text{num} / 10\rfloor \bmod 10$ | `3` (Ingestion) | `0..9` | Programmatic decade classification (`decadeIndex`) |

### UPG Security Contract
- **Primary Group = UID = `num × 10`:** Every daemon runs under its own User Private Group (`users.groups.${name}.gid = spec.primaryGid`) with `StateDirectory = name` and `StateDirectoryMode = "0750"`. No service can read another service's private `/var/lib/<name>` directory.
- **Default Service UMask = `0002`:** Systemd services default to `UMask = "0002"`, ensuring that collaborative media files created in shared group directories are group-writable (`rw-rw-r--`).
- **Shared Group `H000` (`5000 media`) as Supplementary Group:** Assigned exclusively via `extraGroups = [ "media" ]` to services that require Tier C media access (`needsSharedGroup` / `needsMediaGroup`). Edge ingress (`511`) and identity (`512`) never receive GID `5000`.
- **SetGID Requirement on Shared Media Storage (`chmod g+s`):** Shared storage directories (Tier C, e.g. `/data/media/*`) **must have the SetGID bit set** (`chmod 2775 /data/media/*`). This ensures that files created by daemons running with their own primary UPG automatically inherit the parent directory's group ownership (`media`), enabling frictionless multi-service read/write access (e.g. Sonarr, Radarr, SABnzbd, Jellyfin) under `UMask 0002` without violating UPG isolation in private state directories.

### Hard Engine Invariants (`50-core/501-decimal-engine.nix`)
1. **I1 (Three-Digit Range):** $100 \le \text{num} \le 999$.
2. **I2 (No Decade Zero-Slot Daemons):** $\text{num} \bmod 10 \neq 0$ (`HD0` is reserved for block IDs).
3. **I3 (No Foundation Daemons):** $\lfloor\text{num} / 10\rfloor \bmod 10 \neq 0$ (`_0` never spawns daemons).
4. **I4 (No Guardrail Daemons):** $\lfloor\text{num} / 10\rfloor \bmod 10 \neq 9$ (`_9` is build-time evaluation only).

**I1 gilt projektbezogen (`5xx`):** Die `num`-Werte `500`, `502` und `503` sind Foundation-Module der Dekade `_0`, keine Dienste. Sie tragen keine Unit, keinen Port und keine eigene UPG.

### Role Declaration (Recommended, Never Prescriptive)
Declaring an optional `role` string in the service manifest (e.g. `role = "media-server"`) is recommended as best practice to document the functional intent beyond the numeric slot. The field is purely descriptive and has **no impact on Port, UID, or GID derivations**. If declared, it must not be an empty string (`assertion = role != ""`).

### Linux Capabilities (Operator / Host Boundary)
Linux capabilities are an operational decision of the host system and are **never derived from numbers**.
- **Validation only, no automatic injection:** The engine validates declared capabilities against a strict compile-time whitelist (`allowedCapabilities = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ]`). **It does not inject them into systemd unit configs.** Each service module requiring ambient capabilities must explicitly configure them in its own `serviceConfig.AmbientCapabilities`.
- **Root Capability Defense:** Dangerous root capabilities (`CAP_SYS_ADMIN`, `CAP_SYS_RAWIO`, `CAP_SYS_MODULE`, `CAP_SETPCAP`, `CAP_SETUID`, `CAP_SETGID`, `CAP_CHOWN`, `CAP_NET_BROADCAST`) are strictly forbidden and trigger immediate build failure.

### §4.4 Credentials-Speicherort (Secrets & Sealed Creds)

TPM-versiegelte Geheimnisse (`.cred`-Dateien) liegen standardmäßig im persistenten System-Datenverzeichnis `/var/lib/medinix/secrets/` und niemals innerhalb des versionierten Nix-Modulbaums. Die Bereitstellung und Deklaration wird von `52-security/521-creds.nix` verwaltet und via `LoadCredentialEncrypted` an die jeweiligen Service-Units übergeben. Die Versionierung oder Sicherung dieser Schlüsseldateien erfolgt ausschließlich über private Repositorys oder separate lokale Backups mit strengem Zugriffsschutz, niemals in öffentlichen Quellen. Diese Trennung stellt sicher, dass die Dezimalphilosophie für Secret-Referenzen gewahrt bleibt, ohne sensible Daten im Nix-Store oder Git zu exponieren. (Quelle: Chat 1 Block 04 D-04-01, ADR-521).

---

## 5. The Structural Proofs

Die Beweise in §5.1 rechnen **projektbezogen** (`H = 5`). Die universellen Grenzen in §5.2 gelten für den **Gesamtraum** (`H ∈ [1..9]`).

### 5.1 Shared GID (`H000`) and Service UIDs/UPGs Never Collide
The shared project group is $H000$. By Invariants I2 and I3, neither decade `0` ($\lfloor\text{num}/10\rfloor \bmod 10 = 0$) nor leaf `0` ($\text{num} \bmod 10 = 0$) can register a daemon. Thus the minimum valid service number in project $H$ is $H11$:
$$\text{UID}_{\min} = \text{GID}_{\text{UPG},\min} = H110 > H000$$
Collision between `H000` and any service UID/primary GID is mathematically impossible.

### 5.2 Derived Internal Ports Are Never Privileged and Never Ephemeral
For any valid service number $\text{num} \in S_{\text{valid}} = \{100H + 10D + S \mid H \in [1..9], D \in [1..8], S \in [1..9]\}$:
- **Lower bound:** $\text{Port}_{\min} = 111 \times 10 = 1110 > 1023$ (never privileged).
- **Upper bound:** $\text{Port}_{\max} = 989 \times 10 = 9890 < 32768$ (never collides with the Linux ephemeral port range `32768–60999`).

---

## 6. System Root Alignment (Host Boundary)

Partitioning of top-level system directories across multiple independent appliances is host-specific and governed by the host configuration repository (`nix-hermes`), not by this constitution. This document defines the universal decimal grammar for appliances, decades, and services.

---

## 7. Example: Document Appliance (`40-documents`, `H = 4`, Shared GID `4000`)

```
40-core            _0  Foundation (options, registry)
41-ingress         _1  Access (reverse proxy, SSO)
42-security        _2  Security (nftables, creds)
43-ingestion       _3  Mail & Scanner Consumers (431)
44-processing      _4  OCR & Document Conversion Pipelines (441, 442)
45-archive         _5  Document Archive Core UI (451 -> Port/UID/GID 4510)
46-exposition      _6  Public Share Links / API Gateways (461)
47-maintenance     _7  State Backup & SQLite-WAL Checkpointing (476)
48-observability   _8  Health Checks & Push Alerts (481, 482)
49-guardrails      _9  Cross-Domain Assertions (491)
```

---

## 8. Why This Constitution Bears the `0000`

`0000` is the root block ID of namespace `0` (Foundation), occupying the exact slot its own grammar reserves for global structural law.

---

## 9. Exclusion Log (Rejected Alternatives)

| Rejected Proposal | Architectural Reason |
|---|---|
| **"Free Middle" (`_3` to `_8` arbitrary)** | Caused cross-project drift (Storage/Backup/Monitoring landed in random decades); replaced by the universal 10-slot functional taxonomy. |
| **Flat GID `5000` as primary group** | Violated Least Privilege in `/var/lib/<service>`; replaced by UPG (`primaryGid = uid = num * 10`) + `5000` as supplementary group. |
| **Global `UMask 0027` on Shared Media** | Prevented peer services in supplementary group `media` from reading/writing new media files; resolved via default `UMask 0002` + `chmod g+s` on Tier C paths while retaining `StateDirectoryMode 0750` for private state isolation. |
| **Permissive Capabilities Whitelist (`CAP_SETPCAP`, etc.)** | Unnecessary privilege escalation risk for appliance daemons; reduced to minimal `[ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ]`. |
| **StateDirectory with port suffix (`name-port`)** | Broke NixOS upstream expectations and complicated path references; replaced by canonical `/var/lib/${name}`. |
| **Level-3 folder graduation (4-digit folders)** | Collided with the 4-digit Port/UID space; module hierarchy is strictly a two-level tree. |
| **Daemons in `_0` or `_9`** | `_0` is foundation/options and `_9` is compile-time assertions; neither may spawn runtime services. |

---

## 10. Consequences

- **Predictable Cross-Project Navigation:** Every decade (`_0` to `_9`) has the exact same functional role across all repositories.
- **Strict State Isolation & Multi-Service Sharing:** UPG (`GID = UID = ID * 10`) with `StateDirectoryMode = 0750` seals `/var/lib/<name>` against peer processes, while `UMask = 0002` in combination with SetGID (`chmod g+s`) on Tier C ensures frictionless media exchange via supplementary group `H000`.
- **Compile-Time Enforcement:** Invalid service numbers or forbidden daemon decades (`_0`, `_9`, `HD0`) fail immediately during Nix evaluation.

---

## 11. Semantic Anchors

| Principle in the document | Established standard (Semantic Anchor) |
|---|---|
| One `num` derives Port, UID, UPG-GID, shared GID (§4) | [**SSOT** — Single Source of Truth](../anchors/ssot-principle.md) |
| Derive instead of repeat (Port/UID/GID/stateDir) | [**DRY** — Don't Repeat Yourself](../anchors/dry.md) |
| Engine invariants I1–I4 in `50-core/501-decimal-engine.nix` (§4) | [**Design by Contract** (Meyer)](../anchors/design-by-contract.md) |
| A wrong combination must be unrepresentable | [**Poka-Yoke**](../anchors/poka-yoke.md) — vgl. die Lehre von der *tautologischen* Assertion (§4) |
| Universal 10-slot taxonomy `_0`..`_9` (§3) | [**MECE**](../anchors/mece.md) — Mutually Exclusive, Collectively Exhaustive |
| Slot assigned by functional role, not software product (§3) | **Protocol over Product** (role abstraction) — kein Katalog-Anker |
| UPG primary group vs. supplementary storage group (§4) | [**Principle of Least Privilege**](../anchors/least-privilege.md) |
| Recognizability across repos (§3, §10) | [**ISO/IEC 25010** — Maintainability](../anchors/iso-25010.md) |
| `registry.nix` as a narrow, stable interface | [**Deep Modules**](../anchors/deep-modules.md) |
| Rejected alternatives table (§9) | [**MADR** — exclusion log](../anchors/madr.md) |

> **Protocol over Product:** Der Slot wird anhand der Rolle vergeben, nicht anhand der Software.
> **Anker = komprimiertes Vorwissen:** Die verlinkten Definitionen liegen (englisch, Apache-2.0)
> unter [`docs/anchors/`](../anchors/README.md) — ein Begriff statt 1000 Worte Umschreibung.

---

> **Nummerierung:** §12 bleibt frei. Die Sektion war bis `edb04f3` der Appendix und
> wurde bei der Einführung von §14 (Datei-Klassifikation) zu §15. Die Nummer 12 wird
> nicht nachbesetzt, damit bestehende „§14"-Verweise (u. a. in `scripts/nixmeta_check.py`)
> gültig bleiben.

## 13. Documentation Triad (Dokumentationstrias: Lastenheft, Pflichtenheft, ADRs)

*Quelle: `todo/blocks/25-docs-trias.json` (D-25-01)*

Zur Vermeidung von Missverständnissen und Diskrepanzen zwischen Spezifikation, technischer Realisierung und Architektur-Entscheidungen folgt mediNix einer strikten dreistufigen Dokumentationshierarchie:
1. **Lastenheft (Das „Was“):** Fachliche Anforderungen und Zielkriterien aus Auftraggebersicht (z. B. `ROADMAP.md`, `docs/TODO.md`).
2. **Pflichtenheft (Das „Wie“):** Konkrete technische Umsetzungsspezifikation, Modulsignaturen, Typen und Schnittstellen (z. B. Guides, Modulkommentare, `docs/arch/`).
3. **ADRs (Das „Warum“):** Unveränderliche Architekturentscheidungen an Weggabelungen (MADR-Format in `docs/adr/`), inklusive expliziter Begründung und Ausschlusslog verworfener Alternativen.

---

## 14. Datei-Klassifikation

Jede `.nix`-Datei des Repos gehört genau einer von sieben Kategorien an. Die Kategorie
folgt aus der **Konsumform** — wer die Datei liest und wie —, nicht aus dem Dateiinhalt.
Derselbe Nix-Ausdruck kann als Modul, als Bibliothek oder als Testkonsument auftreten;
erst der Konsumweg entscheidet, welche Pflichtfelder gelten.

### 14.1 Die sieben Kategorien

| Kategorie | Pfad-Muster | Beispiel | YAML `kind:` |
|---|---|---|---|
| **Modul** | `5X-*/NNN-*.nix` | `51-ingress/511-caddy.nix` | implizit (Pfad) |
| **Library** | `5X-*/<name>.nix` (ohne `NNN-`) | `50-core/registry.nix` | `library` |
| **Engine** | `50-core/501-decimal-engine.nix`, `50-core/service-contract.nix` | — | `engine` |
| **Package** | `packages/<name>/*.nix` | `packages/arr-provision/default.nix` | `package` |
| **Test** | `tests/*.nix` | `tests/smoke-test.nix` | `test` |
| **Root-Config** | `flake.nix`, `default.nix` (Repo-Wurzel) | — | `root-config` |
| **Tooling-Einstieg** | `50-core/repl.nix` (einzige Ausnahme) | — | `tooling` |

Ist-Stand 2026-11-04 (69 `.nix`-Dateien):

- **Modul (45):** alle `NNN-*.nix` in `51-*`…`59-*` sowie `50-core/500`, `502`, `503`
- **Library (9):** `50-core/derive.nix`, `50-core/hardening-profiles.nix`,
  `50-core/manifest.nix`, `50-core/memory-policy.nix`, `50-core/registry.nix`,
  `50-core/service-factory.nix`, `51-ingress/ingress-access.nix`,
  `52-security/creds.nix`, `53-acquisition/arr-settings.nix`
- **Engine (2):** `50-core/501-decimal-engine.nix`, `50-core/service-contract.nix`
- **Package (3):** `packages/arr-provision/default.nix`, `packages/medinix-cli/default.nix`,
  `packages/medinix-cli/cli.nix`
- **Test (2):** `tests/smoke-test.nix`, `tests/vm-smoke-test.nix`
- **Root-Config (2):** `flake.nix`, `default.nix`
- **Tooling-Einstieg (1):** `50-core/repl.nix`
- **Zonen (5, keine Kategorie — siehe §14.2):** 4 × `docs/examples/`, 1 × `docs/agents/**/templates/`

Summe: 45 + 9 + 2 + 3 + 2 + 2 + 1 + 5 = 69.

`packages/<name>/default.nix` ist der `callPackage`-Einstiegspunkt des Pakets
(`pkgs.callPackage ./packages/<name> { … }` löst darauf auf). Die Implementierung
daneben (`cli.nix`) trägt einen eigenen Header und zählt deshalb als eigene Datei.

**Tooling-Einstieg** ist der einzige Fall im Repo, in dem eine `.nix`-Datei direkt
aufgerufen und **nie importiert** wird: `nix repl --file 50-core/repl.nix`. Sie als
Library zu führen wäre falsch (Libraries werden importiert), als Root-Config ebenfalls
(sie liegt in `50-core/`). Sie trägt kein `provides:`/`requires:` — es gibt keinen
Konsumenten, für den diese Angaben etwas aussagen würden.

Libraries in `5X-*/` werden **nicht** auto-importiert. `default.nix` zieht ausschließlich
Dateien, die `^[0-9]{3}-.*\.nix$` in Ordnern `^[0-9]{2}-.*` erfüllen (Zeilen 58 und 67);
alles andere wird explizit eingebunden. `50-core/service-contract.nix` ist die einzige
Engine, die diesem Muster nicht folgt und deshalb hart in `default.nix` Zeile 80 steht.
`50-core/501-decimal-engine.nix` ist dagegen modulförmig **und** auto-importiert — Engine
zu sein ist keine Import-Aussage, sondern eine Rollenaussage.

### 14.2 Zonen für Beispiele und Vorlagen

| Zone | `status:` | Geprüft von |
|---|---|---|
| `docs/examples/**/*.nix` | `example` | `nixmeta_check.py` (Zonenregel) |
| `docs/agents/**/templates/**/*.nix` | `template` | `nixmeta_check.py` (Zonenregel) |

Beispiele und Vorlagen sind modul- oder libraryförmig, gehören aber nicht zum Modulbaum
und werden nie importiert. Sie werden über **Zone + `status:`** identifiziert, nicht über
`kind:` — eine Aussage, eine Stelle.

**Beispiele sind Blaupausen:** Beim Kopieren in `5X-*/` werden relative Import-Pfade gegen
den **Zielordner** aufgelöst, nicht gegen `docs/examples/`.

### 14.3 Header-Felder pro Kategorie

Basis-Pflichtfelder (ADR-00-nixmeta-v3): `id`, `title`, `domain`, `folder`, `status`,
`complexity`, `last_reviewed`, `links.adr`.

Zusätzlich:

- `kind:` — Pflicht für Library, Engine, Package, Test, Root-Config und
  Tooling-Einstieg. Bei Modul **verboten** (der `NNN-`-Präfix ist die Aussage; ein
  zweites Feld wäre eine zweite Wahrheit). In Zonen (§14.2) ebenfalls verboten.
- `provides:` — **empfohlen** (Hinweis, wie `upstream_*` in ADR-00), nicht Pflicht.
  Für Library und Engine sinnvoll, für Tooling-Einstieg gegenstandslos.
- `requires:` — **empfohlen** für Engine (Hinweis), nicht Pflicht. Für Library nicht
  vorgesehen.
- `folder:` — Verzeichnis relativ zur Repo-Wurzel, `.` für die Wurzel.
- `status:` — Lebenszyklus, **orthogonal** zur Kategorie: `active | deprecated | draft |
  example | template`. `kind: test` + `status: active` heißt „das ist ein Test, und er
  läuft" — zwei Dimensionen, zwei Felder.

### 14.4 Prüfung durch `nixmeta_check.py` (Ratsche 3)

1. `classify(path)` wertet in fester Reihenfolge aus: Root-Liste → Engine-Liste →
   Tooling-Liste (`50-core/repl.nix`) → Modul
   (`^[0-9]{2}-[^/]+/[0-9]{3}-.*\.nix$`) → Library
   (`^[0-9]{2}-[^/]+/[^/]+\.nix$`) → `packages/` → `tests/` → Zonen. Die expliziten
   Listen stehen **vor** den Mustern: `50-core/501-decimal-engine.nix` erfüllt sowohl
   die Engine- als auch die Modul-Form, `50-core/repl.nix` sowohl die Tooling- als auch
   die Library-Form. Kein Treffer ergibt `unklassifiziert` — das ist ein Verstoß.
2. Zonen-Treffer beenden die Kategorie-Prüfung: kein `kind:`, `status:` muss zur Zone
   passen (§14.2).
3. Für die sieben Kategorien: fehlt `kind:`, ist das nur bei Modul zulässig. Ein gesetztes
   `kind:` muss dem Ergebnis von `classify()` entsprechen.
4. `folder:` == Verzeichnis relativ zur Wurzel — für **alle** Dateien, nicht nur für
   `NNN-*`.
5. `status:` stammt aus dem erlaubten Set; `example` und `template` sind ausschließlich in
   ihren Zonen zulässig.

### 14.5 Was §14 nicht regelt

- Keine Umverteilung von Modulnummern (dafür gelten §3 und §4).
- Keine Pfad-Umbenennungen.
- Keine Aussage über die innere Struktur von `packages/medinix-cli/` (separate Aufgabe).
- Keine Aussage über `docs/audit/` und `docs/archive/` — dort liegt Ausgemustertes, es
  wird nicht gegated.

---

### 14.6 Auslegungsregeln

- **§1 `HD1`–`HD9` = services/tasks gilt für die Dekaden `_1`–`_8`.** In `_0` bedeuten
  `HD1`–`HD9` Foundation-Slots (Engine, Host-Module), nie Daemons (I3).
- **§5 rechnet projektbezogen** (`H = 5` → min UID `5110`, min Port `5110`). Die
  universellen Grenzen (Port `1110`–`9890`, `> 1023`, `< 32768`) gelten für den
  Gesamtraum.

### 14.7 Pfad-Konkordanz (`lib/` → `50-core/`)

| Alt (`lib/`) | Neu |
|---|---|
| `lib/decimal-framework.nix` | `50-core/501-decimal-engine.nix` (Engine) + `50-core/derive.nix` (Formel) |
| `lib/derive.nix` | `50-core/derive.nix` |
| `lib/registry.nix` | `50-core/registry.nix` |
| `lib/service-factory.nix` | `50-core/service-factory.nix` |
| `lib/service-contract.nix` | `50-core/service-contract.nix` |
| `lib/hardening-profiles.nix` | `50-core/hardening-profiles.nix` |
| `lib/memory-policy.nix` | `50-core/memory-policy.nix` |
| `lib/arr-provision/` | `packages/arr-provision/` |

Wo §1.3, §2 oder §4 `lib/…` nennen, gilt diese Konkordanz.

---

## 15. Appendix & Architecture Decoupling

The methodological and cross-cutting architectural specifications (Stages 2 & 3) live in:
- **[ARCH-0000 — Decimal Framework Appendix](file:///home/moritz/repos/mediNix-core/docs/arch/ARCH-0000-framework-appendix.md)**
