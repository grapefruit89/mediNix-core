---
id: "ARCH-0000"
title: "Decimal Framework — Framework Appendix (arc42, ISO 25010, STRIDE, Quality Gates)"
domain: 00
status: active
complexity: 2
last_reviewed: 2026-10-14
tags:
  - architecture
  - framework
  - appendix
  - arc42
  - stride
links:
  adr: ADR-0000
---

# ARCH-0000 — Decimal Framework Appendix

> **Framework Appendix to ADR-0000 (Decimal Framework Constitution)**
> 
> This document holds the methodological and architectural anchor layers (Stages 2 & 3)
> decoupled from the constitutional core of [ADR-0000](file:///home/moritz/repos/mediNix-core/docs/adr/ADR-0000-dezimalrahmen-verfassung.md).
> While ADR-0000 governs the invariant numbering grammar, this appendix defines how
> mediNix maps its architecture, quality attributes, threat modeling, and development processes
> onto established industry standards.
>
> Vocabulary basis: **semantic anchors** — see ADR-0000 Section 11.

---

## A1. arc42 + C4 — Architecture Documentation Mapped

The architecture documentation in mediNix maps directly onto the established **arc42**
chapter structure, while **C4** provides deterministic levels of diagram abstraction.

| arc42 Chapter | mediNix Document | Content & Purpose |
|---|---|---|
| **1. Introduction & Goals** | `docs/INDEX.md`, `50-core/MANIFEST.md`, `docs/arch/ARCH-50-architecture-principles.md` | Requirements, quality goals, stakeholder overview |
| **2. Constraints** | `AGENTS.md`, `docs/NO-CONTAINERS.md` | Non-negotiable technical, organizational, and operational constraints |
| **3. Context & Scope** | `docs/arch/ARCH-50-architecture-blueprint.md`, `ARCH-50-service-manifest.md` | Business and technical context, external interfaces, boundaries |
| **4. Solution Strategy** | `docs/arch/ARCH-50-master-index.md`, `ARCH-50-architecture-principles.md` | Key technical decisions, decomposition strategy |
| **5. Building Block View** | `docs/arch/ARCH-50-base-configuration.md`, domains `51`–`59` | Hierarchical component decomposition (Level 1: 50-media, Level 2: 51x-59x) |
| **6. Runtime View** | `docs/arch/ARCH-50-3-stage-boot-pipeline.md` | Boot sequence, systemd dependency graphs, lifecycle interactions |
| **7. Deployment View** | Service map in `docs/INDEX.md`, `ARCH-50-master-sources.md` | Infrastructure mapping, physical ports, file paths |
| **8. Crosscutting Concepts** | `docs/concepts/*`, `ARCH-50-nixhome-layer.md` | Security, user isolation (UPG), persistence, logging |
| **9. Architecture Decisions** | `docs/adr/` (ADR-0000 … ADR-577) | Log of architectural decision records (MADR format) |
| **10. Quality Requirements** | `docs/arch/ARCH-58-sre-quality.md`, `docs/guides/GUIDE-58-seven-quality-gates.md` | Quality tree, scenarios, concrete verification metrics |
| **11. Risks & Technical Debt** | `docs/arch/ARCH-57-impermanence-storage.md`, `ROADMAP.md` | Known technical debt, mitigations, migration roadmaps |
| **12. Glossary** | `docs/INDEX.md`, `docs/repository.yaml` | Terminology, abbreviations, ubiquitous language |

### C4 Diagram Abstractions (`C4-PlantUML`)
- **Context:** Host (`mediahost`) · WAN / Cloudflare · Client — plus the `_1`/`_2` ingress and boundary controls.
- **Container:** NixOS host · systemd service daemons · Caddy ingress · `systemd-creds`.
- **Component:** `lib/service-factory.nix`, `lib/registry.nix`, `51-ingress`, `59-guardrails`.
- **Code:** Used surgically only where complex logic warrants it (e.g. assertion chains in `591-cross-domain.nix`).

---

## A2. ISO/IEC 25010 + Quality Attribute Scenarios

**ISO/IEC 25010** defines standard quality axes; **Quality Attribute Scenarios (QAS)**
make them measurable and testable with concrete target values.

### Axis Mapping

| ISO/IEC 25010 Quality Axis | mediNix Target Promise | Concrete Verification & Evidence |
|---|---|---|
| **Maintainability / Understandability** | "Recognition without looking up" | ADR-0000 §10, `docs/INDEX.md` |
| **Reliability / Fault Tolerance** | "Fail-closed", compile-time enforcement | `AGENTS.md`, `config.assertions`, `59-guardrails` |
| **Maintainability / Modularity** | "Dendritic modules", drop-a-file simplicity | `GUIDE-50-dendritic-modularization.md` |
| **Security / Confidentiality** | Tri-state boundary, no `mkForce`, UPG isolation | `docs/NO-CONTAINERS.md`, ADR-0000 §4 |
| **Portability** | Zero hardcoded IP addresses or hostnames | `AGENTS.md` (knock-out criterion) |
| **Operational Transferability** | Zero containers, 100% native systemd units | `docs/NO-CONTAINERS.md` |

### Quality Attribute Scenarios (Source · Stimulus · Artifact · Environment · Response · Measure)

- **QAS-1 (Maintainability):** *New agent or engineer* reads `docs/INDEX.md` → searches for canonical service spec → **navigation completes in ≤ 2 hops without prior chat history**. Evidence: `llm-index.json`.
- **QAS-2 (Reliability):** *Host configuration* introduces an invalid or unsafe override (`mkForce`) → NixOS build evaluation aborts immediately → **0 unprotected or broken configurations reach deployment**. Evidence: `config.assertions`.
- **QAS-3 (Security):** *Attacker or untrusted network node* attempts to connect to an internal service port from WAN → ingress firewall and loopback binding reject traffic → **0 internal service ports exposed outside the ingress boundary**. Evidence: `52-security`, `51-ingress`.
- **QAS-4 (Portability):** *Target host hardware* adopts the module set → module evaluation succeeds without manual source edits → **0 host-specific hardcoded IPs or hostnames in `mediNix-core`**.

---

## A3. STRIDE + LINDDUN — Threat Modeling

Every security component in the `_2` slot (security) and `_1` slot (ingress) maps to
concrete threat classes under the **STRIDE** model.

| System Element | STRIDE Category | Threat Description | Architectural Mitigation (Evidence) |
|---|---|---|---|
| **Caddy Ingress (511)** | **S**poofing | Forged host header or unauthorized routing bypass | Enforced forward-auth subrequest, ADR-511 |
| **Pocket-ID (512)** | **S**poofing | OIDC token forgery or replay attack | Strict RS256/EdDSA signature check, ADR-512 |
| **Pocket-ID (512)** | **I**nformation Disclosure | Identity metadata or claim leakage | LINDDUN privacy audit (minimal claim scoping) |
| **Cloudflare DNS (513)** | **T**ampering | DNS response manipulation / cache poisoning | DNSSEC validation, ADR-513 |
| **VPN Killswitch (526)** | **I**nformation Disclosure | Routing leak / raw IP exposure during VPN down | Fail-closed routing table & nftables killswitch, ADR-526 |
| **systemd-creds (521)** | **I**nformation Disclosure | Secrets exposed in cleartext Nix store | Invariant check: rejection of `/nix/store/` prefixes, ADR-521 |
| **Landing Page (518)** | **R**epudiation | Unlogged unauthorized access attempts | Structured audit logging to systemd journal, ADR-518 |
| **Attack Surface** | **D**enial of Service | Host boots without network or unhandled crash loop | `584-post-boot-watchdog`, `583-runtime-guard` |
| **All Services** | **E**levation of Privilege | Compromised daemon breaks into host root or peer state | User Private Groups (UPG) + systemd sandbox directives (ADR-52) |

### LINDDUN (Privacy Framework for Identity Services)
- **L**inking / **I**dentifying / **N**on-repudiation / **D**etecting / **D**ata disclosure / **U**nawareness / **N**on-compliance:
  Audited regularly to ensure Pocket-ID issues strictly minimal OIDC scopes and claims to consuming media daemons.

---

## A4. Design by Contract + Fitness Functions

Architecture rules in mediNix are not passive guidelines; they operate as executable **fitness functions**
enforced through **Design by Contract**:
- **Preconditions:** Option schemas in `default.nix` validating caller input types and constraints.
- **Invariants:** `config.assertions` in `591-cross-domain.nix` evaluated at Nix instantiation time (e.g., UPG isolation, unprivileged port theorem, secret boundaries).
- **Postconditions:** Verification checks in `flake.nix` (`decimalFrameworkCheck`, `nixosConfigurations.check`) and integration tests in `tests/smoke-test.nix`.

### Property-Based Testing Specification

The core invariants are proven over the entire valid service domain $S_{\text{valid}}$, defined as:

$$S_{\text{valid}} = \{100H + 10D + S \mid H \in \{1..9\}, D \in \{1..8\}, S \in \{1..9\}\}$$

*(Note: Foundation decade $D=0$ and block roots $S=0$ are reserved for structure/documentation; guardrails decade $D=9$ is reserved for policy assertions).*

The following formal properties hold for every valid service slot $n \in S_{\text{valid}}$:

1. **Port Derivation & Boundary:**
   $$\text{port}(n) = n \times 10 \in [1110, 9890]$$
   $$1023 < \text{port}(n) < 32768$$
   Every derived loopback port is strictly unprivileged ($> 1023$) and comfortably below the Linux ephemeral port threshold ($32768$).

2. **User Private Group (UPG) Process Isolation:**
   $$\text{uid}(n) = \text{port}(n) = n \times 10$$
   $$\text{gid}_{\text{UPG}}(n) = \text{uid}(n)$$
   For any pair of distinct services $a, b \in S_{\text{valid}}$ with $a \neq b$:
   $$\text{uid}(a) \neq \text{uid}(b) \quad \land \quad \text{gid}_{\text{UPG}}(a) \neq \text{gid}_{\text{UPG}}(b)$$
   This guarantees that private state directories (`/var/lib/<service>`) formatted with mode `0750 <uid>:<uid>` cannot be accessed laterally by peer services.

3. **Decoupled Shared Media Access:**
   For daemons requiring shared media access on Tier C storage (`/data/media`):
   $$\text{gid}_{\text{supplementary}}(n) = H \times 1000$$
   Shared storage access is granted exclusively through `SupplementaryGroups = [ "media" ]` (GID 5000), keeping primary groups isolated.

---

## A5. Diátaxis — Separating Documentation Types

The mediNix documentation tree separates documentation by user intent according to **Diátaxis**:

| Diátaxis Type | User Question | mediNix Directory |
|---|---|---|
| **Tutorial** | "How do I get started?" | `docs/learn/` |
| **How-to Guide** | "How do I solve a specific operational task?" | `docs/guides/` |
| **Reference** | "What are the exact facts and schemas?" | `docs/patterns/`, `docs/adr/`, `docs/repository.yaml` |
| **Explanation** | "Why is the system designed this way?" | `docs/concepts/`, `docs/arch/` |

**Demarkation Rule:** **arc42** structures the formal system architecture, while **Diátaxis** organizes user- and developer-facing documentation folders.

---

## A6. Architectural Open Decisions & Roadmap

1. **Diagram Pipeline:** Evaluate rendering C4-PlantUML diagrams via GitHub Actions workflow or embedding SVG artifacts directly.
2. **Property Test Implementation:** Benchmark evaluating property checks in pure Nix evaluation (`lib/registry.nix`) versus an automated test script (`tests/verify_properties.py`).

---

## B1. Migration Anchors — The Renumbering Strategy

The migration of services, modules, and documentation to the decimal framework follows established
evolutionary architecture patterns:

| Migration Anchor | Formal Strategy | Concrete Application in mediNix |
|---|---|---|
| **Strangler Fig** | Replace old components incrementally | Old numbers and routes remain aliased until all references migrate |
| **Mikado Method** | Graph prerequisites before refactoring | Test renames against `generate_index.py` and `flake.nix` before committing |
| **Walking Skeleton** | Prove end-to-end flow with one slice | One module family (e.g. `532-sonarr`) completely refactored before scaling |
| **Thin Vertical Slice** | Domain-by-domain migration | Migrate `51-ingress` fully, verify green CI, then proceed to `52-security` |
| **Spike Solution** | Timeboxed proof-of-concept | Evaluate isolated features in scratch branches before architectural adoption |
| **Hemingway Bridge** | Leave clear handover status | Maintain progress and blockers in `.agent-state.json` and `CHANGELOG.md` |

**Fail-Closed Migration Rule:** Every migration increment must exit cleanly (`nix flake check` exit code 0) before the next increment is started.

---

## B2. Process & Quality Anchors

- **Conventional Commits:** All changes follow `<type>(<scope>): <summary>` format (e.g., `feat(hardening):`, `docs(adr):`).
- **GitHub Flow:** Trunk-based development on `main` with automated CI verification on every pull request and push.
- **Definition of Done (`[A]/[T]/[M]`):**
  - `[A]` **Assertion:** Invariant enforced at Nix evaluation time.
  - `[T]` **Test:** Automated test passing in CI (`smoke-test`, `flake check`).
  - `[M]` **Manual:** Human verification required only for physical hardware interactions.
- **Semantic Versioning (SemVer):** The module interface maintains strict compatibility guarantees according to `MAJOR.MINOR.PATCH`.

---

## B3. Technical Writing & Documentation Anchors

- **BLUF (Bottom Line Up Front):** Every ADR and architecture document begins with the core decision summary in a callout banner.
- **Pyramid Principle (Minto):** Conclusion and decision first, followed by structural proofs and supporting evidence.
- **Simplified Technical English (ASD-STE100):** Assertion messages follow the strict `What / Why / Fix` three-part pattern in clear imperative sentences.
- **Inverted Pyramid:** Changelog entries lead with the most critical breaking changes and operational impacts.

---

## B4. Knowledge & Theory Building Anchors

- **Mental Model & Theory Building (Peter Naur):** Programming is theory building; code is only the ephemeral artifact of the theory shared by the developers and agents. The decimal framework constitution is the explicit embodiment of this theory.
- **Progressive Disclosure:** Information is tiered from high-level summaries (`INDEX.md`) down to granular module-specific specifications (`AGENTS.md`, SKILL files).
