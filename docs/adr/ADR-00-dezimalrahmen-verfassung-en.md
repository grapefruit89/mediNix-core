---
id: "ADR-00-dezimalrahmen-verfassung-en"
title: "ADR 0000 decimal framework constitution (en)"
domain: 00
status: active
complexity: 2
last_reviewed: 2026-08-20
tags:
  - general
links:
  adr: ""
  repo-harvest: ""
---
# ---
# id: 0000
# title: "Decimal Framework — the Constitution of the Numbering Scheme"
# status: "accepted"
# note: "CONSTITUTION — applies to every project, never delete. Formerly ADR-8000 (Renamed: Section 8)"
# date: "2026-07-22"
# supersedes: [8000]
# related: [5042, 5043]
# tags: ["dezimalrahmen", "verfassung", "numbering", "isomorphie", "fraktal", "anker", "ableitung"]
# error_pattern: "dezimalrahmen|verfassung|vier anker|nummernschema|_0|_1|_2|_9|fraktal|fundament|leitplanken|graduier|ableitung|port.*10|uid|gid|projekt.*1000|welche nummer|wohin geh|block-id|container|blatt"
# ---

> # ⚠ CONSTITUTION — this document must never be lost
> **It governs the numbering scheme of every project in this cosmos** — Nix-Grok,
> mediNix, devNIX and everything in the future. Do not delete, do not replace, only
> append. If a part proves to be false: set `status` to `superseded`, note the
> reason — but leave it in place.
>
> **Anchored in:** `AGENTS.md` + `CLAUDE.md` (mediNix), `CLAUDE.md` + `README`
> (devNIX), Skill `/devnix-agent:struktur`. Anyone touching one of these will
> be guided here.

# ADR-0000 — The Decimal Framework

A numbering scheme that **means the same thing on every level** — from the system root
down to a single module folder. It is the only decision that applies
**across projects**: all other ADRs regulate *one* project, this one regulates the
grammar of *all* of them. Anyone who knows it can navigate any repo without
having read it. **One language, everywhere.**

---

## 1. Fractal and Isomorphic

Recurring themes appear in **every** project — media, documents,
network, agents. Each needs a foundation, an entry point, security, and
rules. Exactly these themes get **fixed slots** that mean the same everywhere.

The leading digit is the **Namespace**, the last digit is the **Role**:

```
Level 1   /modules/      2-digit   00 · 10 · 20 · … · 90
Level 2   /50-media/     3-digit   500 · 510 · … · 590
Level 3   (if needed)    4-digit   5510 · 5520 · …
```

A level remains **flat** (files) until it gets too big — then it **graduates**
into another digit. Thus `50-media` → 50-mediNix (500–590) and
`80-agents` → devNIX (800–890).

### Container Slots and Leaf Slots

The fractal has a precise boundary that was previously unspoken:

- A **Container Slot** holds structure (decades, domains, folders). The
  **four anchors** apply here (Section 2).
- A **Leaf Slot** holds services. There are only two roles here:
  **`N0` = Block-ID** (the foundation of the decade, never a program) and
  **`N1`–`N9` = Services**.

So `532` reads as: `5` (Container: Project mediNix) · `3` (Container:
Decade Acquisition) · `2` (Leaf: second service). The anchors repeat on
every container slot — not on the leaf slot. **If a slot graduates**
(gets another digit), its former leaf slot becomes a
container slot, and the anchors apply there again. This keeps the schema fractal
without having to claim "531 = Entry of Acquisition" — that would be nonsense
and was never intended.

---

## 2. The Four Anchors — the same everywhere

| Slot | Role | Question | Content |
|---|---|---|---|
| **`_0`** | **Foundation** | What are we working with? | `CLAUDE.md`, Options-`default.nix`, `docs/`, `registry` — **Knowledge and Structure, no services** |
| **`_1`** | **Entry** | How do you get in? | Reverse Proxy, mDNS, Routing, Auth Entry |
| **`_2`** | **Security** | How is it protected? | Firewall, TLS, VPN Confinement, Auth Mechanics |
| **`_9`** | **Guardrails** | What must everything comply with? | Assertions, Bans, Global Invariants |

Anyone seeing `_2` knows it means Security — in the System Root (`20`), in mediNix (`520`),
everywhere. A project **only populates the anchors it has**; an empty anchor
is reserved, not an error.

**Clarification on `_0`:** Earlier drafts said "Knowledge, no code". That was
imprecise — the aggregating `default.nix` with the options declarations *is*
code. The strict rule is: **`_0` holds knowledge and structure, never
services.** No program, no daemon, no systemd unit emerges from `_0`.
Options API, Registry, Docs: yes. `services.*`: no.

