---
id: "50-banned-technologies"
title: "Banned Technologies & Paradigms (Strict Denylist)"
domain: 50
folder: 50-core
status: active
complexity: 1
last_reviewed: 2026-10-16
links: ""
---

# Banned Technologies & Paradigms

This file serves as absolute law for all AI agents and human contributors. The technologies and paradigms listed below are **strictly forbidden** in the `mediNix-core` repository. There are no exceptions.

## Core Philosophy: The Native Whitelist

We adhere to a strict **Whitelist Philosophy**: If a problem can be solved by native `systemd` features, `nftables`, or native `nixpkgs` modules, we **must** use those. We do not introduce abstraction layers, third-party Daemons, or legacy tools.

Maschinell geprueft: `scripts/check_banned_technologies.py` (order-lint, Label
"Verbotene Technologien?"). Geprueft werden **nur aktivierende Muster** - eine verbietende
Assertion (`!(config.services.logrotate.enable or false)`) oder ein Guard-Name (`nginx = { … }`)
ist erlaubt. Bedingte Regeln dieser Datei (Postgres/MySQL "als Default", Auto-Updater,
unbeschraenktes `sudo`) bleiben manuelle Pruefung.

**Whitelist-Regel (§2/§3) — FINAL:** Erlaubt sind **ausschliesslich** **Pocket ID** (IdP)
und **oauth2-proxy** (Forward-Auth) — plus die Caddy-eingebaute Direktive `forward_auth`.
Diese beiden Namen stehen bewusst **nicht** in den Mustern des Checks und werden nie als
"banned" gemeldet; **jede andere** IdP-/Forward-Auth-Software ist verboten.

## 1. Banned Technologies (Legacy & Bloat)

| Banned Technology | Replacement / Nix-Way Alternative | Rationale |
| :--- | :--- | :--- |
| **`sops-nix` / `agenix`** | `systemd-creds` (LoadCredentialEncrypted) | Absolutely banned. We rely 100% on native systemd TPM2 sealing. Third-party secret managers add unnecessary abstraction, break the pure systemd-native philosophy, and complicate disaster recovery. |
| **`tinyauth`** | `oauth2-proxy` (OIDC gegen Pocket ID) | Banned: **kein Passkey-Support**. Unser Auth-Flow ist passkey-first (Pocket ID, ADR-512); ein Forward-Auth-Proxy ohne Passkeys bricht das. Ersatz: `oauth2-proxy` (ADR-517). |
| **`iptables`** | `nftables` | iptables is legacy, inefficient, and abstract. We use modern, declarative nftables rulesets. |
| **`cron` / `crond` / `anacron`** | `systemd.timers` | cron lacks centralized logging, dependency tracking, and atomic execution. systemd.timers provide native journald integration and predictable execution constraints. |
| **Docker / Podman / LXC** | Native `systemd.services` (DynamicUser, RootImage) | The Zero-Container rule (enforced in `592-environment.nix`). We build software natively from `nixpkgs` and isolate it using systemd's built-in sandboxing (RestrictAddressFamilies, PrivateTmp). |
| **Unrestricted `sudo`** | Whitelisted `sudo` rules | We DO use `sudo`, but only strictly for whitelisted commands (e.g., `media-admin` restart scripts). Passwordless full-root `sudo ALL=(ALL) NOPASSWD: ALL` is strictly banned. |
| **Plex Media Server** | `Jellyfin` | Plex relies on cloud-relays, forces account logins for local playback, includes telemetry, and contradicts our Zero-Trust Localhost and no-silent-phone-home philosophy. |
| **`supervisord` / `PM2`** | `systemd.services` | Do not use internal process managers (Anti-Docker reflex). Use native systemd for lifecycle management. |
| **`ufw` / `firewalld`** | `networking.nftables` | Imperative firewall wrappers create state outside Nix. We exclusively use declarative Nix firewall/nftables rules. |
| **`nginx` / `Traefik`** | `Caddy` | We have exactly ONE reverse proxy instance (Caddy). Adding another Ingress layer breaks architectural purity. |
| **Postgres / MySQL** (Default) | `SQLite` + WAL | For a homelab, heavy DB servers per service are pure overhead. If a service supports SQLite natively, it MUST be used over a heavy relational DB. |
| **App Auto-Updaters** | `nixpkgs` | Built-in self-updaters break declarative reproducibility. Versioning must strictly happen via Nix flake pinning. |

## 2. Identity Provider (IdP)

**Erlaubt (Whitelist) — der EINZIGE IdP:**

| Erlaubt | Warum |
| :--- | :--- |
| **Pocket ID** | Go, SQLite, **Passkey-only**, **1 Binary**, BSD-2. Referenz-IdP (ADR-512). |

**Blacklist — alles andere:**

| Banned IdP | Begründung |
| :--- | :--- |
| **Keycloak** | Java + PostgreSQL, 1–2 GB RAM, kein Passkey-only. |
| **Authentik** | Python + PostgreSQL + Redis, mehrere Container, > 150 MB RAM. |
| **Zitadel** | PostgreSQL, mehrere Komponenten. |
| **Authelia** | Kein reiner IdP (OIDC-Provider Beta), Forward-Auth-Hybrid. |
| **Dex** | Keine Passkeys (nur statische User/LDAP). |
| **tinyauth** | Keine Passkeys, AGPL-3.0. |
| **Logto** | Schwergewichtiger als Pocket ID (Node.js + PostgreSQL). |
| **Kanidm** | Nicht mit dem Single-Binary-pro-Funktion-Prinzip vereinbar. |
| **Glewlwyd** | Nicht mit dem Single-Binary-pro-Funktion-Prinzip vereinbar. |
| **Ory (Kratos/Hydra) · FusionAuth · Casdoor** | Kein Passkey-only, externe DB oder schwerer als Pocket ID. |

