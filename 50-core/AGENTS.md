# LLM Wiki: `50-core`

> **Zweck:** Fundament-Domäne — Host-Baseline und der **Dezimalrahmen** (ADR-0000),
> auf dem alle anderen Domänen aufbauen.

Agentenorientierte Arbeitskarte. Menschliche Doku: [`BANNED_TECHNOLOGIES.md`](BANNED_TECHNOLOGIES.md),
`docs/adr/ADR-0000*` (Dezimalrahmen), `docs/CONVENTIONS.md` (SSoT).

**Rolle:** Kein Dienst, sondern die Engine und die Host-Grundlagen.

**Verantwortung:**
- Host-Hygiene und journald-Baseline (500)
- Dezimalrahmen-Engine + globale Identitäts-Injektion (501, ADR-0000)
- Host-Settings und Domain-Baseline (502)
- `hostIntegration` — `firewall` / `nftables` / `reverseProxy` je `managed|external` (503)
- `repl.nix` — Foundation-Tooling (Nix-REPL mit gepinnten nixpkgs, kein Modul im Auto-Import)
- Verbotsliste `BANNED_TECHNOLOGIES.md` (maschinell: `scripts/check_banned_technologies.py`)
- Generator **aller** Ordner-`AGENTS.md`: `medinix-meta.py generate-docs` / `check-docs`

**Nicht verantwortlich für:**
- Dienste, Ports, Units → die `5X-*`-Domänen
- Edge/Ingress → `51-ingress` · Host-Security-Dienste → `52-security`

**Source of truth:**
- Nummer, UID, Port, GID → `50-core/derive.nix` (`derive`, `sharedGid`) + ADR-0000
- Domain: `medinix.domain` ist ein **Alias** von `medinix.host.domain` (`502-host-settings.nix:23`)
- Erlaubt/verboten → `50-core/BANNED_TECHNOLOGIES.md`
- Was der Host selbst besitzt → `hostIntegration` in `503-host-integration.nix`

**Arbeitsregel:**
- Jede Zahl (Nummer, UID, Port, GID) kommt aus `50-core/derive.nix` — **keine Literale**.
- `hostIntegration = "external"` heißt: die Ressource gehört dem Host — nicht überschreiben.

## Was hier leicht schiefgeht (hart erarbeitet)

- **`networking.useIPTables` existiert in nixpkgs nicht.** Ein Guard darauf ist dauerhaft
  wahr und damit wirkungslos (war der tote Guard in `519`). Richtig:
  `networking.firewall.backend == "iptables"` bzw. `networking.nftables.enable`.
- **`systemd_hardened:` im NIXMETA-Header prüft kein Skript** — es ist eine Behauptung.
  Wer `true` schreibt, muss die Härtung im Modul zeigen (`50-core/hardening-profiles.nix`).
- **Zwei Ratschen, beide nur schrumpfend:** `nixmeta_check.py` +
  `scripts/nixmeta-baseline.txt` und `scripts/check_sources.py` +
  `scripts/sources-baseline.txt` (AB-053). Neue Abweichungen sind rot.
- **Generator-Pflicht:** Wer einen NIXMETA-Header ändert, lässt `generate-docs` **im selben**
  Commit laufen. `check-docs` prüft das in **keiner** CI — eine veraltete Karte fällt dort nicht auf.
- **Kein Laufzeit-Müll ins Repo:** `mcp_server.log` ist nicht getrackt und bleibt es.

## Prüfen

```bash
python3 scripts/medinix-meta.py generate-docs && python3 scripts/medinix-meta.py check-docs
python3 scripts/nixmeta_check.py            # NIXMETA-Ratsche (Header-Vollstaendigkeit)
python3 scripts/check_sources.py            # Upstream-Quellen je Manifest-Traeger
python3 scripts/check_banned_technologies.py
python3 scripts/check_corridor.py           # Korridor-Regeln aus .agent-state.json
python3 docs/agents/shared/scripts/scan_inconsistencies.py   # Nummer/Port-Konsistenz
```

Nur mit `nix` (CI nutzt die flake-gepinnten Tools, nicht die PATH-Versionen):
`nix eval .#checks.x86_64-linux --apply builtins.attrNames` listet alle 47 Checks,
`nix build --no-link .#checks.x86_64-linux.decimal-framework` baut den Rahmen-Check einzeln.


<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->

> ⚙️ **Maschinell erzeugt** aus den NIXMETA-Headern der Module (`python3 scripts/medinix-meta.py generate-docs`).
> **Nicht von Hand aendern** — handgepflegt ist nur der Teil **ueber** der Markierung; die Wahrheit steht in den unten verlinkten `.nix`-Dateien (`docs/CONVENTIONS.md` §1).

## Module Map

| ID | Modul-Datei | Status | Komplexitaet | Ports |
|---|---|---|---|---|
| `500-host-baseline` | [`500-host-baseline.nix`](500-host-baseline.nix) | active | 1/5 | - |
| `501-decimal-engine` | [`501-decimal-engine.nix`](501-decimal-engine.nix) | active | 2/5 | - |
| `502-host-settings` | [`502-host-settings.nix`](502-host-settings.nix) | active | 1/5 | - |
| `503-host-integration` | [`503-host-integration.nix`](503-host-integration.nix) | active | 3/5 | - |
| `derive` | [`derive.nix`](derive.nix) | active | 1/5 | - |
| `hardening-profiles` | [`hardening-profiles.nix`](hardening-profiles.nix) | active | 2/5 | - |
| `manifest` | [`manifest.nix`](manifest.nix) | active | 2/5 | - |
| `memory-policy` | [`memory-policy.nix`](memory-policy.nix) | active | 2/5 | - |
| `registry` | [`registry.nix`](registry.nix) | active | 1/5 | - |
| `repl` | [`repl.nix`](repl.nix) | active | 1/5 | - |
| `service-contract` | [`service-contract.nix`](service-contract.nix) | active | 4/5 | - |
| `service-factory` | [`service-factory.nix`](service-factory.nix) | active | 4/5 | - |
| `smoke-test` | [`smoke-test.nix`](smoke-test.nix) | active | 2/5 | - |
| `vm-smoke-test` | [`vm-smoke-test.nix`](vm-smoke-test.nix) | active | 3/5 | - |

## Interne Abhaengigkeiten (Requires)

Die Module in diesem Ordner benoetigen folgende Bibliotheken/Dateien:


## Dependency Graph

```mermaid
graph TD
  500_host_baseline["500-host-baseline"]
  501_decimal_engine["501-decimal-engine"]
  502_host_settings["502-host-settings"]
  503_host_integration["503-host-integration"]
  derive["derive"]
  hardening_profiles["hardening-profiles"]
  manifest["manifest"]
  memory_policy["memory-policy"]
  registry["registry"]
  repl["repl"]
  service_contract["service-contract"]
  service_factory["service-factory"]
  smoke_test["smoke-test"]
  vm_smoke_test["vm-smoke-test"]
```


---
*Maschinell erzeugt durch `python3 scripts/medinix-meta.py generate-docs` aus den NIXMETA-Headern der oben verlinkten `.nix`-Dateien. Handgepflegt ist nur der Teil ueber der AUTO-GENERATED-Markierung.*
