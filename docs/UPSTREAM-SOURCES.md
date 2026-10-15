# mediNix-core — Upstream-Quellen & Referenzen

Zentrales Verzeichnis aller Upstream-Repositories, Bibliotheken, Standards und Dokumentationen, die als architektonische Grundlage oder Inspiration für Module in mediNix dienen.

> [!TIP]
> **Eiserne Regel für Agenten:** Wenn Code, Logiken oder Architekturen aus externen Repositories, NixOS-Modulen oder Dokus übernommen oder adaptiert werden, muss die Quelle zwingend mit Upstream-URL und Zweck in diese Tabelle eingetragen werden.

---

## Quellennachweise & Inspirationen

| Funktion / Modul | Upstream-Repository / Quelle | Zweck / Genutzter Ansatz |
|---|---|---|
| **511 Ingress / Caddy** | [caddyserver/caddy](https://github.com/caddyserver/caddy) | Reverse Proxy, automatisches TLS, Unix Admin-Socket (`admin unix//run/caddy-media/admin.sock`), `request_header -<Header>` Stripping vor Forward-Auth, Access-Log-Formatierung. |
| **512 Pocket-ID** | [stonith404/pocket-id](https://github.com/stonith404/pocket-id) | Schlanker OIDC Identity Provider (SQLite + Go/Svelte), Passkey-first Authentifizierung im Heimnetzwerk. |
| **516 CrowdSec** | [crowdsecurity/crowdsec](https://github.com/crowdsecurity/crowdsec), Hub [crowdsecurity/caddy](https://app.crowdsec.net/hub/author/crowdsecurity/collections/caddy) | Edge-IPS: Engine liest die Caddy-JSON-Logs aus dem journald (`_SYSTEMD_UNIT=caddy-media.service`; Parser-Filter: `program startsWith caddy`, `UnmarshalJSON(message)`), Bouncer setzt Bans per `createRulesets` in nftables. Collection = Caddy-Parser + base-http-scenarios. |
| **513 Cloudflare DDNS** | [cloudflare/api-schemas](https://github.com/cloudflare/api-schemas) | REST-API zur Aktualisierung von DNS-A-Records und Pruning von kanonischen FQDN-Subdomains. |
| **515 mDNS Aliases** | [avahi/avahi](https://github.com/avahi/avahi) | Lokale Multicast-DNS Veröffentlichung (`{service}.local -> LAN-IP`) für Zero-Config Erkennung im Subnetz. |
| **526 VPN Killswitch** | [WireGuard/wireguard-linux](https://git.zx2c4.com/wireguard-linux) & [netfilter/nftables](https://git.netfilter.org/nftables/) | Confinement via `meta skuid` und `type route hook output priority mangle` Markierung für fwmark-basiertes Policy Routing (ohne Network Namespaces). |
| **551 Jellyfin** | [jellyfin/jellyfin](https://github.com/jellyfin/jellyfin) | Systemd-natives Medien-Streaming, Transcoding, 5510 Dezimal-Port-Zuordnung. |
| **552 Audiobookshelf** | [advplyr/audiobookshelf](https://github.com/advplyr/audiobookshelf) | Hörbuch- und Podcast-Server mit geschütztem Setup-Flag und First-Run-Race-Absicherung (RT-2). |
| **553 Navidrome** | [navidrome/navidrome](https://github.com/navidrome/navidrome) | Schlanker Subsonic-kompatibler Musikserver; Admin-Pre-Seeding via `ND_DEVAUTOCREATEADMINPASSWORD`. |
| **561 Seerr** | [Fallenbagel/jellyseerr](https://github.com/Fallenbagel/jellyseerr) | Medien-Anfrageportal mit nativer Jellyfin-/Plex-Integration auf Port 5610. |
| **574 Servarr Provisioning** | [Sonarr/Sonarr](https://github.com/Sonarr/Sonarr), [Radarr/Radarr](https://github.com/Radarr/Radarr), [Prowlarr/Prowlarr](https://github.com/Prowlarr/Prowlarr) | Automatisches Setup von API-Keys, Root Folders, Download Clients und Qualitäts-Profilen. |
| **581 ntfy** | [binwiederhier/ntfy](https://github.com/binwiederhier/ntfy) | HTTP-basiertes Push-Benachrichtigungssystem für Statusmeldungen und Alerting. |
| **NixOS Tests / VM-Runner** | [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs) (`nixos/lib/testing/python.nix`) | Headless Python-basierte QEMU Test-Treiber für automatisierte Integrationstests (`testers.runNixOSTest`). |
| **CI Action** | [cachix/install-nix-action](https://github.com/cachix/install-nix-action) | Schnelle und deterministische Nix-Installation im GitHub Actions Runner. |

---

## 2. Maschinenlesbare Nachschlagequellen (Agenten)

Übernommen aus `docs/AGENT_SOURCES.md` (2026-10-15 zusammengelegt — **eine** Quellenliste).
Zweck: deterministische Anker gegen Halluzination von NixOS-Optionen, systemd-Direktiven
und API-Strukturen. Vollständige Liste: `lib/registry.nix`, `lib/service-contract.nix`,
`lib/hardening-profiles.nix`, `lib/memory-policy.nix`, Vorbild-Modul `55-playback/551-jellyfin.nix`.

Dieses Dokument dient LLM-Agenten als deterministischer Quellenanker, um Halluzinationen von NixOS-Optionen, systemd-Direktiven und API-Strukturen zu verhindern.

---

## 1. NixOS-Optionen: JSON-Quellen

| Quelle | URL / Zugriff | Format | Nutzen & Hinweis |
| :--- | :--- | :--- | :--- |
| **Eigene `nixosOptionsDoc`-Instanz** | `nix build .#nixosConfigurations.<host>.config.system.build.manual.optionsJSON` | JSON | **Die sauberste Lösung für das Repo.** Baut exakt die Optionen, die der Flake kennt – inkl. eigener Module und gepinnter nixpkgs-Version. |
| **Mayflower Hydra `options.json`** | `https://hydra.mayflower.de/build/13049625/download/1/options.json` | JSON (~11 MB) | Fertig gebautes Artefakt aus der offiziellen `nixos/release-small.nix`. Direkt via `jq` / Python parsbar. |
| **`search-nixos-api` (Hadi)** | `https://search-nixos-api.hadi.diy/search?q=<query>` | JSON | Öffentliche API für Nixpkgs, NixOS, Home-Manager, nix-darwin und NUR. Liefert Treffer mit `name`, `description`, `type`, `default`. |
| **NixOS Search Backend (Elasticsearch)** | `https://search.nixos.org/backend/latest-44-nixos-25.11/_search` | JSON | Die offizielle Such-API hinter `search.nixos.org`. Direkt abfragbar per HTTP POST mit Elasticsearch Query-DSL. |
| **Nix-Standardbibliothek (Noogle)** | `https://noogle.dev/api` | JSON | Maschinenlesbare API für Signaturen und Beispiele von `lib.*`-Funktionen. |

---

## 2. systemd: Direktiven & Manpages

| Quelle | URL / Zugriff | Format | Nutzen & Einsatzbereich |
| :--- | :--- | :--- | :--- |
| **`systemd.directives(7)` Index** | `https://www.freedesktop.org/software/systemd/man/latest/systemd.directives.html` | HTML (`<variablelist>`) | **Das vollständige Direktiven-Register.** Listet alle Unit-Direktiven (`Accept=`, `After=`, `CPUQuota=`, `DeviceAllow=`, `ExecReload=` …), gruppiert nach Kategorie. |
| **`systemd.directives.xml` (Quelle)** | `man/directives-template.xml` (systemd Git) | XML | Rohe XML-Quelle des Direktiven-Index, generiert per `make-directive-index.py` aus allen Manpage-XMLs. |
| **Manpage-XMLs (lokal)** | `/nix/store/*systemd*/share/doc/systemd/*.xml` | XML (DocBook) | Jede einzelne Manpage als XML. Extraktion aller Direktiven, Typen und Beschreibungen ohne HTML-Parsing. |
| **`systemd.exec(5)` & `systemd.service(5)`** | `https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html` | HTML | Härtungs- und Service-Direktiven im Detail (`ProtectSystem=`, `CapabilityBoundingSet=`, `SystemCallFilter=`). |
| **`systemd-analyze dump`** | CLI: `systemd-analyze dump` | Text | Gibt den internen Unit-Zustand des laufenden Init-Systems aus. |

---

## 3. systemd: D-Bus API (Laufzeit-Introspektion)

| Quelle | URL / Zugriff | Format | Nutzen & Einsatzbereich |
| :--- | :--- | :--- | :--- |
| **`org.freedesktop.systemd1(5)`** | `https://www.freedesktop.org/software/systemd/man/latest/org.freedesktop.systemd1.html` | HTML | **Vollständige D-Bus-API-Dokumentation.** Manager-Objekt, Unit-Objekte, Job-Objekte, Methoden, Properties, Signals. |
| **OpenAPI-Spezifikation (D-Bus als REST)** | `systemd-dbus-openapi.yaml` | YAML (OpenAPI 3.1) | Modelliert die systemd D-Bus-API als REST-Operationen. Ideal für maschinenlesbare Agenten-Abfragen. |
| **`busctl --json=pretty`** | CLI: `busctl introspect org.freedesktop.systemd1 /org/freedesktop/systemd1` | JSON | Direkte D-Bus-Introspektion mit strukturierter JSON-Ausgabe. |
| **`systemctl show --property=`** | CLI: `systemctl show <unit> --property=ProtectSystem,PrivateTmp` | Text / Key-Value | Jede `serviceConfig`-Option als D-Bus-Property abfragbar. Für Tests und Verifikation zur Laufzeit. |

---

## 4. NixOS/systemd-Tools für Agenten

| Tool | Zugriff | Zweck |
| :--- | :--- | :--- |
| **`nixos-options` Agent Skill** | `https://skillsmp.com/skills/qbisi/nixos-images/nixos-options` | Markdown-basierter Skill für deterministische NixOS-Optionssuche. |
| **`mcp-nixos`** | MCP-Server (`nixos_search`, `nixos_info`) | Direkte Tool-Aufrufe für LLMs, um NixOS-Optionen und Pakete zu inspizieren. |
| **`nixcfg-rs`** | `https://github.com/mushrowan/nixcfg-rs` | Rust-Brücke: JSON Schema → NixOS-Moduloptionen. |
| **`systemd-analyze security --json=pretty`** | CLI | Bewertet Härtung jeder Unit nach Punkten (0.0 = maximal sicher). Output ist maschinenlesbares JSON. |

---

## 5. Best Practices & Primärquellen

| Quelle | URL | Format |
| :--- | :--- | :--- |
| **NixOS Best Practices (Skill)** | `nixos-best-practices` (GitHub / SkillsMP) | Markdown |
| **Nixpkgs Integrationstests** | `https://github.com/NixOS/nixpkgs/tree/master/nixos/tests` | Nix (SSoT für fehlerfreie Dienst-Starts) |
| **NixOS Wiki** | `https://wiki.nixos.org/` | MediaWiki / API |
| **NixOS Manual** | `https://nixos.org/manual/nixos/stable/` | HTML / CommonMark |
| **nix.dev Tutorials** | `https://nix.dev/` | Markdown |
| **NixOS Discourse** | `https://discourse.nixos.org/latest.json` | JSON-API |

---

## 6. Lokale SSoT-Anker in mediNix-core

* **Dezimalrahmen & Identität:** [`/home/moritz/repos/mediNix-core/lib/registry.nix`](file:///home/moritz/repos/mediNix-core/lib/registry.nix) (`num`, `port`, `uid`, `gid`, `caddyClass`)
* **Dienst-Vertrag & Manifest-Schema:** [`/home/moritz/repos/mediNix-core/lib/service-contract.nix`](file:///home/moritz/repos/mediNix-core/lib/service-contract.nix) (`ui`, `monitoring`, `ops`, `sources`)
* **Service-Schablone (Dendritischer Goldstandard):** [`/home/moritz/repos/mediNix-core/55-playback/551-jellyfin.nix`](file:///home/moritz/repos/mediNix-core/55-playback/551-jellyfin.nix)
* **Zentrales Härtungsprofil:** [`/home/moritz/repos/mediNix-core/lib/hardening-profiles.nix`](file:///home/moritz/repos/mediNix-core/lib/hardening-profiles.nix)
* **Zentrale Memory- & OOM-Policy:** [`/home/moritz/repos/mediNix-core/lib/memory-policy.nix`](file:///home/moritz/repos/mediNix-core/lib/memory-policy.nix)
