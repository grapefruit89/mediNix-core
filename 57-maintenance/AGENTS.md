# LLM Wiki: `57-maintenance`

> **Zweck:** Wartung — Provisionierung, Backup, Drift-/Müll-Erkennung, Updates, Speicher-Tiering.

**Semantic Anchors:**
- Operational Pattern: `Lifecycle Management` · `Garbage Collection` (Drift detection, orphan cleanup, automated pruning)
- Reliability: `Defensive Programming` · `Poka-Yoke` (SQLite WAL checkpointing before shutdown, fail-closed storage bounds)
- Disaster Recovery: `Single Source of Truth` · `Least Privilege` (Restricted SSH pull keys, structured restic backups)

Alles **unterhalb der AUTO-GENERATED-Markierung** stammt aus den NIXMETA-Headern
(`python3 scripts/medinix-meta.py generate-docs`) — **nie** von Hand ändern, sonst
wird `check-docs` rot. Dieser manuelle Teil bleibt erhalten (den Marker-String
nicht wörtlich im Text nennen, sonst schneidet der Generator dort ab).

**Rolle:** Wartungs-/Betriebsdomäne (57x).

**Verantwortung:**
- Storage-Tiering (MergerFS + Verzeichnisstruktur), SQLite-WAL-Tuning
- `574` Provisioning — schreibt Kategorien/Indexer in die *arr-APIs (liest `manifest` und `arr.category`)
- Recyclarr-Sync, Update-Notifier (ntfy), Restic-Backup des A2-State, Drift-Detection, Orphan-Cleanup, SSH-Pull-User

**Nicht verantwortlich für:**
- die Dienste selbst → jeweilige Domäne
- Ingress/Auth → `51-ingress`; Monitoring → `58-observability`

**Source of truth:**
- Provisioning-Vertrag → `manifest` (Dienste) + `53-acquisition/538-provisioning.nix`
- zu schützender Zustand → `50-core/registry.nix` (`stateDir`)
- Ignorier-Listen (z. B. Orphan-Cleanup) leben im jeweiligen Modul

**Bekannte Klemmen:**
- `574` ist die einzige Stelle, die *arr-Kategorien gegen die API durchsetzt: eine Änderung an `arr.category` wirkt dort, nicht im *arr-Modul.
- Backup und Drift-Detection arbeiten auf `stateDir`-Pfaden aus der Registry — Änderungen daran sind Betriebseingriffe.


<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->

> ⚙️ **Maschinell erzeugt** aus den NIXMETA-Headern der Module (`python3 scripts/medinix-meta.py generate-docs`).
> **Nicht von Hand aendern** — handgepflegt ist nur der Teil **ueber** der Markierung; die Wahrheit steht in den unten verlinkten `.nix`-Dateien (`docs/CONVENTIONS.md` §1).

## Module Map

| ID | Modul-Datei | Status | Komplexitaet | Ports |
|---|---|---|---|---|
| `570-storage` | [`570-storage.nix`](570-storage.nix) | active | 3/5 | - |
| `571-sqlite-wal` | [`571-sqlite-wal.nix`](571-sqlite-wal.nix) | active | 3/5 | - |
| `575-update-notifier` | [`575-update-notifier.nix`](575-update-notifier.nix) | active | 3/5 | - |
| `576-backup` | [`576-backup.nix`](576-backup.nix) | active | 3/5 | - |
| `577-hygiene` | [`577-hygiene.nix`](577-hygiene.nix) | active | 3/5 | - |

## Interne Abhaengigkeiten (Requires)

Die Module in diesem Ordner benoetigen folgende Bibliotheken/Dateien:

- [`50-core/hardening-profiles`](../50-core/hardening-profiles.nix)
- [`50-core/registry`](../50-core/registry.nix)

## Dependency Graph

```mermaid
graph TD
  570_storage["570-storage"] --> hardening_profiles["50-core/hardening-profiles"]
  571_sqlite_wal["571-sqlite-wal"] --> hardening_profiles["50-core/hardening-profiles"]
  571_sqlite_wal["571-sqlite-wal"] --> registry["50-core/registry"]
  575_update_notifier["575-update-notifier"] --> hardening_profiles["50-core/hardening-profiles"]
  576_backup["576-backup"] --> hardening_profiles["50-core/hardening-profiles"]
  576_backup["576-backup"] --> registry["50-core/registry"]
  577_hygiene["577-hygiene"] --> hardening_profiles["50-core/hardening-profiles"]
```


---
*Maschinell erzeugt durch `python3 scripts/medinix-meta.py generate-docs` aus den NIXMETA-Headern der oben verlinkten `.nix`-Dateien. Handgepflegt ist nur der Teil ueber der AUTO-GENERATED-Markierung.*
