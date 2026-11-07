---
id: "ARCH-50-deep-dive-knowledge-gems"
title: "ARCH 5000 deep dive knowledge gems"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - core
links:
  adr: ""
  repo-harvest: ""
---
# Architecture: Deep-Dive Knowledge Gems (The "Hidden Pearls")

## 1. User Layer (KISS)
Dieses Dokument fasst die cleversten technischen Lösungen und "Tricks" deines NixOS-Systems zusammen. Es ist ein "Best-of" der Programmierung, das zeigt, wie du komplexe Aufgaben (wie das Vernetzen von Apps oder das Sichern des Systems) mit minimalem Aufwand und maximaler Zuverlässigkeit gelöst hast. Diese Mechanismen sind das, was dein System von einer normalen Installation zu einem "Aviation-Grade" SRE-System abhebt.

## 2. Technical Layer (Aviation-Grade)

### Die mkService Abstraktion (`00-core/lib-helpers.nix`)
*   **Mechanismus:** Ein zentraler Wrapper für Systemd + Caddy + SSO.
*   **Pfiffigkeit:** Erkennt automatisch den Kontext (Network Namespace) und biegt die Reverse-Proxy-Ziele auf die Namespace-Bridge (`10.200.1.2`) um.
*   **Security:** Erzwingt `ProtectSystem="strict"` für alle Dienste als Standard.

### SRE Master Source & Bastelmodus (`00-core/configs.nix`)
*   **Condition:** Der `bastelmodus` Flag steuert globale Sicherheits-Assertions.
*   **UX:** Ein systemd-Dienst sendet bei aktivem Bastelmodus Warnungen (`wall`) an alle Terminals, um Fehlkonfigurationen im produktiven Betrieb zu verhindern.

### Das 10k/20k Port-Schema (`00-core/ports.nix`)
*   **Standard:** `10xxx` für Infrastruktur, `20xxx` für User-Dienste.
*   **Validierung:** Das Modul prüft beim Build auf Port-Kollisionen (`lib.unique`), was "Silent Failures" bei Proxy-Konfigurationen ausschließt.

### VPN-Confinement via Netns (`20-infrastructure/vpn-confinement.nix`)
*   **Isolation:** Erstellt einen dedizierten Network Namespace (`media-vault`) für ungesicherten Traffic (Downloads).
*   **Routing:** Nur Dienste innerhalb des Namespaces nutzen den VPN-Tunnel, während der Host und andere Dienste direkt (und schnell) kommunizieren.

### ARR-Wire: Auto-Wiring API Keys (`40-media/service-media-arr-wire.nix`)
*   **Automatisierung:** Ein Oneshot-Service extrahiert API-Keys aus `config.xml`-Dateien und injiziert sie via REST-API in abhängige Dienste.
*   **Vorteil:** Macht den Media-Stack nach einer Neuinstallation sofort einsatzbereit, ohne manuelles Kopieren von Keys über Weboberflächen.

### Integritäts-Polizei (`90-policy/`)
*   **Flat-Layout:** Ein Build-Check unterbindet Unterordner in den Layern, um die Navigationsgeschwindigkeit im Repo hoch zu halten.
*   **Security-Assertions:** Verhindert den Build, wenn kritische Sicherheitsregeln (Firewall, SSH) verletzt werden, sofern nicht der Bastelmodus aktiv ist.

## 3. Reasoning Layer (History)

### [ADR-017] Abstraktion vs. Explizite Konfiguration
*   **Status:** Entschieden (März 2026).
*   **Kontext:** Jedes Modul manuell zu härten und im Proxy zu registrieren ist fehleranfällig.
*   **Entscheidung:** Nutzung der `mkService` Helfer-Funktion.
*   **Begründung:** Einheitlichkeit (Uniformity) ist wichtiger als individuelle Anpassbarkeit für Standard-Webdienste. Spezialfälle können weiterhin manuell konfiguriert werden.

### [ADR-018] Network-Namespaces statt Docker-Netzwerke
*   **Status:** Entschieden (März 2026).
*   **Kontext:** Docker bietet Isolation, bricht aber das binärbasierte Nix-Konzept.
*   **Entscheidung:** Nutzung nativer Linux Network Namespaces (`netns`).
*   **Vorteil:** Volle Integration in die NixOS-Deklaration ohne den Overhead und die Sicherheitsrisiken eines Docker-Daemons.

---
**Sources:**
*   `00-core/lib-helpers.nix`
*   `00-core/configs.nix`
*   `00-core/ports.nix`
*   `20-infrastructure/vpn-confinement.nix`
*   `40-media/service-media-arr-wire.nix`
*   `90-policy/flat-layout.nix`
