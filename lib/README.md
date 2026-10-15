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

## Nie verdrahtet (0 Importeure) — Entscheidung 2026-10-15: markiert, nicht geloescht

Diese 4 sind **kein Müll**, sondern geschriebene, aber **nie angeschlossene**
Utilities (in *keinem* Alt-Export referenziert). Teilweise ist ihre Aufgabe
heute **woanders** gelöst:

| Modul | Was es tut | Status heute |
|---|---|---|
| `abc-tiering.nix` | Storage-Layout `tierA/B/C` | **überholt** von `cfg.storage.backends.hot/cold` (`default.nix:221,230`) + `registry.stateDir` → **`status: deprecated`** |
| `mk-secure-curl.nix` | curl ohne Secret in `argv` (`--variable`) | **`status: deprecated`** — 513 hat den Fall am 2026-10-15 **nativ** geloest (`--variable token@datei` + `--expand-header`, curl >= 8.3; gepinnt 8.21.0). Das Modul war damit unnoetig |
| `wait-for-api.nix` | Readiness-Gate-Skript | **kein Consumer**: `arr_keys_sync.py` hat `wait_for_url` → **`status: draft`** |
| `_helpers.nix` | `recursiveMergeAttrs` (Listen konkatenieren) | redundant zu `lib.mkMerge` → **`status: deprecated`** |

→ Ergebnis: **markiert statt geloescht** — der Header-`status` macht den Zustand
maschinenlesbar (`nixmeta-check` prueft ihn); Loeschen bleibt spaeter moeglich.

## Einheitlicher Einstieg (Vorschlag)
Ein `lib/default.nix` als `medinixLib`-Bundle würde Mehrfach-Imports bündeln:
```nix
medinixLib = import ./lib { inherit lib config; };
inherit (medinixLib) profiles memoryPolicy creds;
```
Noch **nicht** angelegt (muss auf einer Nix-Maschine evaluiert werden).
