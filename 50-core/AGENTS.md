# LLM Wiki: `50-core`

> **Zweck:** [BITTE MANUELL AUSFUELLEN: Wofuer ist dieser Ordner zustaendig?]


<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->

> ⚙️ **Maschinell erzeugt** aus den NIXMETA-Headern der Module (`python3 50-core/medinix-meta.py generate-docs`).
> **Nicht von Hand aendern** — handgepflegt ist nur der Teil **ueber** der Markierung; die Wahrheit steht in den unten verlinkten `.nix`-Dateien (`docs/CONVENTIONS.md` §1).

## Module Map

| ID | Modul-Datei | Status | Komplexitaet | Ports |
|---|---|---|---|---|
| `500-host-baseline` | [`500-host-baseline.nix`](500-host-baseline.nix) | active | 1/5 | - |
| `501-decimal-engine` | [`501-decimal-engine.nix`](501-decimal-engine.nix) | active | 1/5 | - |
| `502-host-settings` | [`502-host-settings.nix`](502-host-settings.nix) | active | 1/5 | - |
| `503-host-integration` | [`503-host-integration.nix`](503-host-integration.nix) | active | 3/5 | - |

## Interne Abhaengigkeiten (Requires)

Die Module in diesem Ordner benoetigen folgende Bibliotheken/Dateien:


## Dependency Graph

```mermaid
graph TD
  500_host_baseline["500-host-baseline"]
  501_decimal_engine["501-decimal-engine"]
  502_host_settings["502-host-settings"]
  503_host_integration["503-host-integration"]
```


---
*Maschinell erzeugt durch `python3 50-core/medinix-meta.py generate-docs` aus den NIXMETA-Headern der oben verlinkten `.nix`-Dateien. Handgepflegt ist nur der Teil ueber der AUTO-GENERATED-Markierung.*
