# LLM Wiki: `54-transfer`

> **Zweck:** [BITTE MANUELL AUSFUELLEN: Wofuer ist dieser Ordner zustaendig?]


<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->

> ⚙️ **Maschinell erzeugt** aus den NIXMETA-Headern der Module (`python3 50-core/medinix-meta.py generate-docs`).
> **Nicht von Hand aendern** — handgepflegt ist nur der Teil **ueber** der Markierung; die Wahrheit steht in den unten verlinkten `.nix`-Dateien (`docs/CONVENTIONS.md` §1).

## Module Map

| ID | Modul-Datei | Status | Komplexitaet | Ports |
|---|---|---|---|---|
| `541-sabnzbd` | [`541-sabnzbd.nix`](541-sabnzbd.nix) | active | -/5 | - |
| `543-mover` | [`543-mover.nix`](543-mover.nix) | active | 3/5 | - |

## Interne Abhaengigkeiten (Requires)

Die Module in diesem Ordner benoetigen folgende Bibliotheken/Dateien:

- [`lib/hardening-profiles`](../lib/hardening-profiles.nix)
- [`lib/memory-policy`](../lib/memory-policy.nix)

## Dependency Graph

```mermaid
graph TD
  541_sabnzbd["541-sabnzbd"] --> hardening_profiles["lib/hardening-profiles"]
  541_sabnzbd["541-sabnzbd"] --> memory_policy["lib/memory-policy"]
  543_mover["543-mover"] --> hardening_profiles["lib/hardening-profiles"]
```


---
*Maschinell erzeugt durch `python3 50-core/medinix-meta.py generate-docs` aus den NIXMETA-Headern der oben verlinkten `.nix`-Dateien. Handgepflegt ist nur der Teil ueber der AUTO-GENERATED-Markierung.*
