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

The decimal framework organizes all system modules in a strict, fixed **two-level tree**:

```
Level 1 (Container)   2-digit   00 · 10 · 20 · … · 90    Structure, domains & decades
Level 2 (Leaf)        3-digit   511 · 512 · … · 599      Concrete service modules
Derived (Runtime)     4-digit   5110 · 5120 · … · 5990   Port / UID / UPG-GID (NO folder level!)
```

Four-digit numbers are **never** architectural levels, folder tiers, or sub-modules;
they are exclusively derived runtime attributes ($\text{Port} = \text{UID} = \text{GID}_{\text{UPG}} = \text{ID} \times 10$).
Level-3 folder graduation does not exist; the module layout remains strictly flat and two-tiered.

### Container slots and leaf slots

The decimal structure maintains a sharp boundary between structure and runtime services:

- A **container slot** (2-digit, `D0` or `HD`) holds structural grouping (decades,
  domains, directories). On container slots the **four anchors** apply (Section 2).
- A **leaf slot** (3-digit, `HDS`) holds concrete service daemons and modules. On
  leaf slots there are only two roles:
  - **`HD0` = block ID** (the foundation/options of the decade, never a program or daemon).
  - **`HD1`–`HD9` = services** (deployable systemd units).

So `532` reads as: `5` (namespace: project mediNix) · `3` (container: acquisition
decade) · `2` (leaf: second service, Sonarr). The anchors repeat on container slots,
never on leaf slots. The scheme stays simple, deterministic, and flat without any
deeply nested folder graduation.

---

## 2. The four anchors — the same everywhere

| Slot | Role | Question | Content |
|---|---|---|---|
| **`_0`** | **Foundation** | What do we work with? | `CLAUDE.md`, options `default.nix`, `docs/`, `registry` — **knowledge and structure, no services** |
| **`_1`** | **Access** | How do you get in? | reverse proxy, mDNS, routing, auth entry |
| **`_2`** | **Security** | How is it protected? | firewall, TLS, VPN confinement, auth mechanics |
| **`_9`** | **Guardrails** | What must everything comply with? | assertions, prohibitions, global invariants |

**`_1`/`_2` boundary (clarification):** `_1` governs **the whole access path** —
the door *and* who gets through: proxy, IdP, DNS, ACME, mDNS **plus the edge
defenses** (Geo-IP, CrowdSec, rate-limiting). `_2` protects **the system itself** —
secrets, VPN, host firewall, kernel hardening. Mnemonic: *`_1` = the door + who
gets through · `_2` = protect the house.* The "firewall" in `_2` is the **host**
firewall; the edge defenses belong to `_1`, so the access chain stays readable in
one place (KISS).

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
decade · service). Two-digit container slots and arbitrary four-digit numbers derive
**nothing** — they number structure, not services.

| Quantity | Rule | `sonarr` (532) | Band | Purpose & Isolation Boundary |
|---|---|---|---|---|
| **Port** | number × 10 | `5320` | `Hxx0` | Internal HTTP loopback / upstream binding |
| **UID** | number × 10 | `5320` | `Hxx0` | Dedicated process execution user |
| **Primary GID (UPG)** | number × 10 | `5320` | `Hxx0` | User Private Group for private `/var/lib/<service>` |
| **Supplementary GID (Shared)** | project × 1000 | `5000` | `H000` | Shared storage group for Tier C media paths (`/data/media`) |

### User Private Groups (UPG) & State Directory Protection

Earlier naive designs assigned the shared group `5000` (`media`) as the primary group
to all daemons. That broke the Principle of Least Privilege: an exposed edge service
(such as Caddy or Pocket-ID) could laterally read private SQLite databases or session
tokens of other services in `/var/lib/<service>` whenever permissions were group-readable.

The decimal framework resolves this by establishing **User Private Groups (UPG)**:
- **Primary Group = UID = `number × 10`:** Every daemon runs with its own private primary
  group (`GID = UID`). Systemd sets private `StateDirectory` paths (`/var/lib/<service>`)
  to mode `0750 <uid>:<uid>` or `0700`. No peer daemon can inspect private state.
- **Shared Group `H000` via `SupplementaryGroups`:** The shared media group (e.g., `5000`
  for mediNix) is **never** a service's primary group. It is assigned strictly as a
  supplementary group (`SupplementaryGroups = [ "media" ]`) to genuine media consumers
  and acquisition services (`53x`, `54x`, `55x`) that operate on Tier C storage (`/data/media`).
  Edge ingress, authentication, and core daemons never receive GID 5000.

This eliminates both lateral state leaks and the historic Docker `PUID/PGID` permission
failures (`Permission denied`).

**Transformations per target space:**

- **Port** (`× 10`): internal loopback HTTP port, landing in its project thousand-band,
  never privileged (proof: Section 5.2).
- **UID** (`× 10`): **UID, primary GID, and internal port are identical.** This provides
  maximum isomorphism and debuggability (service number `532` → UID `5320`, UPG GID `5320`,
  port `5320`). The band `H110`–`H990` lies safely between system IDs (<1000) and
  systemd DynamicUsers (61184+).
- **Supplementary GID** (`× 1000`): static shared media group (`5000`), above static NixOS
  system GIDs (<1000).

