# NixOS-Ressourcen (kuratiert, maschinenlesbar)

> **Generiert.** Diese Datei wird aus `docs/NIXOS-RESOURCES.json` erzeugt —
> **nicht per Hand editieren**. Änderungen gehören in die JSON.
>
> ```
> python3 scripts/nixos-resources.py --write   # neu schreiben
> python3 scripts/nixos-resources.py --check   # Drift prüfen (CI)
> ```

Stand: 2026-11-04 · **51 Einträge** in **8 Kategorien** · Schema-Version 1

Curated upstream sources for NixOS work in mediNix-core. Consumed by agents via jq; see 'usage' for one-line queries.

Ursprung: `docs/learn/LEARN-50-gold-nuggets.md` (Projekt „mynixos", 2026-03), aufgelöst in Commit `2176c2c`. Alle 19 Links übernommen; die Sammlung wurde um Kuratierung (`relevance`, `use_cases`, `why`) und BANNED-Referenzen erweitert.

---

## Lokale Abfrage (bevorzugt)

Die externen Quellen sind der **Fallback**. Zuerst lokal messen:

```bash
# Repo-Root: Optionen der Prüfkonfiguration
nix eval --json .#nixosConfigurations.check.options.medinix.<pfad>

# Host: einzelne Option
nixos-option medinix.<pfad>

# Paket suchen
nix search nixpkgs <term> --json
```

Die `search.nixos.org`-API ist **instabil** (Elasticsearch-Backend, kein öffentliches API-Versprechen). Nur nutzen, wenn lokal nichts geht.

## jq-Beispiele

```bash
# nur die wirklich wichtigen Quellen
jq '.entries[] | select(.relevance=="high")' docs/NIXOS-RESOURCES.json

# was der Agent direkt parsen kann
jq '.entries[] | select(.machine_readable==true)' docs/NIXOS-RESOURCES.json

# was mediNix bewusst nicht nutzt — mit Begründung
jq '.entries[] | select(.banned_in_medinix==true)' docs/NIXOS-RESOURCES.json
```

---

## Standard-Dokumentation

*Official Nix / NixOS / nixpkgs documentation. Machine-readable where possible.*

- **[nix.dev](https://nix.dev)** — hoch · CC-BY-SA-4.0
  Official Nix documentation. Start here for language basics, flakes, and module system.
  Repo: https://github.com/NixOS/nix.dev
  Use-Cases: `nix-language`, `flakes`, `modules`, `tutorials`
- **[NixOS/nixpkgs](https://github.com/NixOS/nixpkgs)** — hoch · MIT
  The package set and NixOS modules. Every option and package mediNix uses comes from here; `nix search nixpkgs` and `nixos-option` query it.
  Use-Cases: `packages`, `modules`, `overlays`
- **[NixOS Manual (stable)](https://nixos.org/manual/nixos/stable/)** — hoch · MIT
  Versioned manual. Option reference and service documentation.
  Use-Cases: `nixos-options`, `services`, `hardware`
- **[nixpkgs Manual (stable)](https://nixos.org/manual/nixpkgs/stable/)** — hoch · MIT
  Package build reference. Relevant for packages/arr-provision and packages/medinix-cli.
  Use-Cases: `package-development`, `overlays`, `builders`
- **[Nix Language Basics](https://nix.dev/tutorials/nix-language)** — mittel · CC-BY-SA-4.0
  Language reference. Needed when reading or writing Nix expressions.
  Use-Cases: `nix-language`
- **[NixOS Wiki](https://wiki.nixos.org)** — hoch · MIT
  Community knowledge. Often more current than the manual for 'how do I X?' questions.
  Use-Cases: `patterns`, `troubleshooting`
- **[NixOS & Flakes Book (ryan4yin)](https://github.com/ryan4yin/nixos-and-flakes-book)** — mittel · CC-BY-SA-4.0
  Best free Flakes book. Opinionated but readable.
  Use-Cases: `flakes`, `tutorials`
- **[search.nixos.org](https://search.nixos.org)** — hoch · maschinenlesbar · MIT
  Options and package search. For offline/preferred: `nixos-option <path>` on host, or `nix eval --json` inside the repo.
  API: `POST https://search.nixos.org/backend/latest-43-nixos-unstable/_search`
  ⚠️ Elasticsearch backend, not a stable public API. Breaks without warning.
  Use-Cases: `nixos-options`, `packages`

## Patterns & Flake-Referenzen

*Reference flake configs and module collections for architecture comparison. Do not copy verbatim; mediNix has its own conventions.*

- **[Misterio77/nix-starter-configs](https://github.com/Misterio77/nix-starter-configs)** — mittel · CC0-1.0
  Clean flake templates. Compare structure, do not copy.
  Use-Cases: `flake-design`, `templates`
- **[Misterio77/nix-config](https://github.com/Misterio77/nix-config)** — mittel · MIT
  Real-world homelab flake. Useful as an architecture reference.
  Use-Cases: `flake-design`, `homelab`
- **[hlissner/dotfiles](https://github.com/hlissner/dotfiles)** — niedrig · MIT
  Module structure reference. Older style.
  Use-Cases: `module-structure`
- **[nix-community/home-manager](https://github.com/nix-community/home-manager)** — mittel · MIT
  User dotfile management. Not part of mediNix-core; relevant if the host config wants it.
  Use-Cases: `user-config`
- **[numtide/flake-utils](https://github.com/numtide/flake-utils)** — hoch · MIT
  Used in mediNix-core flake.nix (eachDefaultSystem).
  Use-Cases: `flake-design`
- **[hercules-ci/flake-parts](https://github.com/hercules-ci/flake-parts)** — niedrig · MIT
  Dendritic pattern helper. Explicitly not used in mediNix-core (see AGENTS.md). Reference only.
  Use-Cases: `flake-design`

## Server & Betrieb

*Server hardening, deployment, declarative disks, impermanence. Some are direct comparisons to mediNix modules.*

- **[nix-community/srvos](https://github.com/nix-community/srvos)** — mittel · MIT
  Server-hardening profiles. Direct comparison to 50-core/hardening-profiles.nix.
  Use-Cases: `hardening`, `server-profiles`
- **[nix-community/impermanence](https://github.com/nix-community/impermanence)** — mittel · MIT
  Ephemeral root filesystem. Not used in mediNix; relevant for future hardening.
  Use-Cases: `impermanence`
- **[nix-community/nixos-anywhere](https://github.com/nix-community/nixos-anywhere)** — mittel · MIT
  Remote installation via SSH. Relevant when mediNix is deployed for the first time.
  Use-Cases: `deployment`
- **[nix-community/disko](https://github.com/nix-community/disko)** — mittel · MIT
  Declarative disk partitioning. Not used; relevant for reproducible installs.
  Use-Cases: `disks`, `installation`
- **[nix-community/lanzaboote](https://github.com/nix-community/lanzaboote)** — mittel · GPL-3.0
  Secure Boot for NixOS. Not used; relevant for boot-chain integrity.
  Use-Cases: `secure-boot`
- **[NixOS/nixos-hardware](https://github.com/NixOS/nixos-hardware)** — mittel · CC0-1.0
  Hardware quirks. Not an input today; relevant when hardware-specific modules are needed.
  Use-Cases: `hardware`
- **[rasmus-kirk/nixarr](https://github.com/rasmus-kirk/nixarr)** — mittel · GPL-3.0
  Media-server module collection. Direct comparison to 53/54/55/56 modules.
  Use-Cases: `media-stack`, `comparison`

## Sicherheit

*CVE tracking and hardening references. Some entries are banned in mediNix and listed only as 'why we do it differently'.*

- **[nix-community/vulnix](https://github.com/nix-community/vulnix)** — mittel · maschinenlesbar · BSD-3
  CVE scanner for NixOS closures. Recommended if mediNix ever wants CVE monitoring.
  ℹ️ CLI produces JSON with --json; no daemon required.
  Use-Cases: `cve`, `security`
- **[NixOS/nix-security-tracker](https://github.com/NixOS/nix-security-tracker)** — niedrig · maschinenlesbar · MIT
  CVE web service. Reference only; no integration.
  Use-Cases: `cve`
- **[cynicsketch/nix-mineral](https://github.com/cynicsketch/nix-mineral)** — mittel · GPL-3.0
  Extreme hardening module. Comparison only; conflicts with mediNix's profile-based approach.
  Use-Cases: `hardening`, `comparison`

## Werkzeuge

*Daily-use tools. Most are already in the flake devShell or checks.*

- **[nix-community/nh](https://github.com/nix-community/nh)** — hoch · EUPL-1.2
  Better output for nixos-rebuild. Already in the flake devShell.
  Use-Cases: `rebuild`, `devshell`
- **[nix-community/nix-index-database](https://github.com/nix-community/nix-index-database)** — hoch · maschinenlesbar · MIT
  Weekly nix-index update. Faster than nix-index for ad-hoc lookups.
  Use-Cases: `search`, `tools`
- **[utdemir/nix-tree](https://github.com/utdemir/nix-tree)** — hoch · BSD-3
  Interactive dependency graph. Already in the flake devShell.
  Use-Cases: `dependency-graph`
- **[khumba/nvd](https://gitlab.com/khumba/nvd)** — hoch · maschinenlesbar · MIT
  Post-rebuild version diff. Shows what changed between generations.
  Use-Cases: `version-diff`
- **[astro/deadnix](https://github.com/astro/deadnix)** — hoch · maschinenlesbar · GPL-3.0
  Dead-code checker. Active as checks.deadnix-check.
  ℹ️ --output-format=json available.
  Use-Cases: `lint`
- **[oppiliappan/statix](https://github.com/oppiliappan/statix)** — hoch · MIT
  Anti-pattern linter. Active as checks.statix-check.
  Use-Cases: `lint`
- **[NixOS/nixfmt](https://github.com/NixOS/nixfmt)** — hoch · MPL-2.0
  Official formatter. Active as nixfmt-rfc-style in devShell and checks.
  Use-Cases: `formatter`
- **[nix-community/nix-direnv](https://github.com/nix-community/nix-direnv)** — mittel · MIT
  direnv integration for flakes. Optional.
  Use-Cases: `devshell`

## Community

*Forum, chat, discussion. For 'how do others do X?' questions.*

- **[discourse.nixos.org](https://discourse.nixos.org)** — hoch · maschinenlesbar · CC-BY-SA-4.0
  Official forum. Best source for 'how do others do X?'.
  API: `GET https://discourse.nixos.org/search.json?q=<term>`
  Use-Cases: `questions`, `patterns`
- **[Matrix #nix:nixos.org](https://matrix.to/#/#nix:nixos.org)** — niedrig · n/a
  Real-time chat. Not searchable as data.
  Use-Cases: `chat`

## Bewusst nicht verwendet (BANNED)

*Technologies explicitly banned in 50-core/BANNED_TECHNOLOGIES.md. Listed to explain what mediNix intentionally avoids.*

- **[Mic92/sops-nix](https://github.com/Mic92/sops-nix)** — niedrig · **BANNED** · MIT
  Listed so an agent can explain why mediNix uses systemd-creds instead.
  ⛔ 50-core/BANNED_TECHNOLOGIES.md §1: systemd-creds is the only accepted secret mechanism.
- **[ryantm/agenix](https://github.com/ryantm/agenix)** — niedrig · **BANNED** · CC0-1.0
  Same as sops-nix.
  ⛔ 50-core/BANNED_TECHNOLOGIES.md §1.
- **[Traefik](https://github.com/traefik/traefik)** — niedrig · **BANNED** · MIT
  Reference only. mediNix uses Caddy (511).
  ⛔ 50-core/BANNED_TECHNOLOGIES.md §1: exactly ONE reverse proxy (Caddy).

## NixOS-Org-Infrastruktur (nicht projektrelevant)

*Repositories of the nixos.org infrastructure team. Not project-relevant; kept for historical context only.*

- **[NixOS/nixops](https://github.com/NixOS/nixops)** — niedrig · LGPL-3.0
  NixOS-org deployment tool (inactive since Feb 2025). Not project-relevant; kept for historical context.
- **[NixOS/infra](https://github.com/NixOS/infra)** — niedrig · MIT
  NixOS-org server infrastructure. Not project-relevant.
- **[NixOS/ofborg](https://github.com/NixOS/ofborg)** — niedrig · MIT
  NixOS CI bot. Not project-relevant.
- **[NixOS/amis](https://github.com/NixOS/amis)** — niedrig · MIT
  NixOS AWS AMI automation. Not project-relevant.
- **[NixOS/nixos-status](https://github.com/NixOS/nixos-status)** — niedrig · MIT
  Status page for NixOS infra. Not project-relevant.
- **[NixOS/nixos-wiki-infra](https://github.com/NixOS/nixos-wiki-infra)** — niedrig · MIT
  Wiki setup. Not project-relevant.
- **[NixOS/nixops-dashboard](https://github.com/NixOS/nixops-dashboard)** — niedrig · LGPL-3.0
  Dashboard for nixops. Not project-relevant.
- **[NixOS/nixops-hetzner](https://github.com/NixOS/nixops-hetzner)** — niedrig · LGPL-3.0
  Hetzner backend for nixops. Not project-relevant.
- **[NixOS/nixops-aws](https://github.com/NixOS/nixops-aws)** — niedrig · LGPL-3.0
  AWS backend for nixops. Not project-relevant.
- **[NixOS/ofborg-infrastructure](https://github.com/NixOS/ofborg-infrastructure)** — niedrig · MIT
  ofborg infra. Not project-relevant.
- **[NixOS/nixpkgs-merge-bot](https://github.com/NixOS/nixpkgs-merge-bot)** — niedrig · MIT
  Nixpkgs merge bot. Not project-relevant.
- **[NixOS/first-time-contribution-tagger](https://github.com/NixOS/first-time-contribution-tagger)** — niedrig · MIT
  GitHub action. Not project-relevant.
- **[NixOS/security](https://github.com/NixOS/security)** — niedrig · n/a
  NixOS security team. Not project-relevant.
- **[NixOS/reproducible.nixos.org](https://github.com/NixOS/reproducible.nixos.org)** — niedrig · MIT
  NixOS reproducibility. Not project-relevant.

---

## Nicht in dieser Liste

Projekt-spezifische Upstream-Quellen (die tatsächlich importierten Flake-Inputs und die Herkunft einzelner Entscheidungen) stehen in [`UPSTREAM-SOURCES.md`](UPSTREAM-SOURCES.md).
