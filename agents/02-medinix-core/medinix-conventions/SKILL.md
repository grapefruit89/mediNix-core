---
name: medinix-conventions
description: mediNix boilerplate rules - repo docs SSoT.
---

# mediNix Boilerplate Conventions

Durable operating conventions for `/opt/data/50-mediNix` (the mediNix media-PC
boilerplate). Read before adding/refactoring modules.

## When memory is full → write to the REPO, not memory
The agent's long-term memory caps at ~20k chars and fills up. When it is near
full, do NOT force durable project facts into memory. Instead write them as
**ADRs / docs into `/opt/data/50-mediNix/docs/`** (Schema V6 YAML frontmatter).
This is the project's SSoT for decisions and is reviewable months later.
- ADR filenames follow the **decimal-framework prefix**: `ADR-<DOMAIN><NN>-<slug>.md`.
  First 1–2 digits = decimal-framework domain, remaining digits = sequence counter.
  Mapping (confirmed this session):
  - 20 = network (`ADR-21` SSH port policy)
  - 50 = 50-core / architecture (`ADR-5001` secret-management)
  - 51 = ingress (`ADR-51xx`)
  - 52 = security (`ADR-52xx`)
  - 53 = acquisition (`ADR-53xx`)
  - 54 = transfer / VPN (`ADR-5401` SABnzbd-VPN confinement)
  - 55 = playback (`ADR-55xx`)
  - 57 = maintenance (`ADR-5701` SQLite-WAL tuning)
  - 59 = guardrails (`ADR-5043` assertion-quality)
  NOTE: `ADR-5043` predates the strict split and uses 50xx for a guardrail — keep it,
  never renumber an existing ADR after the fact.
- Keep a `docs/INDEX.md` listing all ADRs (ID / Title / Status columns).
- Reference impl: `ADR-21-ssh-port-policy.md`, `ADR-5043-assertion-quality.md`,
  `ADR-5000-secret-management.md`, `ADR-5410-sabnzbd-vpn-confinement.md`,
  `ADR-5700-sqlite-wal-tuning.md`, `ADR-5520-audiobookshelf-port-framework.md`.

## Decimal framework = SSoT in registry + factory (NO redundant modules)
Ports/UIDs/services are defined ONCE in `lib/registry.nix` and instantiated by a
factory (e.g. `53-acquisition/default.nix` `mkArrService`).
- **Do NOT create per-service modules that duplicate what the factory already
  generates** (e.g. 532-sonarr/533-radarr/... as standalone files when the
  registry already lists them). That violates SSoT — they had to be deleted
  (532-535 were created then removed this session).
- New port/UID only means: add one line to `registry.nix`. The factory +
  `default.nix` pick it up. If bespoke logic is needed, extend the factory.

## ⚠ ADR-0000 (Dezimalrahmen-Verfassung) is the AUTHORITATIVE source for ALL numbering
Read `/opt/data/50-mediNix/docs/ADR-0000-dezimalrahmen-verfassung.md` before assigning
any port/UID/GID or ADR prefix. ADR-5043 is real but ADR-0000 supersedes it as the
constitution. Rules that MUST be obeyed (violations cause hard rework):
- **ONLY the 3-digit service number derives.** Port = Nummer × 10, UID = Nummer × 10,
  GID = Projekt × 1000. The last digit of a 3-digit number is the service ROLE
  (N1–N9) — never a free zero, so a service number can only end in 1–9.
- **2-digit (root slots) and 4-digit (Ebene-3) numbers derive NOTHING.** A 4-digit
  number like "5055" is INVALID as a port — there is no "5055" service. If chat/export
  text contains a 4-digit number that looks like a port, treat it as an ERROR, not a fact.
- **Container levels** (decade/domain/folder) carry the 4 anchors: `_0` Fundament,
  `_1` Zugang, `_2` Sicherheit, `_9` Leitplanken. **Leaf levels** (Dienst) carry only
  N0 (Block-ID) + N1–N9 (Dienste); anchors do NOT apply on leaf levels.
- Isomorphism = everything derived from the ONE 3-digit number, each quantity
  transformed appropriately (Port ×10, UID ×10, GID ×1000) — NOT "all numbers equal".