Isomorphism does **not** mean "all numbers equal", but: *everything derived from the one
number, each quantity transformed appropriately, all with the same leading digit.*
That is **meaningful isomorphism** (ADR-5042).

### Invariants (enforced, not merely described)

Two rules are **hard**. They stand here not as convention, but are checked at build
time by `decimalFrameworkCheck` (`flake.nix`):

- **I1 — services are always three-digit** (project · decade · service). Two-digit
  numbers represent containers/structure and derive **nothing**. Without I1 the upper
  bound proof in 5.2 would break, because larger numbers could produce ports exceeding
  the safe boundary.
- **I2 — the project digit is exclusively the first digit** (mediNix = `5`,
  devNIX = `8`). The folder name `50-media` carries project digit `5` + block `0`;
  for the shared GID only the project digit counts → `5000`, not `50000`.

---

## 5. The structural proofs — the framework protects itself

Two guarantees follow not from caution, but from the rules themselves.

### 5.1 Shared GID and Service UIDs/UPGs never collide

The shared supplementary group GID is $H000$ (e.g. `5000`). Under UPG, a service
has $\text{UID} = \text{GID}_{\text{UPG}} = \text{number} \times 10$. Can any service
UID or primary GID ever collide with the shared group GID $H000$?

**Structurally no.** An ID of $H000$ would require service number $H00$. Per Section 2,
`HD0` is the project or decade block ID — **never a service program or daemon**.
Furthermore, the foundation decade `H0` (`H00`–`H09`) holds knowledge and options,
never services. The lowest valid service number is $H11$, which derives:
$$\text{UID}_{\min} = \text{GID}_{\text{UPG},\min} = H110 > H000$$
The shared group ID $H000$ remains **exclusive to the shared storage group — guaranteed
by structure, not by discipline.**

### 5.2 Port Theorem — Internal Loopback Ports are Never Privileged

The derivation theorem $\text{Port} = \text{number} \times 10$ applies strictly to
**internal loopback and upstream HTTP ports** (`127.0.0.1:Hxx0`).

Standard protocol-bound host ports (such as HTTP `80` and HTTPS `443` for the Caddy
reverse proxy, or mDNS `5353` for discovery) are **physical host network interfaces**
and protocol standards. They are governed by RFC standards and host firewalling, not
by the internal service derivation formula.

For all derived internal service ports:
- **Lower bound:** The smallest service number of project $H$ is $H11$ (since decade 0
  holds no services and slot 0 is never a service). The smallest derived port is therefore:
  $$\text{Port}_{\min} = H110$$
  For every valid project namespace $H \ge 1$:
  $$H110 \ge 1110 > 1023$$
  Derived ports are structurally unprivileged without requiring `CAP_NET_BIND_SERVICE`.
  Namespace 0 (`H = 0`) is the foundation of the system root — documentation and structure,
  hosting zero services and zero ports.
- **Upper bound:** The largest valid service number is `999`, yielding $\text{Port}_{\max} = 9990$.
  This guarantees that all derived ports reside well below the default Linux ephemeral port
  range (`net.ipv4.ip_local_port_range = 32768 60999`), preventing runtime binding collisions.

### 5.3 Unix sockets — rule reserved

If ever needed: `/run/{project}/{number}.sock`. Currently no service supports
HTTP over a Unix socket (checked on mediahost: the *arrs bind TCP only). The rule stands
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
| **Flat GID 5000 as primary group** | destroys private state directory isolation (UPG solves this: primary GID = UID = ID*10 for /var/lib, shared GID 5000 strictly via SupplementaryGroups for Tier C) |
| **Level-3 folder graduation (4-digit folders)** | breaks flat module discovery and blows port/UID bands if derived; the framework is strictly a two-level tree |
| **Nested folders** `510/511-x.nix` | breaks the flat auto-import and splits working factories |
| **Filling `_0` with service code** | `_0` is knowledge and structure; services go in the middle |
| **Anchors on the leaf slot** ("531 = access of acquisition") | leaf slots know only block ID and services (Section 1); anchors apply on container slots |
| **Derivations from 2- or 4-digit numbers** | only the three-digit service number derives; two-digit numbers are containers and four-digit numbers are derived runtime values (Section 4) |
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

## 12. Appendix & Architecture Decoupling

The methodological and cross-cutting architectural specifications (Stages 2 & 3),
formerly appended to this constitution, have been decoupled into a dedicated architectural
specification:

- **[ARCH-0000 — Decimal Framework Appendix](file:///home/moritz/repos/mediNix-core/docs/arch/ARCH-0000-framework-appendix.md)**

It defines the formal mappings and engineering processes governing the repo:
- **A1. arc42 + C4:** Mapping of documentation chapters and C4 diagram abstractions.
- **A2. ISO/IEC 25010 & Quality Attribute Scenarios (QAS):** Concrete measurable criteria.
- **A3. STRIDE + LINDDUN:** Threat modeling and privacy boundary specifications.
- **A4. Design by Contract & Fitness Functions:** Guardrails and property-based test definitions ($S_{\text{valid}}$).
- **A5. Diátaxis:** Separation of documentation concerns (Tutorials, How-tos, Reference, Explanation).
- **B1–B4. Process, Migration & Knowledge Anchors:** Evolutionary architecture patterns, SemVer, BLUF, and theory building.
