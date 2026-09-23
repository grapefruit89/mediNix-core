---
id: "0000"
title: "Decimal Framework — the Constitution of the Numbering Scheme"
domain: 00
status: active
complexity: 2
last_reviewed: 2026-09-23
tags:
  - constitution
  - decimal-framework
  - numbering
links:
  adr: ADR-5043
---

> # ⚠ CONSTITUTION — this document must not be lost
> **It governs the numbering scheme of every project in this cosmos** — Nix-Grok,
> mediNix, devNIX and everything to come. The **rules** are enforced at build time
> by `decimalFrameworkCheck` in the flake; this document carries the rationale.
> Text changes are corrections, not loss — every version remains retrievable in the
> Git history and in `CHANGELOG.md`.
>
> **Anchored in:** `AGENTS.md` (mediNix), `CLAUDE.md` + `README` (devNIX),
> skill `/devnix-agent:struktur`.

# ADR-0000 — The Decimal Framework

A numbering scheme that means **the same thing at every level** — from the system
root down to a single module folder. It is the only decision that applies
**across projects**: all other ADRs govern *one* project, this one governs the
grammar of *all*. Whoever knows it finds their way in any repo without having read
it. **One language, everywhere.**

> **Terminology note.** In this document "anchor" means the four **slot anchors**
> (`_0/_1/_2/_9`). To be distinguished from these are **semantic anchors** —
> established methodology terms (SSOT, Design by Contract, MECE …) that ADRs and
> agents use to communicate precisely (Section 11).

---

## 1. Fractal and isomorphic

Recurring themes appear in **every** project — media, documents, network, agents.
Each needs a foundation, an access point, security and rules. Exactly these themes
get **fixed slots** that mean the same everywhere.

The leading digit is the **namespace**, the last digit the **role**:

```
Level 1   /modules/      2-digit   00 · 10 · 20 · … · 90
Level 2   /50-media/     3-digit   500 · 510 · … · 590
Level 3   (if needed)    4-digit   5510 · 5520 · …
```

A level stays **flat** (files) until it grows too large — then it **graduates**
into another digit. Thus `50-media` → 50-mediNix (500–590) and `80-agents` →
devNIX (800–890).

### Container slots and leaf slots

The fractal has a precise boundary that was previously unspoken:

- A **container slot** holds structure (decades, domains, folders). On it the
  **four anchors** apply (Section 2).
- A **leaf slot** holds services. On it there are only two roles:
  **`N0` = block ID** (the foundation of the decade, never a program) and
  **`N1`–`N9` = services**.

So `532` reads as: `5` (container: project mediNix) · `3` (container: acquisition
decade) · `2` (leaf: second service). The anchors repeat on every container slot —
not on the leaf slot. **When a slot graduates** (gains another digit), its former
leaf slot becomes a container slot, and the anchors apply there again. Thus the
scheme stays fractal without having to claim "531 = access of acquisition" — that
would be nonsense and was never meant.

---

## 2. The four anchors — the same everywhere

| Slot | Role | Question | Content |
|---|---|---|---|
| **`_0`** | **Foundation** | What do we work with? | `CLAUDE.md`, options `default.nix`, `docs/`, `registry` — **knowledge and structure, no services** |
| **`_1`** | **Access** | How do you get in? | reverse proxy, mDNS, routing, auth entry |
| **`_2`** | **Security** | How is it protected? | firewall, TLS, VPN confinement, auth mechanics |
| **`_9`** | **Guardrails** | What must everything comply with? | assertions, prohibitions, global invariants |

Whoever sees `_2` knows security — in the system root (`20`), in mediNix (`520`),
everywhere. A project **populates only the anchors it has**; an empty anchor is
reserved, not an error.

**Precision on `_0`:** Earlier versions said "knowledge, not code". That was
imprecise — the aggregating `default.nix` with the option declarations *is* code.
The sharp rule is: **`_0` holds knowledge and structure, never services.** No
program, no daemon, no systemd unit arises from `_0`. Options API, registry, docs:
yes. `services.*`: no.

---

## 3. The free middle — `_3` to `_8`

Six slots belong to the domain itself, in logical order. Here there is **no**
cross-project meaning: `_5` means "media" in the system root, "playback" in mediNix,
something else elsewhere. This is the place for what makes a project unique.
Unoccupied middle slots are reserve — they are not filled to avoid gaps; the gap
*is* the information "there is room here".

---

## 4. Derivations — what follows from the number

