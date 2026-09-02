# ADR-5260 — Killswitch observability before change

Status: accepted
Date: 2026-09-02
Source: former `audits/mediNix-Architektur-Abschluss.md`

## Decision

526 is the enforcement layer. Counters and 583 nft/ss checks exist to *measure* the chain before anyone edits marks or allow-lists.

Do not widen RFC1918/ULA/loopback allows into WAN. Do not treat 583 as a substitute for 526.