## 3. Forward-Auth-Proxys

**Erlaubt (Whitelist) — nur dieser Proxy:**

| Erlaubt | Warum |
| :--- | :--- |
| **oauth2-proxy** | MIT, OIDC-Client, 1 Binary; nixpkgs-Modul `services.oauth2-proxy` (ADR-517). Die Direktive `forward_auth` selbst ist Caddy-eingebaut. |

**Blacklist — alles andere:**

| Banned Proxy | Begründung |
| :--- | :--- |
| **caddy-security** | Caddy-**Plugin**, kein eigenes Binary — widerspricht dem Single-Binary-pro-Funktion-Prinzip. Volle Begründung unten. |
| **tinyauth** | Keine Passkeys, AGPL-3.0. |
| **Pomerium** | Kein klassischer `forward_auth`-Modus seit v0.21, eigene Datenplane. |
| **Authentik Proxy Provider** | Schwergewichtig, an Authentik gebunden. |
| **Authelia** | Hybrid, OIDC-Provider Beta. |
| **Vouch · Traefik-ForwardAuth · nginx `auth_request` · oauth2-proxy-Fremd-Forks** | Nicht die Whitelist. |

### Warum `caddy-security` gebannt ist (Weg B: `pkgs.caddy.withPlugins`)

1. **Hash-TOFU bei jedem Caddy-Bump.** Die `withPlugins`-FOD vendored den
   Caddy-Quellcode samt Plugin — der Hash ändert sich bei **jedem** Caddy-Update in
   nixpkgs, selbst wenn die Plugin-Version unverändert bleibt. Ablauf dann: Build
   schlägt fehl → neuen Hash aus der Fehlermeldung übernehmen → erneut bauen. Das ist
   manueller Pflegeaufwand, den ein LLM **nicht zuverlässig autonom** erledigen kann.
2. **Kein „Single Binary pro Funktion".** caddy-security macht Caddy zum Proxy **und**
   Auth-Gateway — zwei Funktionen in **einem** Prozess. `oauth2-proxy` bleibt ein
   separater, spezialisierter Daemon (eine Aufgabe pro Binary).
3. **Konfigurationskomplexität & Doku.** Die `security`/`authenticate`-Blöcke
   (Portal-/Policy-Struktur) sind mächtiger als nötig; die Doku gilt in der Community
   als „a bit confusing"; es gibt Berichte über gebrochene Pocket-ID-Redirects nach
   Updates. Das einheitliche `/oauth2/auth`-Muster von `oauth2-proxy` passt direkt auf
   `511` (`forward_auth`), ohne Umbau.
4. **Kein offizielles NixOS-Modul.** `services.caddy-security` existiert **nicht** in
   nixpkgs (geprüft: nur `services.caddy.*`). Man hängt am generischen `withPlugins`
   und schreibt die Caddyfile-Blöcke selbst. Für `oauth2-proxy` gibt es dagegen das
   etablierte Modul `services.oauth2-proxy` mit deklarativen Optionen.

**Wenn Weg B trotzdem gegangen wird:** Plugin-Version pinnen (`…@v1.1.29`) **und** den
TOFU-Prozess für den nächsten Caddy-Bump dokumentieren — sonst scheitert der Build bei
jedem nixpkgs-Update. `oauth2-proxy` gewinnt in allen Kriterien ausser „ein Prozess
weniger": kein Hash-Pinning, einheitliches Muster, klare Zuständigkeitstrennung
(Caddy routet, oauth2-proxy authentifiziert).
| **Third-Party Loggers** | `journald` | Do not install custom log rotators or forwarders if `systemd-journald` can do the job natively. |
| **`logrotate`** | `systemd-journald` (`SystemMaxUse=500M`) | Banned (ADR-500). mediNix relies 100% on native systemd journald log limits and automatic retention. Legacy logrotate scripts cause race conditions with service log streams and redundant log layers. |
| **LLM Vector-DBs / RAG Plugins** | `AGENTS.md` & `grep` | Banned: `qmd`, `ChromaDB`, `FAISS`, heavy Python ML dependencies. Our codebase maps are deterministically generated (`medinix-meta.py generate-docs`). LLMs must use native `grep`/`fd` and read the `AGENTS.md` indexes instead of relying on fuzzy, bloated vector search. |

## 2. Banned Paradigms (Anti-Patterns)

| Banned Paradigm | Replacement / Nix-Way Alternative | Rationale |
| :--- | :--- | :--- |
| **`lib.mkForce`** | Additive Config & Tri-State Boundary | Forcing overrides breaks composability. If a host needs a different setting, we use the `managed \| external \| off` Tri-State Boundary and let the host decide. |
| **Fail-Open Defaults** | Fail-Closed Assertions | e.g., silently falling back to unencrypted DNS if the VPN DNS fails, or starting a service with an empty password. If a critical secret or config is missing, the system MUST crash or refuse to build. |
| **Silent State (Drop & Forget bypass)** | `medinix.knownStateDirs` | Leaving data on the host when a module is removed is a leak. All modules must register their state directories so the Orphan Cleanup script can detect drift. |
| **Hardcoded UIDs / GIDs** | `DynamicUser = true` or `lib/registry.nix` | Never hardcode User/Group IDs in modules unless defined centrally in our Service Registry Decimal Framework (Port = UID = Service-Nummer × 10). |

> **Instruction to AI Agents (Claude, Antigravity, etc.):**
> If the user asks you to implement a feature using any of the Banned Technologies, you must refuse, reference this document, and provide the native Nix/systemd alternative. Do not suggest containers, cron, or sops-nix under any circumstances.