The number is the only truth. Everything else is derived from it, and **all
quantities carry the project digit in front** — you read a number and immediately
know the project.

**The sole source of derivation is the three-digit service number** (project ·
decade · service). Two-digit root slots and four-digit level-3 numbers derive
**nothing** — they number structure, not services. Without this rule, level-3
derivations (`5510 × 10 = 55100`) would collide with ephemeral port ranges and
blow the UID band.

| Quantity | Rule | `sonarr` (532) | Band |
|---|---|---|---|
| **Port** | number × 10 | `5320` | `Hxx0` |
| **UID** | number × 10 | `5320` | `Hxx0` |
| **GID** | project × 1000 | `5000` | `H000` |

"Remainder" = the two digits after the project digit (decade + service): from `532`
comes `32`. Everything in mediNix is a 5-er — group `5000`, user `5xx0` (identical
to the port), ports `5xx0`. In devNIX `8000` / `8xx0` / `8xx0`.

We share the GID project-wide (in `5000`, so that Jellyfin reads Sonarr's files),
the UID *individually* (`5110`, `5320`, …) for process isolation. The same leading
digit, but **never the same number** — a separate GID per service would be the
Docker PUID/PGID mistake (`Permission denied`).

**Three transformations, because every target space has its own limits:**

- **Port** (`× 10`): every project lands in its own thousand-band, never
  privileged (proof: Section 5).
- **UID** (`× 10`): **UID and port are identical.** This gives maximum simplicity
  and isomorphism (folder number == UID == port). The band `H110`–`H990` lies
  safely between system IDs (<1000) and DynamicUsers (61184+). The registry
  **reserves** the band per project and declares it an invariant via assertion, so
  that no human account ever counts into it.
- **GID** (`× 1000`): shared project-wide, above all static NixOS system GIDs
  (< 1000).

Isomorphism does **not** mean "all numbers equal", but: *everything from the one
number, each quantity transformed appropriately, all with the same leading digit.*
That is **meaningful isomorphism** (ADR-5042).

### Invariants (enforced, not merely described)

Two rules are **hard**. They stand here not as convention, but are checked at build
time by `decimalFrameworkCheck` (`flake.nix`):

- **I1 — services are always three-digit** (project · decade · service). Two- and
  four-digit numbers number structure and derive **nothing**. Without I1 the upper
  bound proof in 5.2 would break, because four-digit sources could produce `99900`.
- **I2 — the project digit is exclusively the first digit** (mediNix = `5`,
  devNIX = `8`). The folder name `50-media` carries project digit `5` + block `0`;
  for the GID only the `5` counts → `5000`, not `50000`.

---

## 5. The structural proofs — the framework protects itself

Two guarantees follow not from caution, but from the rules themselves.

### 5.1 GID and UID never collide

The GID is `H000`. Can a user ever get the `H000`? **Structurally no.** `H000`
would mean "remainder = `00`" (in the old scheme) or number `H00` (in the new).
And `H00` is the project's block ID, per Section 2 **never a program**.
Additionally the entire `_0` decade (`H00`–`H09`) holds no services. No service
ever lives on `H0X`, so no user ever gets a UID below `H110`. The `H000` remains
**exclusive to the group — guaranteed by structure, not by discipline.**

### 5.2 No derived port is ever privileged

The smallest possible service number of a project `H` is `H11` — because the `_0`
decade holds no services (smallest decade: 1) and `N0` is never a service (smallest
service: 1). Smallest port therefore `H110`. For every project `H ≥ 1`,
`H110 ≥ 1110 > 1023` — never privileged. And `H = 0`? Namespace 0 is the
foundation of the whole (Section 8) — knowledge, no services, no ports. **The same
two rules that protect the GID also keep every port out of the privileged range.**
Upper bound: largest service number `999` → port `9990 < 65535`; collision with the
Linux ephemeral band (default from 32768) is excluded, because three-digit sources
produce at most `9990`.

### 5.3 Unix sockets — rule reserved

If ever needed: `/run/{project}/{number}.sock`. Currently no service supports
HTTP over a Unix socket (checked on q958: the *arrs bind TCP only). The rule stands
ready, but is not applied.

---

## 6. The system root already follows the framework

Nix-Grok built the pattern before it was named:

```
00-core          _0  foundation   ✓ anchor
10-network       _1  access       ✓ anchor
20-security      _2  security     ✓ anchor
30-storage       ┐
40-observability │
50-media  → 50-mediNix   _3–_8  domains (free)
60-apps          │
70-home-automation
80-agents → devNIX ┘
90-policy        _9  guardrails   ✓ anchor
```

Four anchors, six domains. The framework is not an invention, but the order that
already existed — merely made explicit.

---

## 7. Example: a document project (`_4`)

For illustration, **not** as a build order:

```
40-documents/  → (graduates into a repo, 4xx)     GID 4000
  400  foundation   CLAUDE.md, registry, docs     what we work with
  410  access       reverse proxy, SSO            how you get in
  420  security     access control                how it is protected
  430  capture      paperless-ngx                 what goes in
  440  storage      nextcloud, opencloud          where it lives
  490  guardrails   assertions                    what to comply with
```

Whoever knows mediNix reads this without instruction.

---

## 8. Why this constitution bears the 0000

The pure number is **`0000`** — the block ID of the root. Namespace `0` is the
foundation at every level, and `N00` is never a program, always knowledge. The
constitution thus occupies the slot that its own rules reserve for this kind of
content, at the top of the tree.

The migration from the former `8000` (a namespace error) as well as all previous
versions are archived in `CHANGELOG.md` (section "Doku-Sanierung: ADR-0000").

---

## 9. Rejected

| Proposal | Reason |
|---|---|
| **Three anchors** (security as a domain) | security recurs in every project → fixed slot like foundation/access |
| **Security on `_1`** | `_1` is "access" everywhere; would break isomorphism |
| **`_9` = security instead of guardrails** | `20-security` (mechanics) and `90-policy` (assertions) are two things; `_2` mechanics, `_9` constitution |
| **UID = 1000 + number** (`1532`) | led with `1` instead of the project digit; would break "project digit in front" |
| **GID per service** (isomorphic) | destroys the shared library access — `Permission denied` |
| **Nested folders** `510/511-x.nix` | breaks the flat auto-import and splits working factories |
| **Filling `_0` with service code** | `_0` is knowledge and structure; services go in the middle |
| **Anchors on the leaf slot** ("531 = access of acquisition") | leaf slots know only block ID and services (Section 1); anchors apply on container slots |
| **Derivations from 2- or 4-digit numbers** | only the three-digit service number derives; otherwise port/UID band collisions (Section 4) |
| **Constitution as 8000** | devNIX's foundation slot; namespace collision — now 0000 (Section 8) |

---

## 10. Consequences

- **Recognition without looking up** — `_2` is security, `5xxx` is mediNix, everywhere.
- **New projects start with a skeleton** — four anchors given, only fill the middle.
- **Knowledge is transferable** — one grammar across all repos.
- **Guarantees instead of discipline** — GID exclusivity and unprivileged ports
  follow from the structure (Section 5), not from care.
- **Price:** existing projects that adopt the framework must renumber
  (mediNix: ADR-5043). Cheap during development, expensive later.

---

## 11. Semantic Anchors — the established terms behind the framework

This document is no special case: it implements known methodology. Whoever knows
the names understands it without instruction — in a team as in a model. The anchor
names condense the intent; they are vocabulary, not obligation (apply
proportionally).

| Principle in the document | Semantic Anchor |
|---|---|
| "The number is the only truth" (Section 4) | **SSOT** — Single Source of Truth |
| I1/I2, `decimalFrameworkCheck` (Section 4) | **Design by Contract** — invariants |
| Four slot anchors + free middle, no gaps (Section 2/3) | **MECE** — mutually exclusive, collectively exhaustive |
| Container slot vs. leaf slot (Section 1) | **Separation of Concerns** |
| "One language, everywhere" (intro, Section 10) | **Ubiquitous Language** (DDD) |
| "Recognition without looking up" (Section 10) | **ISO/IEC 25010** — understandability/maintainability |
| "Rejected" table (Section 9) | **Pugh matrix** / decisional balance sheet |
| This document itself | **ADR (Nygard)** / **MADR** |

---

## 12. Appendix — anchor layer (stage 2 & 3)

> These appendices are **project-wide** — they apply to the whole repo, not just
> this constitution. If they are later extracted, the following suggest
> themselves: `docs/arch/` (A1–A3, A5), `docs/MIGRATION.md` (B1),
> `CONTRIBUTING.md` (B2), `docs/WORKBENCH.md` (B3), `docs/ONBOARDING.md` (B4).
>
> Vocabulary basis: **semantic anchors** — see Section 11.

---

### A1. arc42 + C4 — architecture docs named

The architecture docs exist (`docs/arch/`, `docs/architecture.md`) — they are just
not mapped onto the established chapter structure. **arc42** makes them
connectable; **C4** gives the diagrams a fixed level of abstraction.

| arc42 chapter | Existing document |
|---|---|
| 1. Introduction & goals | `docs/README.md`, `50-core/MANIFEST.md`, `docs/arch/ARCH-50-architecture-principles.md` |
| 2. Constraints | `AGENTS.md`, `docs/NO-CONTAINERS.md` |
| 3. Context & scope | `docs/arch/ARCH-50-architecture-blueprint.md`, `ARCH-50-service-manifest.md` |
| 4. Solution strategy | `docs/arch/ARCH-50-master-index.md`, `ARCH-50-architecture-principles.md` |
| 5. Building block view | `docs/arch/ARCH-50-base-configuration.md`, domains `51`–`59` |
| 6. Runtime view | `docs/arch/ARCH-50-3-stage-boot-pipeline.md` |
| 7. Deployment view | service map in `docs/README.md`, `ARCH-50-master-sources.md` |
| 8. Crosscutting concepts | `docs/concepts/*`, `ARCH-50-nixhome-layer.md` |
| 9. Architecture decisions | `docs/adr/` (ADR-0000 … ADR-577) |
| 10. Quality requirements | `docs/arch/ARCH-58-sre-quality.md`, `docs/guides/GUIDE-58-seven-quality-gates.md` |
| 11. Risks & technical debt | `docs/arch/ARCH-57-impermanence-storage.md`, `ROADMAP.md`, "Phase 2" roadmap |
| 12. Glossary | `docs/INDEX.md`, `docs/repository.yaml` |

**C4 (diagrams, `C4-PlantUML` stdlib, not Mermaid):**
- **Context:** host (q958) · WAN/Cloudflare · client — plus the `_1`/`_2` ingress boundary.
- **Container:** NixOS host · systemd services · Caddy ingress · `systemd-creds`.
- **Component:** `lib/service-factory.nix`, `lib/registry.nix`, `51-ingress`, `59-guardrails`.
- **Code:** only where needed (e.g. the assertion chain in `591-cross-domain.nix`).

---

### A2. ISO/IEC 25010 + Quality Attribute Scenarios — quality made measurable

`ARCH-58-sre-quality.md` and `GUIDE-58-seven-quality-gates.md` already describe
quality. **ISO/IEC 25010** gives it the standard axes, **Quality Attribute
Scenarios** make it testable (target value instead of adjective).

**Axis mapping (excerpt):**

| ISO/IEC 25010 | mediNix promise | Evidence |
|---|---|---|
| Maintainability / understandability | "recognition without looking up" | ADR-0000 §10 |
| Reliability / fault tolerance | "fail-closed", `config.assertions` | `AGENTS.md`, `59-guardrails` |
| Maintainability / modularity | "dendritic modules", drop-a-file | `GUIDE-50-dendritic-modularization.md` |
| Security | tri-state boundary, no `mkForce` | `docs/NO-CONTAINERS.md`, ADR-0000 |
| Portability | no hardcoded IPs/hostnames | `AGENTS.md` (knock-out criterion) |
| Operational / transferability | zero containers, systemd-native | `docs/NO-CONTAINERS.md` |

**Quality Attribute Scenarios (six-part: source · stimulus · artifact · environment · response · measure):**

- **QAS-1 (maintainability):** *new agent* reads `docs/INDEX.md` → finds the
  canonical page for a service → **in ≤ 2 hops, without chat history**. Evidence: `llm-index.json`.
- **QAS-2 (reliability):** *host admin* sets a `mkForce` override → build aborts →
  **0 unprotected configurations are shipped**. Evidence: `config.assertions`.
- **QAS-3 (security):** *attacker* reaches an internal port from outside →
  connection is blocked → **0 internal services reachable from the WAN**. Evidence: `52-security`, `51-ingress`.
- **QAS-4 (portability):** *another host* takes over the module set → deployment
  runs without source changes → **0 hardcoded IPs/hostnames in the module tree**.

---

### A3. STRIDE — threat model for the `_2` slot

The `_2` slot (security) has modules (`520`, `521`, `525`, `526`) and a BSI audit
(`docs/compliance/bsi-it-grundschutz-audit.md`), but **no STRIDE model**. STRIDE
gives every element fixed threat classes; every mitigation references a threat ID.

| Element | STRIDE | Example threat | Mitigation (evidence) |
|---|---|---|---|
| Caddy ingress (511) | **S**poofing | foreign host header | enforce forward-auth (ADR-511-caddy) |
| Pocket-ID (512) | **S**poofing | OIDC token forgery | signature check, `512-pocket-id` (ADR-512) |
| Pocket-ID (512) | **I**nfo disclosure | metadata leak | LINDDUN check (see below) |
| Cloudflare DNS (513) | **T**ampering | DNS answer manipulated | DNSSEC/TLS, ADR-513-cloudflare-dns |
| VPN killswitch (526) | **I**nfo disclosure | DNS leak / IP leak | fail-closed killswitch, ADR-526 |
| `systemd-creds` (521) | **I**nfo disclosure | plaintext in the store | INV-SECRET: no `/nix/store/` prefix (ADR-521) |
| Landing page (518) | **R**epudiation | honeypot without a log | audit logging, ADR-518 |
| whole surface | **D**enial of service | boot without network | `584-post-boot-watchdog`, `583-runtime-guard` |
| all modules | **E**levation of privilege | privilege escalation | jailed services (ADR-52-privesc-audit-hardening) |

**LINDDUN (privacy, for Pocket-ID/identity):** Linking · Identifying ·
Non-repudiation · Detecting · Data disclosure · Unawareness · Non-compliance —
check each point for whether Pocket-ID stores only the necessary claims.

**Format:** threats receive IDs (`T-001…`), mitigations reference them (standard
pattern, see semantic-anchors contract "Crosscutting Concepts").

---

### A4. Design by Contract + Fitness Functions — the guardrails

The `59X` assertions are **fitness functions**: executable architecture rules that
break the build. **Design by Contract** supplies the vocabulary (precondition ·
invariant · postcondition).

- **Invariants (build time):** `config.assertions` in `591-cross-domain.nix`
  = the hard contracts (GID exclusivity, unprivileged ports, INV-SECRET).
- **Preconditions:** option schemas (`default.nix`) — what a caller must supply.
- **Postconditions:** `flake.nix` checks + `tests/smoke-test.nix` — what holds after the build.

**Property-based testing (gap):** the core invariants can be checked as
*properties* over the whole number space, not just on one example:

- *For every service number `n` (100 ≤ n ≤ 999):* `port(n) == n*10` **and**
  `uid(n) == port(n)` **and** `port(n) > 1023` **and** `port(n) < 65535`.
- *For all pairs `(a,b)`, `a≠b`:* `uid(a) ≠ uid(b)` (process isolation).
- *For all `n`:* `gid(n) == 5000` (shared project-wide, never per service).

Today `tests/smoke-test.nix` checks port isomorphism on one case — a generator over
`100..999` covers the whole space (and catches `9990 < 65535`).

---

### A5. Diátaxis — separating doc types

`docs/` today mixes types (guides · learn · concepts · patterns · arch · examples).
**Diátaxis** cleanly separates four purposes; **arc42** remains for architecture.

| Diátaxis type | Question | mediNix folder |
|---|---|---|
| **Tutorial** | "Get me in" | `docs/learn/` |
| **How-to** | "Solve my problem" | `docs/guides/` |
| **Reference** | "What is fact" | `docs/patterns/`, `docs/adr/`, `docs/repository.yaml` |
| **Explanation** | "Why so" | `docs/concepts/`, `docs/arch/` |

Rule: **arc42 = architecture** (chapters, §1) · **Diátaxis = user/docs**
(folders). `docs/architecture.md` should be a pointer to the arc42 map, not a
second tree.

---

### A6. Open decisions — architecture & security

1. **Language:** `docs/adr/README.md` says "English only from here". These stage-2
   texts are German (like ADR-0000). Switch `52-security/` and `docs/arch/` to English?
2. **Diagrams:** check C4 as PlantUML into the repo (does `mkdocs` render it?) or just link?
3. **Property test:** Nix evaluation (slow) or `lib/registry.nix` → JSON → Python check?

---

### B1. Migration anchors — the renumbering

The migration to the decimal framework **is already running** (git shows the
renames `ADR-00-…-en → ADR-0000-…`, `ADR-51-… → ADR-513-…`, `ADR-57-… → ADR-571-…`).
Exactly for this there are established procedures — they turn "we rename" into a
manageable process.

| Migration step | Anchor | Concrete |
|---|---|---|
| Replace old → new incrementally, never big-bang | **Strangler Fig** | old numbers stay referencable until nothing points to them |
| Preconditions first, then rename | **Mikado Method** | attempt the rename → what breaks (`llm-index.json`, `INDEX.md`, cross-references) → revert → precondition first. Never leave the build red |
| First ONE complete pass | **Walking Skeleton** | one ADR completely renamed (incl. index + cross-refs), then scale |
| Domain by domain | **Thin Vertical Slice** | `51-ingress` (510s) green, then `52-security` (520s) … never all at once |
| Resolve an open design question | **Spike Solution** | e.g. 4-digit level-3 numbers: timeboxed experiment, throw the code away |
| Handover mid-migration | **Hemingway Bridge** | "what's done, what's open, what's next" — as a note, not in the head |

**Rule:** every slice ends green (`nix flake check` + `docs-index.yml`) before the
next begins. That is the migration version of fail-closed.

---

### B2. Process anchors

| Rule | Anchor | Status quo in the repo |
|---|---|---|
| Commit format | **Conventional Commits** | partly lived (`fix(flake):`, `docs(compliance):`) — gaps: `WCR-003:`, `Architecture:` |
| Branch → PR → green main | **GitHub Flow** | CI exists (`.github/workflows/flake-check.yml`, `docs-index.yml`); the rule is missing in writing |
| When is "done" | **Definition of Done** | `AGENTS.md` §Verification (5 steps) + `docs/review-checklist.md` (`[A]`/`[T]`/`[M]`) |
| Versioning | **SemVer** | manifest "v2.0", workbench baseline `1.1 → 1.2` — schema not pinned down |

**Definition of Done = the `[A]/[T]/[M]` taxonomy.** `review-checklist.md` already
separates *eval assertion* (`[A]`), *automated test* (`[T]`), *human judgement*
(`[M]`) — that is a DoD with fitness-function character. Rule: `[A]`/`[T]` belong
in the build, not in a manual list.

**Closing the Conventional-Commits gap:** `CONTRIBUTING.md` is completely missing
(recon). A short document + a commit-msg gate makes the style enforceable instead
of random.

---

### B3. Text anchors

| Purpose | Anchor | Where |
|---|---|---|
| Every ADR begins with the core statement | **BLUF** | ADR-0000 already does it (the callout above) — pin the rule |
| Conclusion first, then supports | **Pyramid Principle** (Minto) | ADR-0000 §5 (proofs) is built pyramidally |
| German texts | **Good German after Wolf Schneider** | ADR-0000, `README.md`, `CHANGELOG.md` |
| English texts | **Plain English (Strunk & White)** | `AGENTS.md`, `docs/adr/README.md` |
| Machine/error texts | **Simplified Technical English (ASD-STE100)** | the assertion messages from ADR-5043 (`What/Why/Fix`, one sentence, imperative) |
| CHANGELOG entries | **Inverted Pyramid** | most important first |

**Core connection:** ADR-5043 prescribes `What / Why / Fix` for every assertion —
that *is* Simplified Technical English, only unnamed. Whoever knows the name keeps
the standard more easily (and it is immediately understandable to consumers).

---

### B4. Knowledge anchors

| Principle | Anchor | Evidence in the repo |
|---|---|---|
| The constitution is the system's "theory" | **Mental Model (Naur)** | ADR-0000 itself; ADR-5043 "Every Bug = Invariant" = theory maintenance |
| Deliver knowledge incrementally | **Progressive Disclosure** | `INDEX.md` → `llm-index.json` → per-folder `AGENTS.md` → skill |
| Separate docs by purpose | **Diátaxis** | see stage 2 §5 |
| Handover mid-work | **Hemingway Bridge** | workbench baselines (`WCR-001`, `WCR-003`) are exactly that |

**Naur is the strongest hit.** "Programming as Theory Building": the program is not
the code, but the theory the team carries. The mediNix constitution is that theory —
made explicit. ADR-5043 §5 ("Every Bug = Invariant") is the mechanism that protects
the theory against loss. This explains why the constitution "must not be lost": its
loss = loss of the system.

---

### B5. Open decisions — way of working

1. **Create `CONTRIBUTING.md`?** (recon: completely missing) — or integrate into `AGENTS.md`?
2. **Commit gate:** commit-msg hook (local) or CI check (`.github/`) — or both?
3. **Language of process docs:** EN (like `AGENTS.md`/`docs/adr/README.md`) or DE (like `CHANGELOG.md`/ADR-0000)?
4. **SemVer scope:** version module set, constitution and workbench baseline separately — or one schema for everything?
