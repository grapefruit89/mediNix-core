# Werkstatt: Chat 1 → Code (4 Tasks)

## Regeln
1. Ein Task, ein Commit, ein Stop.
2. Kein programs.json / concerns.json / domain-matrix.json anfassen.
3. Vor Task 1: `git status` sauber? Wenn nein: erst committen.
4. `nix flake check --no-build` nach jedem Task (eval only).
5. Wenn Task nicht lösbar (nixpkgs hat Fix nicht, eval bricht): STOPP, an User melden, nicht raten.
6. Rückmelde-Format am Ende jedes Tasks (VERSTANDEN / GEMACHT / UNKLAR / NÄCHSTER SCHRITT).

## Task 1: 3 CVEs (flake.lock)
Ziel: Caddy >= 2.11.2, CrowdSec >= 1.7.8, Seerr >= 3.4.0
Datei: flake.lock (via `nix flake update nixpkgs`)
Verifikation:
  nix eval --raw nixpkgs#caddy.version    # >= 2.11.2
  nix eval --raw nixpkgs#crowdsec.version # >= 1.7.8
  nix eval --raw nixpkgs#seerr.version    # >= 3.4.0
  nix flake check --no-build
Commit: fix(deps): CVE-2026-0354, NIXPKGS-2026-2196, CVE-2026-73291

## Task 2: T-01 + T-02 (Ban-Kette)
T-01: 51-ingress/511-caddy.nix — catchAllSites: `abort` → `respond "Get off my lawn" 404` (HTTP + HTTPS)
T-02: 51-ingress/516-crowdsec.nix — hub.collections: + "crowdsecurity/http-probing"
Verifikation:
  grep -n "respond" 51-ingress/511-caddy.nix
  grep -n "http-probing" 51-ingress/516-crowdsec.nix
  nix flake check --no-build
Commit: feat(ingress): Caddy respond 404 catch-all + CrowdSec http-probing

## Task 3: T-05 (mDNS raus, Blocky rein) — 2 Sub-Tasks
3a: 51-ingress/515-blocky.nix anlegen (Split-DNS, uid 5150, Port 53, CAP_NET_BIND_SERVICE)
    lib/registry.nix: blocky = mkNoPortWithUnit "blocky" 515 "network" "none" "blocky"
    nix flake check --no-build → Commit
3b: 51-ingress/515-mdns.nix löschen
    lib/registry.nix: avahi-Eintrag entfernen (falls vorhanden)
    nix flake check --no-build → Commit
Reihenfolge 3a → 3b: Blocky zuerst, damit mDNS-Ausfall keine Lücke hinterlässt.

## Task 4: T-04 (.gitignore)
Datei: .gitignore
Ergänzen: *.cred, *.encrypted
Verifikation: grep -E '\*\.(cred|encrypted)' .gitignore
Commit: chore(gitignore): block *.cred and *.encrypted

## Checkliste
- [ ] Task 1: CVEs in flake.lock
- [ ] Task 2: Caddy 404 + CrowdSec http-probing
- [ ] Task 3a: Blocky-Modul + Registry
- [ ] Task 3b: mDNS/Avahi entfernt
- [ ] Task 4: .gitignore erweitert
- [ ] 4 Commits auf Branch fix/chat1-quickwins
- [ ] nix flake check --no-build grün nach letztem Task
