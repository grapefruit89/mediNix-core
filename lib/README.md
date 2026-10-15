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
| `arr-settings.nix` | `{ lib }` | *arr-Config → .NET-Env-Vars | **6** |
| `creds.nix` | `{ lib }` | Pfadkonvention für Secrets | **5** |
| `cli.nix` | `{ pkgs, registryJson, … }` | `packages.medinix` CLI | 2 |
| `decimal-framework.nix` | `{ lib, config }` | Decimal-Engine (ADR-0000) | 1 |
| `service-contract.nix` | `{ config, lib }` | **NixOS-Modul**: `medinix.manifest`-Schema + Assertions | 1 |
| `smoke-test.nix` | `{ config, lib }` | **NixOS-Modul**: Eval-Smoke-Test | 1 |
| `arr-provision/` | (Python-Paket) | `packages.arr-provision` | – |

## Nie verdrahtet (0 Importeure) — Entscheidung offen

Diese 4 sind **kein Müll**, sondern geschriebene, aber **nie angeschlossene**
Utilities (in *keinem* Alt-Export referenziert). Teilweise ist ihre Aufgabe
heute **woanders** gelöst:

| Modul | Was es tut | Status heute |
|---|---|---|
| `abc-tiering.nix` | Storage-Layout `tierA/B/C` (ADR-5043) | **überholt** von `cfg.storage.backends.hot/cold` (`default.nix:221,230`) + `registry.stateDir` |
| `mk-secure-curl.nix` | curl ohne Secret in `argv` (`--variable`) | **nicht nötig**: Provisioning läuft über Python (`arr-provision`, Header in-process) |
| `wait-for-api.nix` | Readiness-Gate-Skript | **nicht nötig**: `arr_keys_sync.py` hat `wait_for_url` |
| `_helpers.nix` | `recursiveMergeAttrs` (Listen konkatenieren) | generisch, ungenutzt |

→ Pro Modul: **verdrahten** · **bewusst ablegen** · **löschen** (nicht stilllegen ohne Analyse).

## Einheitlicher Einstieg (Vorschlag)
Ein `lib/default.nix` als `medinixLib`-Bundle würde Mehrfach-Imports bündeln:
```nix
medinixLib = import ./lib { inherit lib config; };
inherit (medinixLib) profiles memoryPolicy creds;
```
Noch **nicht** angelegt (muss auf einer Nix-Maschine evaluiert werden).
