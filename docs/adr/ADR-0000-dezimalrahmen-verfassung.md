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

So `532` reads as: `5` (namespace: project mediNix) · `3` (decade: Ingestion / Acquisition) · `2` (leaf: second service, Sonarr).

---

## 2. The Structural Boundary Slots (`_0`, `_1`, `_2`, `_9`)

Four boundary slots frame every project and system root identically:

| Slot | Role | Question | Content & Daemon Invariant |
|---|---|---|---|
| **`_0`** | **Foundation** | What do we work with? | `CLAUDE.md`, options `default.nix`, `lib/decimal-framework.nix`, `registry` — **strictly structure & engine, NEVER daemons** |
| **`_1`** | **Access** | How do you get in? | Reverse proxy (Caddy), DNS, ACME, IdP (Pocket-ID), mDNS, edge defenses |
| **`_2`** | **Security** | How is it protected? | Host firewall (`nftables`), VPN killswitch, `systemd-creds` |
| **`_9`** | **Guardrails** | What must everything comply with? | Compile-time assertions (`config.assertions`), global invariants — **NEVER daemons** |

**`_1`/`_2` boundary:** `_1` governs **the entire ingress and access path** — proxy, IdP, DNS, ACME, mDNS, and edge defenses. `_2` protects **the host and egress boundary** — sealed credentials, VPN confinement, host firewall, kernel hardening.

---

## 3. Universal Functional 10-Slot Taxonomy (`_0` to `_9`)

There is **no arbitrary "free middle"**. Across every project in the cosmos (`mediNix`, `devNIX`, `40-documents`), all ten decades (`_0` through `_9`) follow a strict, universal functional pipeline from input to observability and guardrails:

| Slot | Canonical Role | Universal Function | Example: `mediNix` (`5x`) | Example: `devNIX` (`8x`) | Daemons Allowed? |
|---|---|---|---|---|---|
| **`_0`** | **Foundation** | Structure, Engine, Registry, Docs | `50-core` (Baseline, Engine) | `80-core` (Agent Constitution) | **NO** (`decade != 0`) |
| **`_1`** | **Access** | Ingress, Reverse-Proxy, DNS, IdP, mDNS | `51-ingress` (Caddy, Pocket-ID) | `81-ingress` (Gateway, Auth) | YES (`H11`–`H19`) |
| **`_2`** | **Security** | Host-Firewall, nftables, VPN-Killswitch, Creds | `52-security` (Creds, Killswitch) | `82-security` (Sandboxes, Keys) | YES (`H21`–`H29`) |
| **`_3`** | **Ingestion** | Input, Sources, Indexers, Scanners, Acquisition | `53-acquisition` (Sonarr, Radarr, Prowlarr) | `83-ingestion` (Repo Harvesters, RAG) | YES (`H31`–`H39`) |
| **`_4`** | **Processing** | Transformation, Download Processing, Mover, Build | `54-transfer` (SABnzbd, Storage Mover) | `84-processing` (AST Parsers, Pipelines) | YES (`H41`–`H49`) |
| **`_5`** | **Core UI / App** | **Primary Purpose of the Flake** | `55-playback` (Jellyfin, ABS, Navidrome) | `85-workspace` (OpenCode, Editor, UI) | YES (`H51`–`H59`) |
| **`_6`** | **Exposition** | Request Catalogs, API Gateways, External Delivery | `56-anfragen` (Seerr `561`) | `86-exposition` (MCP Servers, Webhooks) | YES (`H61`–`H69`) |
| **`_7`** | **Maintenance** | Backup (Restic), SQLite-WAL, GC, Storage-Tiering | `57-maintenance` (Restic, Provisioning, WAL) | `87-maintenance` (State GC, Index Sync) | YES (`H71`–`H79`) |
| **`_8`** | **Observability** | Monitoring, Push-Alerts, Telemetry, Health | `58-observability` (Ntfy `581`, Gatus `582`) | `88-observability` (Telemetry, Token Logs) | YES (`H81`–`H89`) |
| **`_9`** | **Guardrails** | Compile-Time Assertions, Global Invariants | `59-guardrails` (`591-cross-domain.nix`) | `89-guardrails` (Schema & AST Gates) | **NO** (`decade != 9`) |

Unoccupied slots remain empty reserves; they are never repurposed for unrelated functions.

---

## 4. Derivations & User Private Groups (UPG)

**The sole source of derivation is the three-digit service number** (`HDS`: project · decade · service, where $H \in [1..9]$, $D \in [1..8]$, $S \in [1..9]$).

