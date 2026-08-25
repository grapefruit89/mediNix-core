# LLM Wiki: `58-observability`

> **Zweck:** [BITTE MANUELL AUSFUELLEN: Wofuer ist dieser Ordner zustaendig?]


<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->

## Module Map

| ID | Modul-Datei | Status | Komplexitaet | Ports |
|---|---|---|---|---|
| `581-ntfy` | `581-ntfy.nix` | active | 3/5 | - |
| `582-crowdsec` | `582-crowdsec.nix` | incomplete | 4/5 | - |
| `583-runtime-guard` | `583-runtime-guard.nix` | active | 3/5 | - |
| `584-post-boot-watchdog` | `584-post-boot-watchdog.nix` | active | 2/5 | - |

## Interne Abhaengigkeiten (Requires)

Die Module in diesem Ordner benoetigen folgende Bibliotheken/Dateien:

- `lib/hardening-profiles`
- `lib/registry`

## Dependency Graph

```mermaid
graph TD
  581_ntfy["581-ntfy"] --> hardening_profiles["lib/hardening-profiles"]
  581_ntfy["581-ntfy"] --> registry["lib/registry"]
  582_crowdsec["582-crowdsec"]
  583_runtime_guard["583-runtime-guard"] --> hardening_profiles["lib/hardening-profiles"]
  583_runtime_guard["583-runtime-guard"] --> registry["lib/registry"]
  584_post_boot_watchdog["584-post-boot-watchdog"] --> hardening_profiles["lib/hardening-profiles"]
  584_post_boot_watchdog["584-post-boot-watchdog"] --> registry["lib/registry"]
```


---
*Generiert durch `medinix-meta.py generate-docs`*