---

## 3. The Free Middle — `_3` to `_8`

Six slots belong to the domain itself, in logical order. There is
**no** cross-project meaning here: `_5` means "Media" in the System Root,
"Playback" in mediNix, and something third elsewhere. This is the place for what makes a
project unique. Unoccupied middle slots are reserves — they are not
filled up to avoid gaps; the gap *is* the information "there is space here".

---

## 4. Derivations — what follows from the number

The number is the only truth. Everything else is derived from it, and
**all sizes carry the project digit at the front** — you read a number and immediately
know the project.

**The derivation source is exclusively the three-digit service number**
(Project · Decade · Service). Two-digit root slots and four-digit
Level 3 numbers derive **nothing** — they number structure, not services.
Without this rule, Level 3 derivations (`5510 × 10 = 55100`) would collide with
ephemeral port ranges and blow up the UID band.

| Size | Rule | `sonarr` (532) | Band |
|---|---|---|---|
| **Port** | Number × 10 | `5320` | `Hxx0` |
| **UID** | Number × 10 | `5320` | `Hxx0` |
| **GID** | Project × 1000 | `5000` | `H000` |

"Remainder" = the two digits after the project digit (Decade + Service): from `532`
it becomes `32`. Everything about mediNix is a 5 — Group `5000`, User `5xx0` (identical to port), Ports
`5xx0`. For devNIX it is `8000` / `8xx0` / `8xx0`.

We share the GID across the project (so Jellyfin can read Sonarr's files), but the UID *individually* (`5110`,
`5320`, …) for process isolation. The same leading digit, but **never the same
number** — an individual GID per service would be the Docker PUID/PGID mistake
(`Permission denied`).

**Three transformations, because each target space has its own limits:**

- **Port** (`× 10`): every project lands in its own thousand band,
  never privileged (Proof: Section 5).
- **UID** (`× 10`): **UID and Port are identical.** This ensures maximum 
  simplicity and isomorphism (Folder Number == UID == Port). The band `H110`–`H990`
  lies safely between System IDs (<1000) and DynamicUsers (61184+). The registry 
  **reserves** the band per project and declares it an invariant via assertion,
  so no human account ever counts into it.
- **GID** (`× 1000`): shared project-wide, above all static
  NixOS system GIDs (< 1000).

Isomorphism does **not** mean "all numbers are equal", but rather: *everything from one
number, each size transformed appropriately, all with the same leading digit.*
This is **meaningful isomorphism** (ADR-5042).

---

## 5. The Structural Proofs — the framework protects itself

Two guarantees follow not from caution, but from the rules themselves.

### 5.1 GID and UID never collide

The GID is `H000`. Can a user ever get `H000`? **Structurally
no.** `H000` would mean "Remainder = `00`" (in the old schema) or Number `H00` (in the new). 
And `H00` is the Block-ID of the project, which according to Section 2 is **never a
program**. Additionally, the entire `_0` decade (`H00`–`H09`) holds no services.
No service ever resides on `H0X`, so no user ever gets a UID below
`H110`. The `H000` remains **exclusive to the group — guaranteed by the
structure, not by discipline.**

### 5.2 No derived port is ever privileged

The smallest possible service number of a project `H` is `H11` — because the
`_0` decade holds no services (smallest decade: 1) and `N0` is never a service
(smallest service: 1). So the smallest port is `H110`. For every project `H ≥ 1`,
`H110 ≥ 1110 > 1023` — never privileged. And `H = 0`? The namespace 0
is the foundation of the whole (Section 8) — knowledge, no services, no
ports. **The same two rules that protect the GID also keep every port
out of the privileged range.** Upper limit: largest service number `999` →
Port `9990 < 65535`; collision with the Linux ephemeral band (default from 32768)
is impossible because three-digit sources generate a maximum of `9990`.

### 5.3 Unix Sockets — Rule reserved

If ever needed: `/run/{project}/{number}.sock`. Currently no
service supports HTTP over Unix socket (checked on q958: the *arrs only bind TCP). The
rule is ready but not applied.

---

## 6. The System Root already follows the framework

Nix-Grok built the pattern before it was named:

```
00-core          _0  Foundation    ✓ Anchor
10-network       _1  Entry         ✓ Anchor
20-security      _2  Security      ✓ Anchor
30-storage       ┐
40-observability │
50-media  → 50-mediNix   _3–_8  Domains (free)
60-apps          │
70-home-automation
80-agents → devNIX ┘
90-policy        _9  Guardrails    ✓ Anchor
```

