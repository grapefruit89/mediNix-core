---
id: "ADR-019"
title: "Community-Flakes Benchmark & Architektur-Abgrenzung"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-10-26
tags:
  - architecture
  - benchmark
  - network
  - container
links:
  adr: ADR-0000 (Dezimalrahmen), ADR-0011 (UID-Routing vs. Netns), ADR-5000 (Native Services over Docker)
---

# ADR-019: Community-Flakes Benchmark & Architektur-Abgrenzung

## Kontext

Im Rahmen des konzeptionellen Architektur-Audits (Quelle: `todo/blocks/19-community-flakes-benchmark.json`) wurden prominente Community-Homelab-Flakes (u. a. Nixarr, Nixflix, jellarr, phenax/homeserver, lukethacoder) analysiert und gegen die Design-Prinzipien von mediNix gebenchmarkt.

Dabei ging es insbesondere um drei wiederkehrende Muster der Community:
1. **Network Namespaces für VPN-Routing (Nixarr)**
2. **Container-basierte Bereitstellung (Docker/Podman)**
3. **Monolithische `settings.nix`-Konfigurationsdateien (phenax)**

## Architektonische Entscheidungen

### 1. Ablehnung von Network Namespaces zugunsten von UID-fwmark (D-19-01)
* **Community-Muster:** Nixarr isoliert VPN-Dienste in eigenen Network Namespaces (`netns`).
* **mediNix-Entscheidung:** Verworfen. mediNix nutzt UID-basiertes `fwmark` und nftables Policy Routing (siehe `ADR-0011-uid-routing-vs-netns.md`).
* **Begründung:** Network Namespaces isolieren die Netzwerkebene hart in separate Silos. Dies bricht die transparente Unix-Domain-Socket-Kommunikation (UDS), die systemd-Socket-Aktivierung und das lokale DNS-Split-Horizon zwischen abhängigen Diensten. UID-fwmark isoliert den ausgehenden Datenverkehr selektiv nach Benutzer-ID, ohne das lokale Inter-Service-Routing zu beschädigen.

### 2. Bestätigung des strikten Container-Verbots (Zero-Container) (D-19-02)
* **Community-Muster:** Viele Homelab-Flakes (z. B. lukethacoder) binden Docker-Compose oder Podman-Container ein.
* **mediNix-Entscheidung:** Bestätigung des strikten Verbots (siehe `50-core/BANNED_TECHNOLOGIES.md` und `ADR-5000-native-services-over-docker.md`).
* **Begründung:** Container erzeugen imperativen Zustand und Images außerhalb des Nix-Stores, verdoppeln Isolationsebenen und verhindern die direkte Nutzung von TPM2-Hardware-Credentials (`systemd-creds`) sowie granularen User-Private-Group-Dateirechten (UPG). mediNix setzt ausschließlich auf native systemd-Services mit NixOS-Hardening.

### 3. Ablehnung monolithischer `settings.nix`-Dateien (D-19-03)
* **Community-Muster:** Zentralisierte globale Einstellungsdateien (wie `settings.nix` bei phenax), die Parameter quer über alle Services sammeln.
* **mediNix-Entscheidung:** Verworfen.
* **Begründung:** Eine zentrale `settings.nix` erzeugt eine unkontrollierte God-File-Abhängigkeit und führt zu zyklischen Abhängigkeiten im Modulbaum. mediNix verteilt Konfigurationsaspekte strikt über den Dezimalrahmen (`502-host-settings.nix` für Host-Parameter) und Service-Metadaten dezentral über die Service-Registry und Manifeste (ADR-0000, ADR-0003).

## Status und Konsequenzen
* Die Entscheidungen D-19-01, D-19-02 und D-19-03 sind verbindlich.
* Bestehende Guardrails und Dokumentationen reflektieren diese Abgrenzung.
