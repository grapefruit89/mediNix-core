# LLM Wiki: `55-playback`

> **Zweck:** Wiedergabe — Medienserver und ihre Weboberflächen.

Alles **unterhalb der AUTO-GENERATED-Markierung** stammt aus den NIXMETA-Headern
(`python3 scripts/medinix-meta.py generate-docs`) — **nie** von Hand ändern, sonst
wird `check-docs` rot. Dieser manuelle Teil bleibt erhalten (den Marker-String
nicht wörtlich im Text nennen, sonst schneidet der Generator dort ab).

**Rolle:** Playback-/Media-Domäne (55x).

**Verantwortung:**
- `551` Jellyfin, `552` Audiobookshelf, `553` Navidrome — Registry-Rolle `stream`
- Landing-Kacheln: die Module setzen `landing` + `iconSvg`/`iconId` selbst

**Nicht verantwortlich für:**
- Zugangskontrolle → `51-ingress`: `stream` heißt WAN-sichtbar **ohne** `forward_auth`, die App authentifiziert selbst (OIDC gegen Pocket ID, ADR-517)
- Transcoding-/GPU-Hardware → 50-core
- Speicherpfade/Tiering → `57-maintenance`

**Source of truth:**
- Port/UID/Rolle → `lib/registry.nix` (`jellyfin`/`audiobookshelf`/`navidrome` = `stream`)
- Kachel-Darstellung → `51-ingress/518-landingpage.nix` plus `ingress.vhosts.<name>.landing`/`iconId`/`iconSvg`

**Bekannte Klemmen:**
- `stream` ist WAN-offen ohne Ingress-Auth. 511 lässt es nur zu, wenn der Manifest-Eintrag `stream` deklariert **oder** der Dienst in `medinix.ingress.streamAck` steht (Review 2026-10-17, Finding 20) — ein Vhost-Override auf `stream` ist kein Freibrief.
- `idp` ist per Assertion dem IdP selbst vorbehalten.

**Kern vs. Zulieferer:**
Die drei Dienste in `55-playback` (Jellyfin, Audiobookshelf, Navidrome) bilden den eigentlichen Kern des Systems. Alle anderen Dekaden existieren primär, um diesen Kern mit Inhalten, Sicherheit, Infrastruktur und Wartung zu versorgen. Das erklärt das bewusste architektonische Verhältnis: Der Kern bleibt kompakt und fokussiert, während die Zulieferer- und Wartungsdomänen breiter aufgestellt sind.


<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->

> ⚙️ **Maschinell erzeugt** aus den NIXMETA-Headern der Module (`python3 scripts/medinix-meta.py generate-docs`).
> **Nicht von Hand aendern** — handgepflegt ist nur der Teil **ueber** der Markierung; die Wahrheit steht in den unten verlinkten `.nix`-Dateien (`docs/CONVENTIONS.md` §1).

## Module Map

| ID | Modul-Datei | Status | Komplexitaet | Ports |
|---|---|---|---|---|
| `551-jellyfin` | [`551-jellyfin.nix`](551-jellyfin.nix) | active | 3/5 |  |
| `552-audiobookshelf` | [`552-audiobookshelf.nix`](552-audiobookshelf.nix) | active | 2/5 | - |
| `553-navidrome` | [`553-navidrome.nix`](553-navidrome.nix) | active | 2/5 | - |

## Interne Abhaengigkeiten (Requires)

Die Module in diesem Ordner benoetigen folgende Bibliotheken/Dateien:

- [`50-core/hardening-profiles`](../50-core/hardening-profiles.nix)
- [`50-core/memory-policy`](../50-core/memory-policy.nix)
- [`50-core/registry`](../50-core/registry.nix)
- [`50-core/service-factory`](../50-core/service-factory.nix)
- [`52-security/creds`](../52-security/creds.nix)

## Dependency Graph

```mermaid
graph TD
  551_jellyfin["551-jellyfin"] --> registry["50-core/registry"]
  551_jellyfin["551-jellyfin"] --> service_factory["50-core/service-factory"]
  551_jellyfin["551-jellyfin"] --> hardening_profiles["50-core/hardening-profiles"]
  551_jellyfin["551-jellyfin"] --> memory_policy["50-core/memory-policy"]
  551_jellyfin["551-jellyfin"] --> creds["52-security/creds"]
  552_audiobookshelf["552-audiobookshelf"] --> creds["52-security/creds"]
  552_audiobookshelf["552-audiobookshelf"] --> registry["50-core/registry"]
  552_audiobookshelf["552-audiobookshelf"] --> hardening_profiles["50-core/hardening-profiles"]
  552_audiobookshelf["552-audiobookshelf"] --> memory_policy["50-core/memory-policy"]
  553_navidrome["553-navidrome"] --> creds["52-security/creds"]
  553_navidrome["553-navidrome"] --> registry["50-core/registry"]
  553_navidrome["553-navidrome"] --> hardening_profiles["50-core/hardening-profiles"]
  553_navidrome["553-navidrome"] --> memory_policy["50-core/memory-policy"]
```


---
*Maschinell erzeugt durch `python3 scripts/medinix-meta.py generate-docs` aus den NIXMETA-Headern der oben verlinkten `.nix`-Dateien. Handgepflegt ist nur der Teil ueber der AUTO-GENERATED-Markierung.*
