# TERMINOLOGY — etablierte Begriffe (Semantic Anchors)

> **Zweck:** Wir benutzen **etablierte Namen** statt Eigenschöpfungen. Referenz ist der
> Semantic-Anchors-Katalog (<https://llm-coding.github.io/Semantic-Anchors/>). Jeder
> Eintrag: **unser Konstrukt → Anker + Link**. Es stehen **nur** Namen aus dem Katalog
> hier — nichts Ausgedachtes.
>
> **Definitionen eingelagert:** englische Originale unter `docs/anchors/<id>.md`
> (Apache-2.0, © LLM-Coding) — offline lesbar; erneuern mit `scripts/fetch_anchors.py`.
>
> **Regel:** Methode/Konzept → **Anker nennen**. Fakt (Port/UID/Log) → **messen**
> (Anker steuert das Denken, die Messung liefert die Wahrheit).

## Dezimalrahmen (ADR-0000 — Kern des Repos)

| Konstrukt | Etablierter Anker |
|---|---|
| Eine `num` leitet Port, UID, UPG-GID, shared GID ab (§4) | [SSOT](anchors/ssot-principle.md) |
| Ableiten statt wiederholen (Port/UID/GID/stateDir) | [DRY](anchors/dry.md) |
| Engine-Invarianten I1–I4 (`50-core/501-decimal-engine.nix`, §4) | [Design by Contract](anchors/design-by-contract.md) |
| Falsche Kombination soll unmöglich sein | [Poka-Yoke](anchors/poka-yoke.md) |
| 10-Slot-Taxonomie `_0`..`_9` (§3) | [MECE](anchors/mece.md) |
| UPG vs. Zusatzgruppe `media` (§4) | [Principle of Least Privilege](anchors/least-privilege.md) |
| `registry.nix` = schmale, stabile Schnittstelle | [Deep Modules](anchors/deep-modules.md) |
| Wiedererkennbarkeit über Repos (§3, §10) | [ISO/IEC 25010](anchors/iso-25010.md) |
| Verworfene Alternativen (§9) | [MADR](anchors/madr.md) |

→ Ausführlich in [`docs/adr/ADR-0000-dezimalrahmen-verfassung.md`](adr/ADR-0000-dezimalrahmen-verfassung.md) §11.

## 51-ingress (Start)

| Unser Konstrukt | Etablierter Anker | Datei |
|---|---|---|
| Eine WAN-Tür (Caddy), Backends nur auf `127.0.0.1` | [Separation of Concerns](anchors/separation-of-concerns.md) + [Defense in Depth](anchors/defense-in-depth.md) | `511-caddy.nix` |
| „Chamäleon": global injizieren **oder** eigene `caddy-media`-Unit | [GoF-Strategy Pattern](anchors/gof-strategy-pattern.md) | `511-caddy.nix` |
| Caddyfile/Sites werden **aus dem Manifest gerendert** | [SSOT](anchors/ssot-principle.md) + [GoF-Template Method](anchors/gof-template-method-pattern.md) | `511-caddy.nix` |
| **Ein** Besitzer pro `users.users.<n>` (Engine, nicht Modul) | [SSOT](anchors/ssot-principle.md) | `512`, `513`, Engine |
| DDNS-/ACME-Token **getrennt**, Token nie in `argv`, `NoExecPaths` | [Principle of Least Privilege](anchors/least-privilege.md) + [Defense in Depth](anchors/defense-in-depth.md) | `513`, `514` |
| mDNS-Alias: Retry + Alive-Check + `trap cleanup` | [Defensive Programming](anchors/defensive-programming.md) | `515-mdns.nix` |
| **Ein** Edge-Bouncer (CrowdSec), **ein** Log-Sink (journald) | [SSOT](anchors/ssot-principle.md) + [Defense in Depth](anchors/defense-in-depth.md) | `516`, journald |
| 519 verbietet Fremd-Stacks (nginx/httpd/iptables), fail-closed | [Poka-Yoke](anchors/poka-yoke.md) + [Design by Contract](anchors/design-by-contract.md) | `519-ingress-guardrails.nix` |
| vHost-Zugriff = ein deklarierter `accessGroup`-Vertrag | [Design by Contract](anchors/design-by-contract.md) | `510-ingress-SERVICE.md` |

## Querschnitt (ganzes Repo)

| Unser Konstrukt | Etablierter Anker |
|---|---|
| `50-core/registry.nix` = einzige Quelle für Port/UID/caddyClass | [SSOT](anchors/ssot-principle.md) |
| `50-core/service-factory.nix` erzeugt Units aus einem Deskriptor | [GoF-Factory Method](anchors/gof-factory-method-pattern.md) |
| Härtung **nur** aus `50-core/hardening-profiles.nix` | [SSOT](anchors/ssot-principle.md) + [DRY](anchors/dry.md) |
| Assertions brechen den Build ab (fail-closed) | [Design by Contract](anchors/design-by-contract.md) + [Poka-Yoke](anchors/poka-yoke.md) + [Andon](anchors/andon.md) |
| „messen → verstehen → Diff → Go" | [Genchi Genbutsu](anchors/genchi-genbutsu.md) + [PDCA](anchors/pdca.md) |
| Nach 2 Fehlversuchen am selben Punkt **STOPP** | [Andon](anchors/andon.md) |
| Backup → **eine** Änderung → messen → Rollback | [PDCA](anchors/pdca.md) |
| „markiert statt gelöscht" (nie verdrahtete Module des damaligen Altordners) | [Chesterton's Fence](anchors/chestertons-fence.md) |
| Keine Container/netns, systemd-native | [Unix Philosophy](anchors/unix-philosophy.md) + [Principle of Least Privilege](anchors/least-privilege.md) |
| Architektur-Entscheidungen (`docs/adr/`) | [ADR according to Nygard](anchors/adr-according-to-nygard.md) (+ [MADR](anchors/madr.md)) |
| `arr-settings` = Konfig per `SONARR__…`-Env-Vars | [Twelve-Factor App](anchors/twelve-factor-app.md) |
| Rails/Tests: Port-Riegel, Negativtests, Voll-Stack-Ratsche | [Testing Pyramid](anchors/testing-pyramid.md) + [Design by Contract](anchors/design-by-contract.md) |
| Service Map / TODO / Runbook **generiert** aus Quellen | [Docs-as-Code](anchors/docs-as-code.md) + [SSOT](anchors/ssot-principle.md) + [Diátaxis](anchors/diataxis-framework.md) |
| Refactor im Bestand statt Neubau | [Mikado Method](anchors/mikado-method.md) + [Strangler Fig](anchors/strangler-fig.md) |

## 52-security

| Unser Konstrukt | Etablierter Anker | Datei |
|---|---|---|
| media-GID, break-glass-User, sysctl, LUKS+TPM2 | [Defense in Depth](anchors/defense-in-depth.md) + [Principle of Least Privilege](anchors/least-privilege.md) | `520-core-security.nix` |
| sudo-Allowlist des Notfall-Users (nur feste restart-Kommandos) | [Principle of Least Privilege](anchors/least-privilege.md) | `520` |
| Genau **ein** Paketfilter-Eigentümer (firewall XOR nftables) | [SSOT](anchors/ssot-principle.md) | `520` |
| Nur versiegelte Credentials (`LoadCredentialEncrypted`) | [Design by Contract](anchors/design-by-contract.md) + [Principle of Least Privilege](anchors/least-privilege.md) | `521-creds.nix` |
| WireGuard-Interface flake-verwaltet | [Defense in Depth](anchors/defense-in-depth.md) | `525-vpn-interface.nix` |
| VPN-Killswitch (`meta skuid` + Route-Hook, fail-closed) | [Poka-Yoke](anchors/poka-yoke.md) + [Defense in Depth](anchors/defense-in-depth.md) | `526-vpn-killswitch.nix` |

## 50-core/ (Hilfsbibliotheken)

| Modul / Konstrukt | Etablierter Anker |
|---|---|
| `registry.nix` — SSoT für Port/UID/GID/stateDir | [SSOT](anchors/ssot-principle.md) |
| `service-factory.nix` — `mkService` erzeugt User/Unit/tmpfiles | [GoF-Factory Method](anchors/gof-factory-method-pattern.md) |
| `service-contract.nix` — Manifest-Schema + Assertions | [Design by Contract](anchors/design-by-contract.md) |
| `hardening-profiles.nix` — einzige Härtungsquelle | [SSOT](anchors/ssot-principle.md) + [DRY](anchors/dry.md) |
| `memory-policy.nix` — zentrale OOM-/cgroup-Policy je Dienst | [SSOT](anchors/ssot-principle.md) + [Bulkhead Pattern](anchors/bulkhead.md) |
| `creds.nix` — Pfadkonvention für Secrets | [Design by Contract](anchors/design-by-contract.md) |
| `arr-settings.nix` — Config per Env-Var | [Twelve-Factor App](anchors/twelve-factor-app.md) |
| `decimal-framework.nix` — Decimal-Engine (ADR-0000) | [SSOT](anchors/ssot-principle.md) |
| `cli.nix` + `runbook.json` — Betrieb/Triage | [Site Reliability Engineering](anchors/site-reliability-engineering.md) |
| `smoke-test.nix` — Eval-Smoke-Test | [Testing Pyramid](anchors/testing-pyramid.md) |
| Kleine Module, schmale Schnittstelle, ein Zweck | [Deep Modules](anchors/deep-modules.md) + [Separation of Concerns](anchors/separation-of-concerns.md) |
| 4 nie verdrahtete Module am 2026-10-16 archiviert (`docs/audit/`) | [YAGNI](anchors/yagni.md) + [Chesterton's Fence](anchors/chestertons-fence.md) |

## 53-acquisition (Arr-Stack & Provisioning)

| Modul / Konstrukt | Etablierter Anker | Datei |
|---|---|---|
| Konfiguration über Env-Variablen (`SONARR__*`) | [Twelve-Factor App](anchors/twelve-factor-app.md) | `532-sonarr.nix`..`536-prowlarr.nix` |
| Isolierte UPG-Dienstkonten (`sonarr`, `radarr`, etc.) | [Principle of Least Privilege](anchors/least-privilege.md) | `532`..`536` |
| Provisioning-Reactor via Kernel-epoll ohne Polling-Sleep | [Poka-Yoke](anchors/poka-yoke.md) + [Design by Contract](anchors/design-by-contract.md) | `538-provisioning.nix` |
| Recyclarr deklarativer Trash-Guides-Sync | [Docs-as-Code](anchors/docs-as-code.md) + [SSOT](anchors/ssot-principle.md) | `537-recyclarr.nix` |

## 54-processing (Downloader & Data Mover)

| Modul / Konstrukt | Etablierter Anker | Datei |
|---|---|---|
| SABnzbd strikt im VPN-Namespace isoliert | [Bulkhead Pattern](anchors/bulkhead.md) + [Defense in Depth](anchors/defense-in-depth.md) | `541-sabnzbd.nix` |
| Speichertier-Entkopplung (Fast NVMe Ingestion vs. SATA Array) | [Separation of Concerns](anchors/separation-of-concerns.md) | `543-mover.nix` |
| Mover Mount-Checks: Abbruch bei fehlendem Ziel (fail-closed) | [Defensive Programming](anchors/defensive-programming.md) + [Poka-Yoke](anchors/poka-yoke.md) | `543-mover.nix` |

## 55-playback (Media Streaming)

| Modul / Konstrukt | Etablierter Anker | Datei |
|---|---|---|
| Jellyfin: Read-Only Medien-Mounts, flüchtiges Transcode-Tmpfs | [Principle of Least Privilege](anchors/least-privilege.md) + [Separation of Concerns](anchors/separation-of-concerns.md) | `551-jellyfin.nix` |
| Navidrome / Audiobookshelf: Eigene UPG-UIDs, dedizierte Caches | [Bulkhead Pattern](anchors/bulkhead.md) + [Principle of Least Privilege](anchors/least-privilege.md) | `552`, `553` |

## 56-exposition (Portal & Ingress Boundary)

| Modul / Konstrukt | Etablierter Anker | Datei |
|---|---|---|
| Seerr: Entkoppelte Anfrage-Schnittstelle ohne Direktzugriff aufs Array | [Separation of Concerns](anchors/separation-of-concerns.md) + [Defense in Depth](anchors/defense-in-depth.md) | `561-seerr.nix` |

## 57-maintenance (Storage & Lifecycle Hygiene)

| Modul / Konstrukt | Etablierter Anker | Datei |
|---|---|---|
| Storage-Tiering-Hierarchie (NVMe-Cache, SATA-Array) | [SSOT](anchors/ssot-principle.md) + [Design by Contract](anchors/design-by-contract.md) | `570-storage.nix` |
| SQLite WAL Checkpointing vor Shutdown | [Defensive Programming](anchors/defensive-programming.md) + [Poka-Yoke](anchors/poka-yoke.md) | `571-sqlite-wal.nix` |
| SSH-Backup mit restriktivem Command-Key | [Principle of Least Privilege](anchors/least-privilege.md) + [Defense in Depth](anchors/defense-in-depth.md) | `576-backup.nix`, `579-backup-ssh.nix` |
| Drift-Detection & Orphan-Cleanup (Verwaiste Artefakte entfernen) | [YAGNI](anchors/yagni.md) + [Design by Contract](anchors/design-by-contract.md) | `577`, `578` |

## 58-observability (Telemetry & Health Gates)

| Modul / Konstrukt | Etablierter Anker | Datei |
|---|---|---|
| ntfy: Sofortige Push-Benachrichtigung bei Service-Fehlern | [Andon](anchors/andon.md) | `581-ntfy.nix` |
| Gatus / Exporters: Synthetische Health-Checks & Prometheus-Metriken | [Site Reliability Engineering](anchors/site-reliability-engineering.md) | `582-gatus.nix`, `585-exporters.nix` |
| Runtime-Guard & Post-Boot-Watchdog: Früherkennung von Systemdrift | [Poka-Yoke](anchors/poka-yoke.md) + [Andon](anchors/andon.md) | `583`, `584` |
| VPN-Selftest: Regelmäßige Validierung der externen IP-Maskierung | [Defense in Depth](anchors/defense-in-depth.md) + [Poka-Yoke](anchors/poka-yoke.md) | `586-vpn-selftest.nix` |
| SMART Disk Health mit HDD-Spindown-Erhalt | [Site Reliability Engineering](anchors/site-reliability-engineering.md) | `587-disk-health.nix` |

## 59-guardrails (Compile-Time Assertions)

| Modul / Konstrukt | Etablierter Anker | Datei |
|---|---|---|
| Cross-Domain Invarianten: Evaluierungsabbruch bei Regelbruch (fail-closed) | [Design by Contract](anchors/design-by-contract.md) + [Poka-Yoke](anchors/poka-yoke.md) | `591-cross-domain.nix` |
