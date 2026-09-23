---
schema_version: "1.0"
id: medinix-authoring
name: medinix-authoring
metadata:
  title: mediNix Authoring
version: "1.0"
status: active
layer: agent
domain: authoring
summary: >
  Build, name and document modules the mediNix way: decimal framework, NIXMETA, triangulated research.

description: >
  How to build, name and document mediNix-core modules: the decimal framework (number = identity, derivations, anchors, container vs leaf slots), dendritic structure, NIXMETA headers, hardening-profile rules, and the triangulated research flow (mediNix implementation vs nixpkgs NixOS module vs service upstream). Use when creating, renaming or integrating any .nix module or service in mediNix-core.

purpose:
  - "Apply the decimal framework (identity, derivations, anchors, leaf vs container)."
  - "Produce NIXMETA-complete modules and triangulate each service against nixpkgs and upstream."

when_to_use:
  - "Creating, renaming or integrating any .nix module or service."
  - "Adding a service slot: port, UID/GID, registry entry, NIXMETA header, hardening profile."

when_not_to_use:
  - "Reviewing an existing diff for defects — that is medinix-review's job."
  - "Generic Nix syntax questions — medinix-nix's job."

inputs:
  - "The service/package intent, plus docs/repository.yaml as the per-service research index."

outputs:
  - "A NIXMETA-complete module consistent with registry and hardening profiles."

authority:
  local:
    - "AGENTS.md"
    - "mediNix architecture"
    - "Decimal System (ADR-00)"
    - "NIXMETA"
    - "lib/creds.nix"
    - "lib/hardening-profiles.nix"

  external:
    - "Service upstream docs"
    - "NixOS/nixpkgs module sources"

  rule: >
    Local mediNix architecture and explicit project invariants take precedence over external patterns.

research:
  upstream:
    repo: null
    docs: null
    api: null
  nixpkgs:
    package: null
    module: null
    tests: null
  reference:
    repos:
      - https://github.com/librephoenix/nixos-config
      - https://github.com/vimjoyer/flake-starter-config
      - https://github.com/ChrisTitusTech/nixos-titus
      - https://github.com/ironicbadger/infra
  context7:
    enabled: false
    library_id: null

related:
  skills: [medinix-nix, medinix-review]
  tools: [medinix-meta-check, medinix-meta-docs]
  files: [lib/registry.nix, lib/service-factory.nix, lib/hardening-profiles.nix, lib/creds.nix, docs/repository.yaml]

invariants:
  - "Port = UID (decimal slot number x10); GID = project slot x1000 (shared group 'media')."
  - "Slot 534 is retired and reserved — never reassign."
  - "ADR-5050: systemd-native only; Docker-first patterns rejected."
  - "NIXMETA header required with id, provides, requires, status."

verification:
  required:
    - "medinix-meta check (graph) exits green."
    - "check-docs exits green after generate-docs."

  preferred:
    - "nix flake check on a Nix-equipped host."

change_policy:
  scope: surgical
  avoid:
    - "Unrequested abstraction."
    - "Unrelated refactoring."

  deletion_over_addition: true

output_contract: "PLAN / EXECUTE / VERIFY / RESULT / OPEN"

notes:
  []

---

# mediNix Authoring — Building Modules the mediNix Way

## Purpose

This skill defines how modules are created, numbered, hardened and documented
in mediNix-core.

It does not replace the constitution (`docs/adr/ADR-0000-dezimalrahmen-verfassung.md`),
the registry (`lib/registry.nix`), the architectural law (`50-core/MANIFEST.md`),
or objective verification (`medinix-verify` / flake checks).

## 1. The decimal framework — number = identity

A module number is not a filename. It is the module's identity:

```
551
├── Module identity          (551-jellyfin.nix)
├── Port / UID derivation    (5510)
├── Registry entry           (lib/registry.nix)
├── Documentation            (generated AGENTS.md, docs/)
├── ADR assignment           (ADR-55xx)
├── Service upstream         (docs/repository.yaml)
└── NIXMETA header
```

**Derivations** come exclusively from the three-digit service number
(project · decade · service). Two-digit root slots and four-digit Level-3
numbers derive nothing — they number structure, not services.

| Size  | Rule            | sonarr (532) | Shared?                     |
|-------|-----------------|--------------|-----------------------------|
| Port  | number × 10     | 5320         | —                           |
| UID   | number × 10     | 5320         | individual (process isolation) |
| GID   | project × 1000  | 5000         | shared across the project   |

UID == Port is deliberate isomorphism. The GID is shared so services can read
each other's files; an individual GID per service would recreate the Docker
PUID/PGID permission mistake. Derived values come from the registry — never
hardcoded.

**Anchors** (apply to container slots, not leaf slots):

| Slot | Role        | Content                                      |
|------|-------------|----------------------------------------------|
| `_0` | Foundation  | knowledge and structure — `default.nix` options API, docs, registry. No services, no daemon, no systemd unit |
| `_1` | Entry       | reverse proxy, mDNS, routing, auth entry     |
| `_2` | Security    | firewall, TLS, VPN confinement, auth mechanics |
| `_9` | Guardrails  | assertions, bans, global invariants          |

**Leaf slots:** `N0` is the Block-ID (the decade's foundation — never a
program); `N1`–`N9` are services. `532` reads as: project 5 · decade 3
(Acquisition) · second service. Unoccupied middle slots are reserves — the
gap is the information "there is space here". When a slot graduates (gains a
digit), its former leaf slot becomes a container slot and the anchors apply
there again.

## 2. Dendritic, not dogmatic