| Quantity | Formula | Example: `sonarr` (`532`) | Band | Purpose & Isolation Boundary |
|---|---|---|---|---|
| **Port** | $\text{num} \times 10$ | `5320` | `Hxx0` | Internal HTTP loopback / upstream binding |
| **UID** | $\text{num} \times 10$ | `5320` | `Hxx0` | Dedicated process execution user |
| **Primary GID (UPG)** | $\text{num} \times 10$ | `5320` | `Hxx0` | User Private Group for `/var/lib/<name>` (`UMask 0027`) |
| **Shared GID** | $\lfloor\text{num} / 100\rfloor \times 1000$ | `5000` | `H000` | Shared storage group (`SupplementaryGroups` only!) |
| **State Directory** | `"/var/lib/${name}"` | `/var/lib/sonarr` | — | Clean canonical state path without port suffixes |
| **Decade Role** | $\lfloor\text{num} / 10\rfloor \bmod 10$ | `3` (Ingestion) | `0..9` | Programmatic role classification |

### UPG Security Contract
- **Primary Group = UID = `num × 10`:** Every daemon runs under its own User Private Group (`users.groups.${name}.gid = spec.primaryGid`) with `UMask = "0027"` and `StateDirectory = name`. No service can read another service's `/var/lib/<name>` directory.
- **Shared Group `H000` (`5000 media`) as Supplementary Group:** Assigned exclusively via `extraGroups = [ "media" ]` to services that require Tier C media access (`needsSharedGroup` / `needsMediaGroup`). Edge ingress (`511-caddy`) and identity (`512-pocket-id`) never receive GID `5000`.

### Hard Engine Invariants (`lib/decimal-framework.nix`)
1. **I1 (Three-Digit Range):** $100 \le \text{num} \le 999$.
2. **I2 (No Decade Zero-Slot Daemons):** $\text{num} \bmod 10 \neq 0$ (`HD0` is reserved for block IDs).
3. **I3 (No Foundation Daemons):** $\lfloor\text{num} / 10\rfloor \bmod 10 \neq 0$ (`_0` never spawns daemons).
4. **I4 (No Guardrail Daemons):** $\lfloor\text{num} / 10\rfloor \bmod 10 \neq 9$ (`_9` is build-time evaluation only).

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

## 6. System Root Alignment

```
00-core            _0  Foundation
10-network         _1  Access
20-security        _2  Security
30-storage         _3  Ingestion / Data Pools
40-documents       _4  Processing / DMS
50-mediNix         _5  Core Media Appliance
60-exposition      _6  External Gateways
70-maintenance     _7  Lifecycle & Backups
80-devNIX          _8  Observability & Agentic Tooling
90-policy          _9  Guardrails
```

---

## 7. Example: Document Appliance (`40-documents`, `H = 4`, Shared GID `4000`)

```
40-core            _0  Foundation (options, registry)
41-ingress         _1  Access (Caddy, SSO)
42-security        _2  Security (nftables, creds)
43-ingestion       _3  Mail & Scanner Consumers (431)
44-processing      _4  OCR & Tika/Gotenberg Pipelines (441, 442)
45-archive         _5  Paperless-ngx Core UI (451 -> Port/UID/GID 4510)
46-exposition      _6  Public Share Links / API Gateways (461)
47-maintenance     _7  Restic A2 Backup & SQLite-WAL (476)
48-observability   _8  Gatus & Ntfy Health Checks (481, 482)
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
| **StateDirectory with port suffix (`name-port`)** | Broke NixOS upstream expectations and complicated path references; replaced by canonical `/var/lib/${name}`. |
| **Level-3 folder graduation (4-digit folders)** | Collided with the 4-digit Port/UID space; module hierarchy is strictly a two-level tree. |
| **Daemons in `_0` or `_9`** | `_0` is foundation/options and `_9` is compile-time assertions; neither may spawn runtime services. |

---

## 10. Consequences

- **Predictable Cross-Project Navigation:** Every decade (`_0` to `_9`) has the exact same functional role across all repositories.
- **Strict State Isolation:** UPG (`GID = UID = ID * 10`) with `UMask = 0027` seals `/var/lib/<name>` against peer processes while preserving shared Tier-C access via supplementary group `H000`.
- **Compile-Time Enforcement:** Invalid service numbers or forbidden daemon decades (`_0`, `_9`, `HD0`) fail immediately during Nix evaluation.

---

## 11. Semantic Anchors

| Principle in the Document | Methodological Standard |
|---|---|
| Single number derives Port, UID, UPG-GID, Shared-GID (§4) | **SSOT** — Single Source of Truth |
| Engine invariants I1–I4 in `lib/decimal-framework.nix` (§4) | **Design by Contract** (Meyer) |
| Universal 10-slot taxonomy `_0`..`_9` (§3) | **MECE** — Mutually Exclusive, Collectively Exhaustive |
| UPG primary group vs. supplementary storage group (§4) | **Principle of Least Privilege (PoLP)** |
| Recognizability across repos (§3, §10) | **ISO/IEC 25010** — Maintainability (*Analyzability* & *Modularity*) |
| Rejected alternatives table (§9) | **MADR Exclusion Log** |

---

## 12. Appendix & Architecture Decoupling

The methodological and cross-cutting architectural specifications (Stages 2 & 3) live in:
- **[ARCH-0000 — Decimal Framework Appendix](file:///home/moritz/repos/mediNix-core/docs/arch/ARCH-0000-framework-appendix.md)**
