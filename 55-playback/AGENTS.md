# LLM Wiki: `55-playback`

> **Zweck:** [BITTE MANUELL AUSFUELLEN: Wofuer ist dieser Ordner zustaendig?]


<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->

## Module Map

| ID | Modul-Datei | Status | Komplexitaet | Ports |
|---|---|---|---|---|
| `551-jellyfin` | `551-jellyfin.nix` | active | 3/5 |  |
| `552-audiobookshelf` | `552-audiobookshelf.nix` | active | -/5 | - |
| `553-navidrome` | `553-navidrome.nix` | active | -/5 | - |
| `554-feishin` | `554-feishin.nix` | active | -/5 | - |

## Interne Abhaengigkeiten (Requires)

Die Module in diesem Ordner benoetigen folgende Bibliotheken/Dateien:

- `lib/creds`
- `lib/hardening-profiles`
- `lib/memory-policy`
- `lib/registry`
- `lib/service-factory`

## Dependency Graph

```mermaid
graph TD
  551_jellyfin["551-jellyfin"] --> registry["lib/registry"]
  551_jellyfin["551-jellyfin"] --> service_factory["lib/service-factory"]
  551_jellyfin["551-jellyfin"] --> hardening_profiles["lib/hardening-profiles"]
  551_jellyfin["551-jellyfin"] --> memory_policy["lib/memory-policy"]
  551_jellyfin["551-jellyfin"] --> creds["lib/creds"]
  552_audiobookshelf["552-audiobookshelf"]
  553_navidrome["553-navidrome"]
  554_feishin["554-feishin"]
```


---
*Generiert durch `medinix-meta.py generate-docs`*