## Confirmed service → port/UID/GID/ADR map (mediNix = 50, GID 5000, UID/Port 5xx0)
| Service | Dienstnummer | Port | UID | GID | ADR |
|---------|-------------|------|-----|-----|-----|
| Caddy (Reverse-Proxy, _1 Zugang) | **511** | **5110** | 5110 | 5000 | ADR-5110 |
| Pocket ID (OIDC) | **512** | **5120** | 5120 | 5000 | ADR-5120 |
| SABnzbd | 541 | 5410 | 5410 | 5000 | ADR-5410 |
| Sonarr | 532 | 5320 | 5320 | 5000 | ADR-5320 |
| Jellyfin | 551 | 5510 | 5510 | 5000 | ADR-5510 |
| Audiobookshelf | 552 | 5520 | 5520 | 5000 | ADR-5520 |
| Navidrome | 553 | 5530 | 5530 | 5000 | ADR-5530 |
| Jellyseerr | 561 | 5610 | 5610 | 5000 | ADR-5610 |
**Rule:** Port = UID = ADR-prefix (all = Dienstnummer × 10). GID = 5000 for ALL
(unshared per-service GID = docker PUID/PGID permission-denied bug). 
**CRITICAL:** `511` is CADDY (the `_1` Zugang). Pocket ID is the SECOND service in the
ingress decade → `512` → 5120. Never assign 511 to anything but Caddy.
Each service gets its OWN ADR (ADR-51x0, ADR-5xx0) — fully populated, not just a map row.

## ADR filename prefixes follow the framework
- SCHICHT-BASIS ADRs use Ordner00: `ADR-5000` (50-core), `ADR-5700` (57-maintenance).
- SERVICE ADRs use the service PORT (= Dienstnummer × 10). NO LAUFNUMMERN.
  SABnzbd → `ADR-5410`, Audiobookshelf → `ADR-5520`, Pocket ID → `ADR-5120`.
  A previous version used `ADR-5501`/`ADR-5001` (running numbers) — those are
  INVALID and were RENAMED to the decimal-framework port. NEVER use a running
  number like `ADR-0050`, `ADR-5001`, `ADR-5501` — the number IS the port.
- Do NOT renumber an existing ADR after the fact (except to fix a prior violation).

## SSH port is 22 (canonical) — 53844 is deprecated
High-port SSH (53844) is security theatre / obscurity, explicitly rejected.
See `docs/ADR-21-ssh-port-policy.md` and the build assertion in
`52-security/525-ssh-antilockout.nix`. Never migrate SSH off 22.

## Assertion messages must be human+LLM readable
Every `assertions` entry needs tag/what/why/fix. See the dedicated
`medinix-assertion-quality` skill and `docs/ADR-5043-assertion-quality.md`.

## Every .nix file needs a NIXMETA v3.0 header
See `nix-metadata-header` skill. 39/39 files already carry it.

## Enriching modules from the vector store
To pull gold standards for a layer (e.g. 520/530) from the unified store, query
`vec-mcp` programmatically. The client must handle StreamableHTTP session ids —
see `references/query-vector-store.md`.

## Pitfalls
- Don't write durable facts to memory when it's >95% full — use repo docs.
- Don't hand-build per-service modules the registry+factory already cover.
- Don't "fix" the SSH port to a high number — 22 is correct, 53844 deprecated.
- **NEVER derive a port from a 4-digit number** (e.g. "5055" from chat) — only the
  3-digit service number derives (×10). 4-digit = invalid, treat as error.
- **511 is Caddy.** Never assign 511 to Pocket ID (or any other service). Pocket ID = 512.
- **Don't put anchors on leaf-level service numbers** (e.g. "531 = Zugang der
  Beschaffung" is nonsense — anchors live on container decades only).
- When extracting "ports" from chat/export text, cross-check against ADR-0000's map
  before writing them as fact. Chat authors guess numbers; the Verfassung is truth.
- Verfassung detail bank: `../../shared/references/dezimalrahmen-adr-0000.md`.
- Robust long-running job pattern (setsid + PID-file, no pkill self-match):
  `references/robust-long-job-wrapper.sh` — use for any multi-hour Tower build.
