# Agent Sources — Maschinenlesbare Nachschlagequellen für mediNix-core

Dieses Dokument dient LLM-Agenten als deterministischer Quellenanker, um Halluzinationen von Optionen und Direktiven zu verhindern.

## 1. NixOS Optionen & Bibliotheken
- **NixOS-Optionen (Online-API):** `https://search-nixos-api.hadi.diy/options?query=<name>` (Schnelle JSON-Rückgabe via curl)
- **Nix-Standardbibliothek:** `https://noogle.dev/api` (Für `lib.*`-Funktionen und Signaturen)

## 2. systemd Spezifikationen
- **systemd Direktiven-Index:** `https://www.freedesktop.org/software/systemd/man/latest/systemd.directives.html` (Vollständiger Index aller gültigen `serviceConfig`- und `unitConfig`-Optionen)
- **systemd D-Bus Properties:** `https://www.freedesktop.org/software/systemd/man/latest/org.freedesktop.systemd1.html` (Laufzeit-Properties und Unit-Status)

## 3. Lokale SSoT-Anker (mediNix)
- **Dezimalrahmen & Identität:** [`/home/moritz/repos/mediNix-core/lib/registry.nix`](file:///home/moritz/repos/mediNix-core/lib/registry.nix) (`num`, `port`, `uid`, `gid`, `caddyClass`)
- **Service-Schablone (Goldstandard):** [`/home/moritz/repos/mediNix-core/55-playback/551-jellyfin.nix`](file:///home/moritz/repos/mediNix-core/55-playback/551-jellyfin.nix) (Lokale Optionen, Manifest-Publikation, StateDirectory, systemd-Härtung)
- **Härtungs-Profile:** [`/home/moritz/repos/mediNix-core/lib/hardening-profiles.nix`](file:///home/moritz/repos/mediNix-core/lib/hardening-profiles.nix)
- **Memory- & OOM-Policy:** [`/home/moritz/repos/mediNix-core/lib/memory-policy.nix`](file:///home/moritz/repos/mediNix-core/lib/memory-policy.nix)
- **Service-Vertrag:** [`/home/moritz/repos/mediNix-core/lib/service-contract.nix`](file:///home/moritz/repos/mediNix-core/lib/service-contract.nix)
