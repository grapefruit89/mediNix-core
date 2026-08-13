---
name: medinix-governance
description: "mediNIX governance: SSoT, review scan, unit pitfall."
---

# mediNIX-core Governance & Safe-Change Protocol

Load this for any mediNIX-core task that touches modules, adds features, or reviews a diff.
It encodes three durable rules that are NOT in the module-authoring skills (those are user-owned
and must be `hermes curator adopt`-ed to patch — see bottom).

## Rule 1 — ADMIN-HANDOFF is the ONLY Host-Pflichten file (Single Source of Truth)
- mediNIX-core is a **portable Flake/Module**. Host responsibilities (Binary-Cache, Impermanence,
  Tier-Hardware mounts, VPN-interface, ACME/TLS, TPM-Secrets, SSH/nftables) live **exclusively**
  in `AGMIN-HANDOFF.md` at repo root.
- NO scattered Host hints in AGENTS.md, README, or module comments. If you find one, replace it
  with "siehe ADMIN-HANDOFF.md §X".
- **No q958 / 192.168.x / m7c5.de / privado in `.nix` as defaults or code heuristics.** Examples in
  `default.nix` `example =` fields are allowed BUT must be generic (`"wg0"`, `"example.com"`,
  `[ "10.8.0.1" ]`); the house VPN name `privado` must NEVER appear in code — strip it from any
  grep-heuristic too (e.g. `mediNix-cli` VPN probe was `grep -iE 'privado|wg|vpn'` → reduced to
  `wg|vpn`). `mkOption default =` must never hardcode a host value.
- Flake must evaluate with zero Host assumptions. A new consumer must learn everything they need
  to set on their machine from ADMIN-HANDOFF alone.
- **Host-responsibility list (post Phase 7/8):** Policy-Routing is NOW in the module
  (`526-vpn-policy-routing.nix`, UID tables 5410/5360 + routingPolicyRules + fail-closed
  `unreachable`, mkIf confinement && vpn.interface != ""). Host delivers ONLY: WireGuard interface
  + Keys (secret store), `vpn.interface`, `vpn.dnsServers`, and `sabnzbd.enable`/`prowlarr.enable`.
  ADMIN-HANDOFF §4 is a ≤5-line checklist + test — NO ip-rule manual.
- Portability scan command + exemptions: see references/portability-scan.md.

## Rule 2 — Review-First (Teil 0) before any feature
Before building new features, prove the current `main` is sound with **line-cited evidence**,
not memory:
1. Run a portability scan (see references/portability-scan.md) — `grep -rn` for
   `q958|192\.168\.|m7c5\.de|10\.8\.|privado` in `*.nix`. Treffer only in `example =` fields
   or the `mediNix-cli` host-heuristic are OK; anything else is a K.O. violation.
2. Verify each claimed fix against the actual file+line. Quote the line.
3. Only after "OK / BUG / FIXED" report, proceed to features.
This caught a real Unit-naming bug that a second AI reviewer mis-diagnosed (see Pitfall 1).

## Rule 3 — Pitfall: StateDirectory ≠ systemd Unit-Name
- **Factory** (`lib/service-factory.nix` line ~47): `systemd.services."${name}" = { ... }` where
  `name` is the **plain kebab service name** (e.g. `"sonarr"`). → Unit = `sonarr.service`.
- The **port** (5320) lives ONLY in `StateDirectory` (`/var/lib/sonarr-5320`) and socket
  `listenStreams` — NEVER in the Unit name.
- `after = [ "sonarr-5320.service" ]` is **wrong**; correct is `after = [ "sonarr.service" ]`.
- SABnzbd is native nixpkgs (`services.sabnzbd.enable` → `sabnzbd.service`), same plain rule.
- If you ever see `*-NNNN.service` in an `after =`/`wants =` list, it's a bug — fix to plain name.
- The inverse confusion (thinking the Factory adds port suffix) is the most common mediNIX footgun.
  The Port sits in StateDirectory + socket, not the Unit.
- **VALIDATED MIS-DIAGNOSIS (this session):** a second AI reviewer claimed the Factory produces
  `sonarr-5320.service` and told us to "fix" `after =` to plain names — that reviewer had the
  truth BACKWARDS (it conflated StateDirectory with Unit). We had `after = [ "sonarr-5320.service" ]`
  WRONG, and plain `sonarr.service` CORRECT. Always read `lib/service-factory.nix` line 47 + the
  actual `53x-*.nix` module before trusting any reviewer's Unit-name claim. The canonical proof:
  `532-sonarr.nix` builds `systemd.services.sonarr` (Factory `name="sonarr"`).

## Invariant discipline (fail-closed)
- All security/config guarantees are Build-time `assertions` in `59-guardrails/590-registry.nix`
  + `599-cross-domain.nix` (INV-*). New checks ALWAYS go in the registry, never inline text.
- VPN confinement (`525-usenet-confinement.nix`): `usenet-confinement.enable = true` WITHOUT
  `vpn.interface` AND `vpn.dnsServers` → eval error (INV-04 / INV-VPN-01/03/04/05).
  No silent fallback to 1.1.1.1 / host DNS (INV-VPN-05 — framed as conscious POLICY, not just
  leak-protection; document that explicitly). Modul implements NO DoT client; Host delivers
  encrypted DNS (ADMIN-HANDOFF §4a variants A/B/C).
- **INV-VPN-03** (relaxed this session): confinement → `sabnzbd.enable || prowlarr.enable`
  (at least one confined service active), NOT both-required. 
- **INV-VPN-04** (corrected this session): IPv4 `^[0-9]+(\.[0-9]+){3}$` and IPv6 `[0-9a-fA-F:]+`
  with at least one `:` — the earlier `hasInfix "."` check wrongly rejected pure IPv6.
- **Runtime Verify** (`usenet-vpn-verify.service`) uses ipify external HTTPS; it is a SUPPLEMENT
  to the real kill-switch (RestrictNetworkInterfaces + UID policy routing), NOT a substitute.
  Document in ADMIN-HANDOFF §4b that the kill works offline without ipify.

## Commit discipline
- main only, no branches. Push only after explicit user "Ja push" in chat.
- Show full diff/file for Sichtprüfung before commit when user expects it (German workflow preference).
- CHANGELOG.md: keep Phase-numbered, note Legacy cleanups + fakeHash as conscious placeholder.

## Overlap note
`medinix-nix-idioms` (user-owned, NOT curator-managed) already carries a "Factory-Unit-Namen-Regel"
but predates this sharper StateDirectory-vs-Unit distinction. Recommend:
`hermes curator adopt medinix-nix-idioms` then patch Pitfall 1 in there too. Until adopted,
this skill is the authoritative capture. `medinix-pre-commit` covers 7 Quality Gates but not the
Review-First scan protocol — keep both.
