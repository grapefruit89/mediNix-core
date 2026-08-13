---
id: "GEMINI"
title: "GEMINI"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - general
links:
  adr: ""
  repo-harvest: ""
---
# GEMINI.md – Definitives Manifest (v7.0)
# Supersedes: alle Vorgänger | Stand: März 2026

═══════════════════════════════════════════════
## 0. OBERSTES GEBOT: PFAD-REINHEIT
═══════════════════════════════════════════════

Schreiben NUR in: /home/Knowledge-Pipeline/ und /home/mynixos/
VERBOTSZONE: /root/ – kein Schreiben, keine temporären Dateien
/tmp/ – nur Read-Only für git clone

Datei-Schreib-Methode: ausschließlich Python-Direkt-Write oder
tee. Kein `cat << EOF` (Syntaxfehler). Kein `printf` mit 
Sonderzeichen (Flag-Interpretation).

Nach jeder Operation: ls -la /root/ → Reinheits-Nachweis.

═══════════════════════════════════════════════
## I. PROJEKT-ZIEL
═══════════════════════════════════════════════

Migration von Unraid/Docker/Traefik zu nativem NixOS-Homeserver.
Hardware: Fujitsu Q958 | i3-9100 | 16GB RAM | Intel UHD 630

ZIEL-STACK (nach Migration):
  Infrastruktur : Caddy, AdGuardHome, Tailscale, Cloudflared
  Identity      : Pocket-ID (OIDC + Passkeys)
  Datenbanken   : PostgreSQL, Valkey
  Medien        : Jellyfin, Sonarr, Radarr, Prowlarr, SABnzbd,
                  Audiobookshelf, Jellyseerr, Recyclarr
  Kommunikation : Matrix Conduit
  Produktivität : Vaultwarden, n8n, Home Assistant, Paperless
  Wissen        : Miniflux, Readeck, Linkding
  Ops           : Homepage, Semaphore, ddns-updater

NICHT-ZIELE (dauerhaft verboten):
  Docker, Podman, OCI-Container
  Traefik, iptables, GRUB, klassische Channels
  Denix-Framework (bleeding-edge, nicht stabil genug)
  Readarr-fork, Agent-Zero, Redis (→ Valkey stattdessen)

═══════════════════════════════════════════════
## II. UNVERÄNDERLICHE PRINZIPIEN
═══════════════════════════════════════════════

SOFTWARE-SELEKTION (Priorität):
  1. Natives NixOS-Modul (services.X.enable) – absolute Priorität
  2. Nixpkgs-Paket + eigener systemd-Unit
  3. Community-Flake (battle-tested, >6 Monate stabil)
  4. VERBOTEN: Docker/Podman/OCI

BINARY-EFFIZIENZ-MANDAT:
  Go/Rust/C Single-Binaries gewinnen gegen Python/Java-Stacks.
  Gilt wenn funktionaler Ersatz existiert.

NO-LEGACY-MANDAT:
  Proxy    → Caddy (Go)        nicht Traefik/Nginx
  Firewall → nftables          nicht iptables
  Boot     → systemd-boot+UEFI nicht GRUB
  Pakete   → Flakes only       nicht Channels
  GPU      → iHD (Intel QSV)   nicht generische Treiber

MODULARITÄT (Dendritic-Pattern):
  Werkzeuge: flake-parts + import-tree (stabil, community-validated)
  Regel: Eine Datei = Ein Feature. NixOS + Home-Manager eines
         Dienstes leben in einer Datei. Kein specialArgs-Tunnel.
  NICHT: denix (experimentell)

═══════════════════════════════════════════════
## III. LAYER-ARCHITEKTUR (modules/)
═══════════════════════════════════════════════

  00-core     Ohne dies: OS unsicher oder kaputt
              SSH, Users, nftables, Boot, Secrets, Storage

  20-server   Ohne dies: Server nicht erreichbar
              Caddy, AdGuard, Tailscale, PostgreSQL, Valkey,
              Pocket-ID, Cloudflared, VPN-Confinement

  30-services Täglich genutzt, betriebskritisch
              Vaultwarden, n8n, Home Assistant, Matrix Conduit,
              Semaphore, Homepage, OliveTin

  40-media    Audio/Video-Konsum
              Jellyfin, Sonarr, Radarr, Prowlarr, SABnzbd,
              Audiobookshelf, Jellyseerr, Recyclarr

  50-knowledge Wissen & Dokumente
              Paperless, Miniflux, Readeck, Linkding, Karakeep

  80-monitoring Beobachtet das System
              Scrutiny, Netdata, Uptime-Kuma

  90-policy   Assertions & Build-Checks
              Port-Kollisions-Guard, Container-Verbot, Lint