One program gets its own module point by default. Bündelung (bundling
multiple programs into one module) is allowed only when justified by genuine
domain coupling — and must then be documented. Every `.nix` file is one
module with a flat auto-import; there is no central import list.

## 3. The three questions before implementing

- **A. Dendritic** — is this service independent enough for its own `.nix`?
- **B. Decimal** — where does it belong, and which number does it get
  (from the registry / a free slot in the right decade)?
- **C. Documentation** — can another person understand in 30 seconds what,
  why, and where this service is configured?

Only then comes the Nix implementation.

## 4. Service research triangulation

**Package ≠ NixOS service module ≠ upstream application ≠ NixOS test.**
Four different things, four different sources:

| Source          | nixpkgs path pattern                          | Answers                          |
|-----------------|-----------------------------------------------|----------------------------------|
| Nix package     | `pkgs/by-name/xx/<name>/`                     | how nixpkgs builds/installs the software |
| NixOS module    | `nixos/modules/services/<category>/<name>.nix` (e.g. `misc/servarr/sonarr.nix`) | how it integrates as a declarative NixOS service |
| Application     | the upstream project (`docs/repository.yaml`) | what the software is and needs   |
| NixOS test      | `nixos/tests/<name>/` (optional, when available) | whether the integration actually works |

Caution: a nixpkgs package is **not** automatically "good code to copy" —
it can be historical, minimal, complex, or full of workarounds. It shows how
nixpkgs packages the software, not how mediNix should integrate it.

When implementing or reviewing a service:

1. Inspect the existing mediNix implementation and registry.
2. Inspect the relevant NixOS/nixpkgs module (package and module are
   different things — inspect both when relevant; tests optional but
   valuable when available).
3. Inspect the relevant service upstream project.
4. Inspect reference configurations when useful — extract patterns,
   not files.
5. Compare every proposed pattern against the decimal framework, NIXMETA,
   hardening profiles, portability rules, and the existing architecture.
6. Implement the smallest mediNix-native solution.
7. Document why the chosen structure exists.

The authoritative source routing lives in `docs/repository.yaml` (with the
binding research policy in its header). Reference configs, documentation
sources (Zero to Nix, Context7) and community sources are pattern and
explanation material — they never override mediNix rules.

## 5. Module checklist

For a new service module:

1. Assign the number (free `N1`–`N9` slot in the right decade; registry gets
   the entry first).
2. Write the NIXMETA header (section 6) with `id == filename stem`.
3. Use the `cfg = config.medinix.services.<name>` idiom — not foreign
   namespaces (`my.*`).
4. Hardening exclusively via `lib/hardening-profiles.nix` profiles — never
   isolated security settings scattered in the module.
5. Container/isolation additions must be a LIST inside `mkMerge` (a scalar
   silently overwrites instead of merging).
6. Assertions for the module's invariants (fail closed).
7. Never hardcode derived values (ports, UIDs, GIDs) — take them from the
   registry.
8. Run the metadata check and regenerate docs:
   `python3 50-core/medinix-meta.py check` then `generate-docs`.
9. Verify per `medinix-discipline` §8 / `medinix-verify`.

## 6. NIXMETA header

Required fields (checked by `50-core/medinix-meta.py check`):

```nix
# ---
# id: "532-sonarr"        # MUST equal the filename stem
# title: "..."
# domain: 53
# folder: 53-acquisition
# status: active          # active | template | example | ...
# provides: ["lib/..."]   # what other modules may depend on
# requires: ["lib/..."]   # provider must exist (implicit: every module id provides itself)
# ---
```

Rules:

- `id` equals the filename stem (checker enforces; `-default` suffix exempt).
- `requires` names must be an existing `provides` or module id — otherwise
  the check fails with a deadlink.
- ADR numbers are never "running" counters; reference the ADR in
  `links.adr` only if it exists.
- Optional fields (complexity, last_reviewed, ports, state_dir, nixpkgs_attr,
  upstream_github, …) should be filled when they describe reality — never
  invented.

## 7. Authoring gold (legacy migration 2026-09-16)

- **Auto-import prefix**: maintenance/guardrail modules MUST be named
  `NNN-*.nix` (3 digits, e.g. `578-orphan-cleanup.nix`) so the loader in
  `default.nix` picks them up. An unprefixed file is INERT — not an
  error, just dead code; delete it rather than leave it.
- **ADR filename prefixes follow the framework**: ADR-NNNN mirrors the
  folder (e.g. `ADR-5000` for core, `ADR-5700` for maintenance);
  service ADRs use the service PORT (= Dienstnummer x 10, e.g.
  `ADR-526`), never running numbers like `ADR-5501`.
- **mkArrEnv double-prefix bug**: when flattening a recursive attrset
  to .NET env vars, build the FULL key including the prefix inside the
  recursion (leaf: `"${prefix}__${...}"`) and return it 1:1 — adding a
  second `${prefix}__` around the flattened result produces
  `SONARR__SERVER__PORT`. Verify against
  `templates/arr-settings-example.nix` before applying any snippet.
- **Env-var boundary**: only AppSettings (port, bind address, auth
  method, theme, log level, update mechanism) are env-var configurable.
  Quality profiles, root folders, download clients and indexer apps are
  database entities created via the API — keep their provisioning as
  API calls, do NOT delete it in favour of env vars.

## 8. Where the detail lives

Registry values: `lib/registry.nix` (SSoT). Constitution: `docs/adr/` ADR-00.
Architectural law: `50-core/MANIFEST.md`. Source routing: `docs/repository.yaml`.
Objective proof: `medinix-verify` and the flake checks. Do not duplicate any
of it here.
