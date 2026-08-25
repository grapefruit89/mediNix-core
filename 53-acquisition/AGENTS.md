# LLM Wiki: `53-acquisition`

> **Zweck:** [BITTE MANUELL AUSFUELLEN: Wofuer ist dieser Ordner zustaendig?]


<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->

## Module Map

| ID | Modul-Datei | Status | Komplexitaet | Ports |
|---|---|---|---|---|
| `532-sonarr` | `532-sonarr.nix` | active | 3/5 | - |
| `533-radarr` | `533-radarr.nix` | active | 3/5 | - |
| `534-readarr` | `534-readarr.nix` | active | 3/5 | - |
| `535-lidarr` | `535-lidarr.nix` | active | 3/5 | - |
| `536-prowlarr` | `536-prowlarr.nix` | active | 3/5 | - |

## Interne Abhaengigkeiten (Requires)

Die Module in diesem Ordner benoetigen folgende Bibliotheken/Dateien:

- `lib/arr-settings`
- `lib/registry`
- `lib/service-factory`

## Dependency Graph

```mermaid
graph TD
  532_sonarr["532-sonarr"] --> arr_settings["lib/arr-settings"]
  532_sonarr["532-sonarr"] --> service_factory["lib/service-factory"]
  532_sonarr["532-sonarr"] --> registry["lib/registry"]
  533_radarr["533-radarr"] --> arr_settings["lib/arr-settings"]
  533_radarr["533-radarr"] --> service_factory["lib/service-factory"]
  533_radarr["533-radarr"] --> registry["lib/registry"]
  534_readarr["534-readarr"] --> arr_settings["lib/arr-settings"]
  534_readarr["534-readarr"] --> service_factory["lib/service-factory"]
  534_readarr["534-readarr"] --> registry["lib/registry"]
  535_lidarr["535-lidarr"] --> arr_settings["lib/arr-settings"]
  535_lidarr["535-lidarr"] --> service_factory["lib/service-factory"]
  535_lidarr["535-lidarr"] --> registry["lib/registry"]
  536_prowlarr["536-prowlarr"] --> arr_settings["lib/arr-settings"]
  536_prowlarr["536-prowlarr"] --> service_factory["lib/service-factory"]
  536_prowlarr["536-prowlarr"] --> registry["lib/registry"]
```


---
*Generiert durch `medinix-meta.py generate-docs`*