Four anchors, six domains. The framework is not an invention, but the already
existing order — just made explicit.

---

## 7. Example: a Document Project (`_4`)

For illustration, **not** as a build order:

```
40-documents/  → (graduates to a repo, 4xx)   GID 4000
  400  Foundation   CLAUDE.md, registry, docs      what are we working with
  410  Entry        Reverse Proxy, SSO             how to get in
  420  Security     Access Protection              how is it protected
  430  Acquisition  paperless-ngx                  what goes in
  440  Storage      nextcloud, opencloud           where is it
  490  Guardrails   Assertions                     what to comply with
```

Anyone who knows mediNix reads this without instructions.

---

## 8. Why this constitution bears the 0000 (formerly 8000)

The previous number `8000` was a namespace error that the constitution itself
uncovers: `8` is devNIX. `8000` is therefore devNIX's own `_0` slot — the
Block-ID of *one* project. A document that governs **all** projects must
not reside in the foundation slot of a single one; otherwise it collides with devNIX's
own foundation and contradicts its own slot semantics.

The pure number is **`0000`**: the Block-ID of the root. Namespace `0` is
the foundation on every level — and `N00` is never a program, always knowledge.
The constitution thus occupies exactly the slot that its own rules reserve for exactly
this kind of content, at the top of the tree. **It instantiates
itself.** Side effect: the port proof in 5.2 ("H = 0 never derives") gets
its inhabitant.

*Migration:* References to "ADR-8000" in `AGENTS.md`, `CLAUDE.md`, READMEs and
in the skill must be changed to `0000`; leave a forwarding note under the old number
(`superseded by 0000`), according to its own rule "never delete".

---

## 9. Rejected

| Proposal | Reason |
|---|---|
| **Three Anchors** (Security as Domain) | Security recurs in every project → fixed slot like Foundation/Entry |
| **Security on `_1`** | `_1` is everywhere "Entry"; would break isomorphism |
| **`_9` = Security instead of Guardrails** | `20-security` (Mechanics) and `90-policy` (Assertions) are two things; `_2` Mechanics, `_9` Constitution |
| **UID = 1000 + Number** (`1532`) | Would lead with `1` instead of the project digit; would break "project digit in front" |
| **GID per Service** (isomorphic) | Destroys shared library access — `Permission denied` |
| **Nested Folders** `510/511-x.nix` | Breaks the flat auto-import and dismantles working factories |
| **Fill `_0` with Service Code** | `_0` is knowledge and structure; services go in the middle |
| **Anchors on the Leaf Slot** ("531 = Entry of Acquisition") | Leaf slots only know Block-ID and services (Section 1); Anchors apply to Container slots |
| **Derivations from 2- or 4-digit numbers** | Only the three-digit service number derives; otherwise Port/UID band collisions (Section 4) |
| **Constitution as 8000** | devNIX's foundation slot; namespace collision — now 0000 (Section 8) |

---

## 10. Consequences

- **Recognition without looking up** — `_2` is Security, `5xxx` is mediNix, everywhere.
- **New projects start with a skeleton** — four anchors given, just fill the middle.
- **Knowledge is transferable** — one grammar across all repos.
- **Guarantees instead of Discipline** — GID exclusivity and unprivileged ports
  follow from the structure (Section 5), not from diligence.
- **Cost:** existing projects adopting the framework must renumber
  (mediNix: ADR-5043). Cheap in the development phase, expensive later.

---

## 11. Origin and Version History

From a brainstorm series by the repo owner (July 2026), slot by slot checked against
reality on q958. Milestones: the Four-Anchor conclusion (when
`20-security` and `90-policy` turned out to be two things), the GID rule
`Project × 1000`, and the collision proof via the `N00` rule — all three by the
owner, verified and justified here.

Consolidated on 2026-07-22 from four previous drafts; their contradictions are
resolved (Log: `KONSOLIDIERUNG.md`):

| Previous Draft | Status | Resolution |
|---|---|---|
| `8000-dezimalrahmen.md` (no derivations) | superseded | fully absorbed herein |
| `8000-clean.md` (with derivations) | superseded | Basis of this version; Clarifications §1/§2/§4/§5/§8 |
| `ableitungen.md` (UID = 1000 + Number) | **rejected** | UID formula contradicted "project digit in front" — see Rejected |
| `ableitungen2.md` (UID = Project × 1000 + Remainder) | superseded | absorbed into §4/§5 |
