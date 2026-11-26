---
status: active
type: log
tags: [scratchboard, staging, befund, governance]
summary: "Scratchboard: Eingang für Befunde, Bugs und Änderungswünsche. Erst Zeile erfassen, verifizieren, dann in Batches abarbeiten und verteilen."
---

# SCRATCHBOARD — Eingang für Befunde & Änderungswünsche

> **Regel R0:** Befunde immer zuerst ins Scratchboard — kein ungefragtes Direkt-Patching.
> Jede Beobachtung wird eine Zeile mit Typ, Bereich, Beleg und Status. Erst nach Review/Planung
> wird die Behebung chirurgisch umgesetzt und verifiziert.

---

## 1. Zeilen-Register

| ID | Typ | Bereich | Befund (1 Satz) | Beleg | Lösung / Ziel | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| K-01 | BUG | Ingress | Speedport-Credential überschreibt Cloudflare-Token per Attrset-Merge (`//`). | `513-ddns.nix:335-416` | Zusammenführung in eine einzige Liste `LoadCredentialEncrypted`; Ratsche `mediNix-ddns-speedport-multi-cred` | behoben |
| K-02 | BUG | Ingress/UPG | `517-oauth2-proxy.nix` fehlte Primärgruppe GID 5170 und Manifest-Eintrag. | `517-oauth2-proxy.nix` | `medinix.manifest.oauth2-proxy` registriert (Slot 517), UPG auto-abgeleitet; Ratsche `mediNix-oauth2-proxy-upg` | behoben |
| M-01 | RISK | Ingress | Globale `unauthenticatedPaths` umgehen Ack-Assertion auf Public-Vhosts. | `511-caddy.nix:294-297` | `publicBypassPaths` prüft nur vhost-spezifische `unauthenticatedPathsOf` | behoben |
| M-02 | GAP | Ingress | Port 53 (TCP/UDP) für LAN-Clients blockiert bei `firewall = "managed"`. | `515-blocky.nix` | Port 53 TCP/UDP automatisch in `allowedTCPPorts`/`allowedUDPPorts` geöffnet | behoben |
| M-03 | GAP | Ingress | Guardrail bricht Hosts mit legitimer `nftables`-Nutzung (`firewall = false`). | `519-ingress-guardrails.nix:31` | `keepOn.firewall` akzeptiert auch `networking.nftables.enable` | behoben |
| M-04 | RISK | Ingress | Cloudflare-Apex-Update könnte fremde Records ohne mediNix-Kommentar antasten. | `513-ddns.nix:151-163` | `update_record` filtert strikt auf `.comment == "managed-by=mediNix-core/513"` | behoben |
| B-01 | RISK | Core/Tooling | Nicht-kanonische Nix-Formatter (alejandra, nixpkgs-fmt) bergen Risiko für Format-Kriege und Ablenkung. | Resteküche & BANNED_TECHNOLOGIES.md | In `50-core/BANNED_TECHNOLOGIES.md` und `scripts/check_banned_technologies.py` sperren (SSoT: `nixfmt` / `nixfmt-rfc-style`) | behoben |
| R-98a | DEBT | Acquisition/Tooling | `packages/arr-provision` ist in 8 lose `arr-sync-*`-Einzel-CLIs und 8 Wrapper-Derivations zersplittert und nutzt in `common.py` eine serielle `time.sleep()`-HTTP-Polling-Schleife (`wait_for_url`). | `packages/arr-provision/default.nix:23-90`, `packages/arr-provision/arr_provision/common.py:49-74`, `todo/tasks.json` (`R98`) | Bündelung in eine Derivation + ein modulares CLI `arr-provision <subcommand>` (`--debug`, `--dry-run`, Symlink-Aliase `arr-sync-*`) mit kernel-/journal-eventbasierter Readiness (`selectors.EpollSelector` + `journalctl --follow` + `signal.set_wakeup_fd` in `events.py`). | behoben |
| R-98b | BUG | Acquisition/ADR-0010 | `prowlarr_sync.py` verletzt ADR-0010 §2.3 durch direktes `sqlite3.connect(PROWLARR_DB)`/`UPDATE ScheduledTasks` gegen den laufenden Daemon, während `536-prowlarr.nix` noch `update.mechanism = "BuiltIn"` setzt. | `packages/arr-provision/arr_provision/prowlarr_sync.py:117-131`, `53-acquisition/536-prowlarr.nix:163`, `53-acquisition/538-provisioning.nix:208` | SQLite-Zugriff und `PROWLARR_DB` vollständig entfernen; `536-prowlarr.nix` auf `update.mechanism = "External"` umstellen und Task-/Host-Config ausschließlich über Prowlarr-REST-API abgleichen. | behoben |
| R-98c | BUG | Acquisition/Hardening | `arr_keys_sync.py` und `locale_sync.py` versuchen als `User = media` unter `ProtectSystem = "strict"` Dateien in `/var/lib/sabnzbd` und `/var/lib/jellyfin` zu schreiben und `systemctl restart` aufzurufen; `541-sabnzbd.nix` lädt zudem `sabnzbd-api-key`, seedet ihn aber nicht vor Start. | `packages/arr-provision/arr_provision/arr_keys_sync.py:27-85`, `packages/arr-provision/arr_provision/locale_sync.py:15-89`, `53-acquisition/538-provisioning.nix:150-222`, `54-processing/541-sabnzbd.nix:280-282` | Gemäß ADR-0010 §2.1 SABnzbd-Key-Seed in `541-sabnzbd.nix` `preStart` verlegen; `keys`-Modul strikt read-only per REST, `locale`-Modul komplett auf Jellyfin-/SABnzbd-REST-APIs umstellen; `SAB_INI_FILE`, `JELLYFIN_CONFIG` und `sabnzbd.ini`-Key-Fallback in `538-provisioning.nix` streichen. | behoben |
| R-98d | GAP | Acquisition/Sandbox | `mediNix-provision.service` erbt über `profiles.client` `PrivateUsers = true`, was mit `SupplementaryGroups = [ "systemd-journal" ]` den Lesezugriff auf das Host-Journal im User-Namespace blockieren würde. | `50-core/hardening-profiles.nix:93`, `50-core/hardening-profiles.nix:193-197`, `53-acquisition/538-provisioning.nix:144` | In `50-core/hardening-profiles.nix:93` `PrivateUsers = lib.mkDefault true;` setzen (ohne verbotenes `lib.mkForce`) und in `538-provisioning.nix` `SupplementaryGroups = [ "systemd-journal" ]; PrivateUsers = false;` aktivieren; Konfiguration über eine zentrale JSON (`arr-provision-config.json`) liefern. | behoben |
| D-01 | DEBT | Docs | 21 Dateien in `concepts/`, `guides/`, `modules/`, `examples/` sind zu 80% redundant gegen ADRs und ohne Code-Bezug. | Audit task-5177, `docs/` Mini-Ordner | Variante A umsetzen (21 → 7 Dateien, 9 Guides & Fragmente nach `docs/audit/2026-11/docs-consolidation/` archivieren, Kernwissen in ADRs/Navigation konsolidieren). | behoben |
| G-01 | GOV | Governance/AI | Fehlende verbindliche Quellen-Hierarchie für Recherche-Subagenten birgt Halluzinations- und Altlasten-Risiko. | User-Vorgabe (Meister/Rechercheur) | Dreistufige Ground-Truth-Whitelist (1. Lokale Verfassung, 2. Offizieller Upstream, 3. Blacklist) in `CONVENTIONS.md` und `GEMINI.md` versiegeln. | behoben |
| S-01 | ENH | Architecture/Vocabulary | Voll-Rollout Semantic Anchors über alle verbleibenden mediNix-Module (NIXMETA-Header) und kontinuierliche Begriffs-Präzisierung. | User-Auftrag 2026-11-26, docs/TERMINOLOGY.md | Schrittweise alle restlichen .nix-Module mit englischen Semantic Anchors versehen und als feste LLM-Denkplanke verankern. | offen |