═══════════════════════════════════════════════
## IV. WISSENSBASIS-STANDARD
═══════════════════════════════════════════════

PFADE:
  Rohdaten (Read-Only)  : /home/Knowledge-Pipeline/raw/
  Veredelte Docs (SSoT) : /home/Knowledge-Pipeline/docs/
  Archiv/Superseded     : /home/Knowledge-Pipeline/raw/_duplikate/
  NixOS-Code            : /home/mynixos/

DREI-LAYER-PFLICHT (jedes Dokument):
  1. User Layer (KISS)    – Was ist das, wofür brauche ich es?
  2. Technical Layer      – Vollständige Spezifikation, Nix-Code
  3. Reasoning Layer      – ADR: Warum? Was wurde verworfen?

SIEBEN QUALITÄTS-TORE (jede .nix-Datei):
  1. Community-Goldstandard  (nixpkgs/modules Abgleich)
  2. API-Accuracy            (context7 – nie halluzinieren)
  3. SSoT-Compliance         (configs.nix + ports.nix)
  4. SRE-Hardening           (systemd-analyze security < 4.0)
  5. Dendritische Integrität (One Service, One File)
  6. Hygiene & Purity        (kein toter Code, keine Meta-Options)
  7. Traceability            (YAML-Header mit Quellen-Referenz)

WISSENS-WACHSTUM (Löschverbot):
  Neue Erkenntnisse ergänzen – sie ersetzen nie.
  [CONTEXT7-ENRICHMENT]  – aus Context7
  [SEARCH-ENRICHMENT]    – aus Web-Recherche
  [ARCHITECT-NOTE]       – interne logische Herleitung
  [SUPERSEDED]           – überholt, bleibt im Reasoning Layer

═══════════════════════════════════════════════
## V. PATTERN-MINING PROTOKOLL (GitHub)
═══════════════════════════════════════════════

Wenn ein GitHub-Link übergeben wird:

SCHRITT 1 – FILTER (nie blind alles einlesen):
  Bei Account-Links (nicht einzelne Repos):
  - Liste nur Repos mit *.nix Dateien
  - Filtere nach Tags: nixos, homelab, nix-config, self-hosted
  - Nur Repos mit Aktivität in 2024 oder 2025
  - Zeige gefilterte Liste → Nutzer wählt aus

SCHRITT 2 – EXTRAKTION (nur relevante Dateien):
  Erlaubt  : README.md, flake.nix, *.nix aus modules/ oder hosts/
  Verboten : Quellcode (src/), Lock-files, CI-Configs (.github/)
  Ziel     : /home/Knowledge-Pipeline/raw/sources/<repo-name>/

SCHRITT 3 – PATTERN-ANALYSE:
  Extrahiere: Modul-Struktur, Options-Pattern, Hardening-Tricks
  Schreibe Analyse nach: /raw/sources/<repo-name>-patterns.md

SCHRITT 4 – VEREDELUNG (optional, auf Anweisung):
  Übertrage relevante Patterns nach /docs/ (Drei-Layer-Standard)
  Markiere Herkunft: [PATTERN-MINING: <repo>]

═══════════════════════════════════════════════
## VI. ANTI-HALLUZINATIONS-GESETZ
═══════════════════════════════════════════════

Bei Nix-Optionen / API-Fragen: IMMER zuerst context7 befragen.
Beweispflicht: Erfolg = ls -la + head/tail Nachweis.
Keine Platzhalter: "..." oder "wie oben" = Systemverstoß.

VERBOTENE EINGRIFFE:
  Kein sed -i auf Systemdateien
  Kein pkill auf unbekannte Prozesse  
  Keine SSH/systemd-Manipulation ohne expliziten Auftrag
  Keine Metadaten als Nix-Options (options.my.meta.*)
  Alles deklarativ über Nix – niemals manuell

═══════════════════════════════════════════════
## VII. MCP-SERVER
═══════════════════════════════════════════════

Beim Start zu validieren:
  context7        – Primäre Docs-Quelle (KRITISCH)
  nixos           – Nix-Optionen Validierung
  open-websearch  – Live Best-Practices
  github          – Referenz-Repository Scans

Bei Ausfall: SOFORT melden. Kein stilles Scheitern.
Kein Simulieren von Tool-Outputs.

═══════════════════════════════════════════════
## VIII. GIT-SYNC PROTOKOLL
═══════════════════════════════════════════════

Repo  : https://github.com/grapefruit89/mynixos-knowledge-base
Pfad  : /home/Knowledge-Pipeline/docs/ → Branch main
Trigger: Nach jeder erfolgreichen Veredelung
Prefix : adr:, services:, learnings:, guides:, patterns:
Tokens : Nur via Umgebungsvariablen – niemals im Klartext