# LLM Wiki: `53-acquisition`

> **Zweck:** [BITTE MANUELL AUSFUELLEN: Wofuer ist dieser Ordner zustaendig?]


<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->

> ⚙️ **Maschinell erzeugt** aus den NIXMETA-Headern der Module (`python3 50-core/medinix-meta.py generate-docs`).
> **Nicht von Hand aendern** — handgepflegt ist nur der Teil **ueber** der Markierung; die Wahrheit steht in den unten verlinkten `.nix`-Dateien (`docs/CONVENTIONS.md` §1).

## Module Map

| ID | Modul-Datei | Status | Komplexitaet | Ports |
|---|---|---|---|---|
| `532-sonarr` | [`532-sonarr.nix`](532-sonarr.nix) | active | 3/5 | - |
| `533-radarr` | [`533-radarr.nix`](533-radarr.nix) | active | 3/5 | - |
| `534-readarr` | [`534-readarr.nix`](534-readarr.nix) | active | 3/5 | - |
| `535-lidarr` | [`535-lidarr.nix`](535-lidarr.nix) | active | 3/5 | - |
| `536-prowlarr` | [`536-prowlarr.nix`](536-prowlarr.nix) | active | 3/5 | - |

## Interne Abhaengigkeiten (Requires)

Die Module in diesem Ordner benoetigen folgende Bibliotheken/Dateien:

- [`lib/arr-settings`](../lib/arr-settings.nix)
- [`lib/hardening-profiles`](../lib/hardening-profiles.nix)
- [`lib/memory-policy`](../lib/memory-policy.nix)
- [`lib/registry`](../lib/registry.nix)
- [`lib/service-factory`](../lib/service-factory.nix)

## Dependency Graph

```mermaid
graph TD
  532_sonarr["532-sonarr"] --> arr_settings["lib/arr-settings"]
  532_sonarr["532-sonarr"] --> service_factory["lib/service-factory"]
  532_sonarr["532-sonarr"] --> registry["lib/registry"]
  532_sonarr["532-sonarr"] --> hardening_profiles["lib/hardening-profiles"]
  532_sonarr["532-sonarr"] --> memory_policy["lib/memory-policy"]
  533_radarr["533-radarr"] --> arr_settings["lib/arr-settings"]
  533_radarr["533-radarr"] --> service_factory["lib/service-factory"]
  533_radarr["533-radarr"] --> registry["lib/registry"]
  533_radarr["533-radarr"] --> hardening_profiles["lib/hardening-profiles"]
  533_radarr["533-radarr"] --> memory_policy["lib/memory-policy"]
  534_readarr["534-readarr"] --> arr_settings["lib/arr-settings"]
  534_readarr["534-readarr"] --> service_factory["lib/service-factory"]
  534_readarr["534-readarr"] --> registry["lib/registry"]
  534_readarr["534-readarr"] --> hardening_profiles["lib/hardening-profiles"]
  534_readarr["534-readarr"] --> memory_policy["lib/memory-policy"]
  535_lidarr["535-lidarr"] --> arr_settings["lib/arr-settings"]
  535_lidarr["535-lidarr"] --> service_factory["lib/service-factory"]
  535_lidarr["535-lidarr"] --> registry["lib/registry"]
  535_lidarr["535-lidarr"] --> hardening_profiles["lib/hardening-profiles"]
  535_lidarr["535-lidarr"] --> memory_policy["lib/memory-policy"]
  536_prowlarr["536-prowlarr"] --> arr_settings["lib/arr-settings"]
  536_prowlarr["536-prowlarr"] --> service_factory["lib/service-factory"]
  536_prowlarr["536-prowlarr"] --> registry["lib/registry"]
  536_prowlarr["536-prowlarr"] --> hardening_profiles["lib/hardening-profiles"]
  536_prowlarr["536-prowlarr"] --> memory_policy["lib/memory-policy"]
```


---
*Maschinell erzeugt durch `python3 50-core/medinix-meta.py generate-docs` aus den NIXMETA-Headern der oben verlinkten `.nix`-Dateien. Handgepflegt ist nur der Teil ueber der AUTO-GENERATED-Markierung.*
