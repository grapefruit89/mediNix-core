---
id: "GUIDE-50-stick-ready-deployment"
title: "GUIDE 50 — Deployment: nixos-rebuild & flake checks"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-10-17
tags:
  - core
links:
  adr: ""
  repo-harvest: ""
---
# 🚀 Deployment: reproduzierbar aus dem Flake

Ziel: Das System spiegelt exakt den Code. Es gibt **eine** Quelle — den Flake.

## 🧩 Workflow
1. Änderung im Repo (Modul unter `NN-domain/`, keine losen Root-Skripte).
2. `nix flake check` — alle Assertions und Checks grün.
3. `nixos-rebuild switch --flake .#<host>` auf dem Zielhost.

Host-Setup once (Root-`README.md`, Quickstart):

```nix
medinix.enable = true;
medinix.domain = "example.tld";
medinix.ingress.enable = true;
medinix.ingress.tls.acmeHost = "example.tld";
medinix.ingress.tls.acmeCredential = "/path/to/cf.cred";
```

## 📌 Was dieses Repo nicht nutzt (verifiziert in `flake.nix`)
Die Inputs sind nur `nixpkgs` und `flake-utils`. Es gibt **kein** disko, **kein**
nixos-anywhere und **kein** srvos. Disko-Partitionierung ist Host-Sache, nicht Teil
des Modulsets.

Host-Entscheidungen nach dem Import: `docs/ADMIN-HANDOFF.md`.

Quellen: Root-`README.md` (Quickstart), `flake.nix`, `docs/CONVENTIONS.md`.
