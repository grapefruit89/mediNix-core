# LLM Wiki: `59-guardrails`

> **Zweck:** [BITTE MANUELL AUSFUELLEN: Wofuer ist dieser Ordner zustaendig?]


<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->

## Module Map

| ID | Modul-Datei | Status | Komplexitaet | Ports |
|---|---|---|---|---|
| `591-cross-domain` | `591-cross-domain.nix` | active | -/5 | - |

## Interne Abhaengigkeiten (Requires)

Die Module in diesem Ordner benoetigen folgende Bibliotheken/Dateien:

- `511-caddy`
- `526-vpn-killswitch`
- `lib/registry`

## Dependency Graph

```mermaid
graph TD
  591_cross_domain["591-cross-domain"] --> registry["lib/registry"]
  591_cross_domain["591-cross-domain"] --> 526_vpn_killswitch["526-vpn-killswitch"]
  591_cross_domain["591-cross-domain"] --> 511_caddy["511-caddy"]
```


---
*Generiert durch `medinix-meta.py generate-docs`*
