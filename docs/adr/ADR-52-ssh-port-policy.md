---
id: "ADR-52-ssh-port-policy"
title: "ADR 5200 ssh port policy"
domain: 52
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - policy
  - security
  - ssh
links:
  adr: ""
  repo-harvest: ""
---
# ADR-21: SSH Port Policy — canonical port 22

## Status
Active (supersedes any earlier "high-port SSH" guidance, e.g. port 53844).

## Context
An earlier draft migrated SSH to a non-standard high port (53844) on the belief
that obscurity adds security. This was rejected: high-port SSH is **security
theatre** — it provides no real protection (any scanner finds the port), only
obscurity, and it breaks the documented contract that tooling and operators rely
on. It also fragmented the config: the firewall (523), the sshd module (525) and
the backup daemon (594) all had to agree on a magic number.

## Decision
- **Primary SSH port is 22.** This is the canonical, expected port.
- **Backup SSH daemon runs on 2222** (Dropbear / stage-2 rescue path), key-only.
- **Migrating SSH off port 22 is forbidden** and enforced by a build assertion in
  `525-ssh-antilockout.nix` (`assertion = cfg.port == 22`).
- Real hardening comes from: key-only auth, `Match Address` LAN restriction,
  nftables allow-list, and the out-of-band backup daemon — **not** from a hidden
  port.

## Consequences
- Operators must not set `medinix.ssh.port` to anything but 22. The build
  fails loudly with a precise message if they try.
- 523 / 525 / 594 stay in lock-step on ports `[22, 2222]`.
- 595-ssh-assertions guards all three paths (primary sshd up, port 22 in
  allowedTCPPorts, password auth off, backup daemon running).

## Verification
- `grep -rn "53844" --include="*.nix" .` must return only documentation text,
  never a live port assignment.
- Build assertion in 525 fires if `cfg.port != 22`.
