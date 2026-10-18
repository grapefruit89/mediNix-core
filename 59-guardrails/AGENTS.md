# LLM Wiki: `59-guardrails`

> **Zweck:** Domänenübergreifende Invarianten — die Assertions, die kein einzelnes Modul allein verantworten kann.

Alles **unterhalb der AUTO-GENERATED-Markierung** stammt aus den NIXMETA-Headern
(`python3 50-core/medinix-meta.py generate-docs`) — **nie** von Hand ändern, sonst
wird `check-docs` rot. Dieser manuelle Teil bleibt erhalten (den Marker-String
nicht wörtlich im Text nennen, sonst schneidet der Generator dort ab).

**Rolle:** Guardrail-Domäne (59x) — hier steht nur, was mehrere Domänen zugleich betrifft.

**Verantwortung:**
- `591` Cross-Domain-Assertions: fail-closed, der Build bricht statt zu warnen (ADR-0003 §3)

**Nicht verantwortlich für:**
- Assertions zu einem einzelnen Dienst — die stehen **inline** in ihrem Modul

**Source of truth:**
- jede Regel steht bei ihrem Gegenstand; dieser Ordner sammelt nur die domänenübergreifenden

**Bekannte Klemmen:**
- **Entschieden und angeglichen (2026-10-17, Finding 25):** Es gibt **kein** zentrales Assertion-Register (ADR-0003 §3). ADR-5043 beschreibt jetzt die geltende Praxis: Assertions inline beim geprüften Option, Message mit Was/Warum/Wie und Modul-Locator; cross-domain Garantien nur in `591-cross-domain.nix`. Historie: `590-registry.nix` existierte bis `533126e` (dort gelöscht, dort entstand 591).


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
