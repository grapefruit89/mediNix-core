---
id: "GUIDE-50-aviation-grade"
title: "GUIDE 50 — Aviation-Grade: native-first Dienst-Auswahl"
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
# ⚖️ Aviation-Grade: native-first Dienst-Auswahl

Heuristik bei der Dienstwahl für einen Homeserver (kein Rechenzentrum): bevorzuge
nativ kompilierte, schlanke Dienste.

- Go/Rust/C statt Python/Java/Node, **wo** eine binäre Alternative existiert.
- Weniger RAM, sofortiger Kaltstart, leichtere Nix-Integration.

## 🧩 Belege im Repo
- **Pocket ID (Go)** statt eines funktional schwereren Identity-Stacks —
  `51-ingress/512-pocket-id.nix`.
- **Caddy (Go)** als einzige WAN-Tür — `51-ingress/511-caddy.nix`.
- Native systemd-Dienste statt Container — `docs/NO-CONTAINERS.md`, Root-`README.md`.

## 🛡️ Grenze der Regel
Das ist eine **Auswahl-Heuristik**, keine maschinelle Prüfung. Harte Regeln stehen in
den Checks (`docs/CONVENTIONS.md` §Die Kette). Sprach-Ausnahmen sind erlaubt, wenn
nixpkgs keine native Alternative bietet — im Repo sichtbar als Profile `nodejs`
(Audiobookshelf, Navidrome) und `python` (SABnzbd) in `docs/INDEX.md`.

Quellen: Root-`README.md`, `docs/INDEX.md` (Service Map + Profile).
