---
id: "ARCH-50-architecture-blueprint"
title: "ARCH 50 — Architecture Blueprint"
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
# mediNix-core — Architektur-Blueprint

## 1. User Layer (KISS)

Der Blueprint beschreibt den Aufbau des Fujitsu Mediahost Homeservers als
**Infrastructure as Code** auf **NixOS Flakes**: vollständig reproduzierbar, alle
Dienste in Domänen organisiert. Fokus: **maximale Sicherheit** (Zero-Container,
versiegelte Secrets, fail-closed Ingress) bei hoher Effizienz (HDD-Spindown,
QuickSync).

## 2. Technical Layer

### Hardware-Plattform
*   **Maschine:** Fujitsu Mediahost (i3-9100, 16 GB RAM).
*   **Grafik:** Intel UHD 630 (QuickSync für H.264/H.265/HEVC) — `551` setzt
    `intel-media-driver` + `intel-compute-runtime`.
*   **Storage-Layout:**
    *   **OS/Appdata:** SATA-SSD (~512 GB).
    *   **Download-Cache:** NVMe (~250 GB) für `/downloads`.
    *   **Media:** direkte HDD-Mounts unter `/storage/`.

### Storage-Logik & Spindown-Optimierung
*   **Dateisystem:** **ext4** (kein ZFS — Overkill für die Kapazität, ADR-570).
*   **Spindown-Schutz:** smartd mit `-n standby,q`
    (`58-observability/587-disk-health.nix`, Option `spindownPreservation`) —
    **nicht** `hd-idle`.
*   **Atomic Move:** Downloads liegen auf der NVMe; der Transfer erfolgt per
    Hardlink/Atomic-Move innerhalb von `.staging`-Ordnern auf der Zielplatte.
*   **mergerfs:** **optional und host-seitig** (`docs/examples/mergerfs-tiering.nix`).
    Als Default abgelehnt, weil es beim Verzeichnis-Scan alle Platten weckt.

### Netzwerk & Sicherheit
*   **Reverse Proxy:** **Caddy** (`51-ingress/511-caddy.nix`) — die **eine** WAN-Tür;
    Backends binden ausschließlich `127.0.0.1:<port>`.
*   **TLS:** NixOS-ACME/Lego via Cloudflare **DNS-01** (`51-ingress/514-acme.nix`);
    Caddy läuft mit `auto_https off` und liest `/var/lib/acme/{acmeHost}/…`.
*   **Identity:** **Pocket ID** (`51-ingress/512-pocket-id.nix`) = OIDC-IdP
    (Passkeys). **Wichtig:** Pocket ID hat **keinen forward-auth-Endpoint** — ein
    Caddy-Gate (`auth.mode = "forward-auth"`) braucht einen separaten Auth-Proxy
    (oauth2-proxy, ADR-517), nicht Pocket ID.
*   **VPN:** **WireGuard** (`52-security/525-vpn-interface.nix`,
    `526-vpn-killswitch.nix`) mit **UID-basiertem nftables-Routing**.
    **`netns`/`PrivateNetwork` ist verboten** (ADR-0011) — kein Maroka-chan,
    kein Tailscale.
*   **Secrets:** **versiegelte systemd-Credentials** (`LoadCredentialEncrypted`),
    **kein** `sops-nix`/`agenix` (`lib/creds.nix`, ADR-521). Erzeugung/Rotation
    sind Host-Sache.
*   **Container:** **keine** (Zero-Container; Assertion gegen
    `virtualisation.docker.enable`, ADR-0002 §5).

### Modulare Flake-Struktur
```text
mediNix-core/
├── flake.nix            # Inputs: nixpkgs + flake-utils
├── default.nix          # Optionen + Engine
├── lib/                 # derive · registry · service-factory · hardening-profiles · creds
├── 50-core/ … 59-guardrails/   # NN-domain/NNN-dienst.nix (Dezimalrahmen, ADR-0000)
└── docs/                # ADRs · Konzepte · Guides · Patterns
```
Auto-Import der Domänen über `builtins.readDir` (kein `import-tree`).

### Spezifische Service-Implementierungen
*   **Jellyfin (551):** nativ, QuickSync/VAAPI; `auto` wird zu `intel` aufgelöst,
    RAM-Transcoding über `config/encoding.xml` (`TranscodingTempPath=/transcode`).
*   **SABnzbd (541):** VPN-Confinement über UID-Routing/nftables (`526`) plus
    `RestrictNetworkInterfaces`-Invariante.
*   **Beobachtbarkeit:** ntfy (`581`), Gatus (`582`), smartd (`587`).

## 3. Reasoning Layer (History)

*   **mergerfs/ZFS:** abgelehnt — mergerfs weckt beim Scan alle HDDs, ZFS ist für
    die Kapazität Overkill. mergerfs bleibt als optionale Host-Lösung.
*   **NixOS nativ statt Docker:** über 20 Dienste als native NixOS-Module für
    volle deklarative Kontrolle (ADR-0002 §5, ADR-5000).
*   **Pocket ID statt Authelia:** kleiner Footprint, moderne Passkey-Unterstützung.
*   **UID-Routing statt `netns`:** deklarativ, kein externer Flake, keine
    imperativen `ip netns`-Skripte (ADR-0011).

---
*Quellen: Repo-Code (Stand 2026-10-17) — `flake.nix`, `lib/`, `51-ingress/`,
`52-security/`, `55-playback/551`, `58-observability/587`;
ADR-0000, ADR-0002, ADR-0011, ADR-521, ADR-570.*
