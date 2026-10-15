---
id: "0000"
title: "Decimal Framework — the Constitution of the Numbering Scheme"
domain: 00
status: active
complexity: 2
last_reviewed: 2026-10-14
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
> by `decimalFrameworkCheck` and `lib/decimal-framework.nix`; this document carries the rationale.
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

---

## 2. The Structural Boundary Slots (`_0`, `_1`, `_2`, `_9`)

Four boundary slots frame every project and system root identically:

| Slot | Role | Question | Content & Daemon Invariant |
|---|---|---|---|
| **`_0`** | **Foundation** | What do we work with? | `CLAUDE.md`, options `default.nix`, `lib/decimal-framework.nix`, `registry` — **strictly structure & engine, NEVER daemons** |
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

### Hard Engine Invariants (`lib/decimal-framework.nix`)
1. **I1 (Three-Digit Range):** $100 \le \text{num} \le 999$.
2. **I2 (No Decade Zero-Slot Daemons):** $\text{num} \bmod 10 \neq 0$ (`HD0` is reserved for block IDs).
3. **I3 (No Foundation Daemons):** $\lfloor\text{num} / 10\rfloor \bmod 10 \neq 0$ (`_0` never spawns daemons).
4. **I4 (No Guardrail Daemons):** $\lfloor\text{num} / 10\rfloor \bmod 10 \neq 9$ (`_9` is build-time evaluation only).

### Role Declaration (Recommended, Never Prescriptive)
Declaring an optional `role` string in the service manifest (e.g. `role = "media-server"`) is recommended as best practice to document the functional intent beyond the numeric slot. The field is purely descriptive and has **no impact on Port, UID, or GID derivations**. If declared, it must not be an empty string (`assertion = role != ""`).

### Linux Capabilities (Operator / Host Boundary)
Linux capabilities are an operational decision of the host system and are **never derived from numbers**.
- **Validation only, no automatic injection:** The engine validates declared capabilities against a strict compile-time whitelist (`allowedCapabilities = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ]`). **It does not inject them into systemd unit configs.** Each service module requiring ambient capabilities must explicitly configure them in its own `serviceConfig.AmbientCapabilities`.
- **Root Capability Defense:** Dangerous root capabilities (`CAP_SYS_ADMIN`, `CAP_SYS_RAWIO`, `CAP_SYS_MODULE`, `CAP_SETPCAP`, `CAP_SETUID`, `CAP_SETGID`, `CAP_CHOWN`, `CAP_NET_BROADCAST`) are strictly forbidden and trigger immediate build failure.

---

## 5. The Structural Proofs

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
| Engine invariants I1–I4 in `lib/decimal-framework.nix` (§4) | [**Design by Contract** (Meyer)](../anchors/design-by-contract.md) |
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

> **Protocol over Product:** Der Slot wird anhand der Rolle vergeben, nicht anhand der Software.

---

## 12. Appendix & Architecture Decoupling

The methodological and cross-cutting architectural specifications (Stages 2 & 3) live in:
- **[ARCH-0000 — Decimal Framework Appendix](file:///home/moritz/repos/mediNix-core/docs/arch/ARCH-0000-framework-appendix.md)**
