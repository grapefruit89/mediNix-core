# lib/ — Hilfsbibliotheken

Zentraler Ordner für **Nix-Hilfsfunktionen und Engines**.

> **Kein Modul-Ordner.** `lib/` wird **nicht** auto-importiert (das tun nur die
> `NN-`-Domain-Ordner via `default.nix`). Die Dateien hier sind reine
> Funktionen/Attrsets, die per `import ./lib/<datei>.nix { … }` genutzt werden.

## Live-Module (mit Importeur)

| Modul | Signatur | Zweck | Importeure |
|---|---|---|---|
| `registry.nix` | `{ lib }` | **SSoT** für Ports/UID/GID/stateDir (Decimal-Framework) | **24** |
| `hardening-profiles.nix` | `{ lib }` | systemd-Hardening-Profile (`base`/`network`/…) | **17** |
| `service-factory.nix` | `{ lib, config }` | `mkService` — erzeugt User/Unit/tmpfiles | **10** |
| `memory-policy.nix` | `{ lib, config }` | OOMScore/CPU-/IO-Weight je Dienst | **7** |
| `derive.nix` | – | UID/GID/Port Ableitung | 3 |
| `cli.nix` | `{ pkgs, registryJson, … }` | `packages.medinix` CLI | 2 |
| `decimal-framework.nix` | `{ lib, config }` | Decimal-Engine (ADR-0000) | 1 |
| `manifest.nix` | `{ lib }` | **SSoT**: Manifest-Schema v1 Helper (`mkManifestEntry`) | 1 |
| `service-contract.nix` | `{ config, lib }` | **NixOS-Modul**: `medinix.manifest`-Schema + Assertions | 1 |
| `smoke-test.nix` | `{ config, lib }` | **NixOS-Modul**: Eval-Smoke-Test | 1 |
| `vm-smoke-test.nix` | `{ config, lib }` | VM Smoke-Test Modul | 1 |
| `arr-provision/` | (Python-Paket) | `packages.arr-provision` | – |

## In Domänen umgezogen (Domänenspezifische Helfer)
| Ehemalige Datei | Neuer Speicherort | Zweck |
|---|---|---|
| `lib/ingress-access.nix` | `51-ingress/ingress-access.nix` | SSOT für effektive vHost-Exposure & Access-Groups |
| `lib/creds.nix` | `52-security/creds.nix` | Sealed-only systemd-creds Pfadprüfung |
| `lib/arr-settings.nix` | `53-acquisition/arr-settings.nix` | *arr-Config → .NET-Env-Vars |

## Nie verdrahtet (0 Importeure) — Entscheidung 2026-10-15: markiert, nicht geloescht

Diese 4 waren **nie angeschlossene** Utilities (0 Importeure, in *keinem*
Alt-Export referenziert). Am 2026-10-16 **archiviert** → `docs/audit/2026-10-16/repo-cleanup/lib/`
(operativ entfernt, **Wissen bleibt**); ihre Aufgaben sind heute **woanders** gelöst:

| Modul | Was es tat | Heute gelöst durch |
|---|---|---|
| `abc-tiering.nix` | Storage-Layout `tierA/B/C` | `cfg.storage.backends.hot/cold` + `registry.stateDir` |
| `mk-secure-curl.nix` | curl ohne Secret in `argv` | nativ in `513` (`--variable` + `--expand-header`, curl ≥ 8.3) |
| `wait-for-api.nix` | Readiness-Gate | `arr_keys_sync.py` → `wait_for_url` |
| `_helpers.nix` | `recursiveMergeAttrs` | `lib.mkMerge` |

## Einheitlicher Einstieg (Vorschlag)
Ein `lib/default.nix` als `medinixLib`-Bundle würde Mehrfach-Imports bündeln:
```nix
medinixLib = import ./lib { inherit lib config; };
inherit (medinixLib) profiles memoryPolicy creds;
```
Noch **nicht** angelegt (muss auf einer Nix-Maschine evaluiert werden).
