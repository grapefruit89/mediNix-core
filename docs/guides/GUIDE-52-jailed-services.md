---
id: "GUIDE-52-jailed-services"
title: "GUIDE 52 — Systemd-Hardening statt bubblewrap-Jail"
domain: 52
status: active
complexity: 2
last_reviewed: 2026-10-17
tags:
  - sandbox
  - security
links:
  adr: ""
  repo-harvest: ""
---
# ⛓️ Sandboxing: systemd-Hardening statt bubblewrap-Jail

Kein `jail.nix`, kein `bubblewrap`. Isolation kommt aus **einer** Quelle:
`lib/hardening-profiles.nix` (SSoT).

## 🛡️ base-Profil (für jeden Dienst)
`NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`,
`ProtectKernel*`, `ProtectProc=invisible`, `ProcSubset=pid`, `RestrictNamespaces`,
`RestrictRealtime`, `RestrictSUIDSGID`, `LockPersonality`,
`SystemCallFilter=@system-service`, `SystemCallArchitectures=native`.

## 🔌 Netz-Policy getrennt von Bind-Policy
- `networkPolicy.loopback` — nur `127.0.0.1`/`::1`
  (z. B. `RestrictNetworkInterfaces = [ "lo" ]`).
- `networkPolicy.internet` — verbinden erlaubt, binden nur lokalhost; `526` ist der
  WAN-Choke.
- `networkPolicy.proxy` — `SocketBindAllow = [ "any" ]` für Reverse-Proxies.

Sprach-/Rollen-Profile (`dotnet`, `dotnet-gpu`, `nodejs`, `python`, `network`,
`script`, …) erweitern `base` gezielt — Härtung wird **nie** ad hoc im Modul
dupliziert.

## 📂 Dateisystem
Lesende Mediendienste binden die Bibliothek über `BindReadOnlyPaths` **read-only**;
jeder Dienst schreibt nur in sein eigenes `stateDir` und ggf. den Media-Root.

Quellen: `lib/hardening-profiles.nix`, `docs/NO-CONTAINERS.md`,
`53-acquisition/README.md`, `docs/TERMINOLOGY.md`.
