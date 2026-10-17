# LLM Wiki: `59-guardrails`

> **Zweck:** [BITTE MANUELL AUSFUELLEN: Wofuer ist dieser Ordner zustaendig?]


<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->

> ⚙️ **Maschinell erzeugt** aus den NIXMETA-Headern der Module (`python3 50-core/medinix-meta.py generate-docs`).
> **Nicht von Hand aendern** — handgepflegt ist nur der Teil **ueber** der Markierung; die Wahrheit steht in den unten verlinkten `.nix`-Dateien (`docs/CONVENTIONS.md` §1).

## Module Map

| ID | Modul-Datei | Status | Komplexitaet | Ports |
|---|---|---|---|---|
| `591-cross-domain` | [`591-cross-domain.nix`](591-cross-domain.nix) | active | -/5 | - |

## Interne Abhaengigkeiten (Requires)

Die Module in diesem Ordner benoetigen folgende Bibliotheken/Dateien:

- `511-caddy`
- `526-vpn-killswitch`
- [`lib/registry`](../lib/registry.nix)

## Dependency Graph

```mermaid
graph TD
  591_cross_domain["591-cross-domain"] --> registry["lib/registry"]
  591_cross_domain["591-cross-domain"] --> 526_vpn_killswitch["526-vpn-killswitch"]
  591_cross_domain["591-cross-domain"] --> 511_caddy["511-caddy"]
```


---
*Maschinell erzeugt durch `python3 50-core/medinix-meta.py generate-docs` aus den NIXMETA-Headern der oben verlinkten `.nix`-Dateien. Handgepflegt ist nur der Teil ueber der AUTO-GENERATED-Markierung.*
