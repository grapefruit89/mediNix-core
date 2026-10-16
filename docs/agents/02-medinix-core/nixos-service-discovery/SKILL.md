---
name: nixos-service-discovery
mcp: [nixos]
description: "Discovery- und Aufnahme-Workflow fuer einen Dienst in mediNix-core: erst Quellen in der richtigen Rangfolge klaeren (Repo-SSoT -> nixpkgs-Modul-Code -> Upstream -> Context7 als Sparformat), dann Nix-Modul und Provisioning bauen, dann die Pruef-Leiter fahren. Laden, bevor ein neuer oder geaenderter Dienst (NNN-*.nix) entsteht."
---

# nixos-service-discovery

Laden, wenn ein **Dienst** neu aufgenommen oder geaendert wird (`XX-domain/NNN-dienst.nix`).
Ziel: nicht raten, keine Quelle erfinden und keine Werte abschreiben, die das Repo schon ableitet.

## Rangfolge der Quellen (verbindlich)

1. **Repo-SSoT zuerst.** `lib/registry.nix` (Nummer, Port, UID, StateDir), `lib/service-contract.nix`
   (Manifest-Schema), `lib/hardening-profiles.nix`, `docs/adr/` (`docs/adr/llm-index.json` lesen!),
   existierende **Geschwisterdateien** derselben Dekade.
2. **nixpkgs-Modul-Code = Wahrheit fuer NixOS.** Der Code, der im System laeuft:
   `nix eval --raw .#…` zum Zustand, `grep -r "options.services.<dienst>" /nix/store/*-source/nixos/modules/`
   fuer das Modul, oder das nix-MCP (`tools.nixos.nix`). Ein handgeschriebenes
   `systemd.services.<dienst>` umgeht das Modul - das ist der Anti-Pattern-Reflex.
3. **Upstream** (`<dienst>.org/docs/`, `api.<dienst>.org`): Env-Variablen, Verhalten,
   API-Endpunkte fuer ein Provisioning-Skript. OpenAPI-Specs nie komplett laden, nur die Pfade.
4. **Context7 nur als Sparformat-Index.** Kann nie mehr wissen als 1-3 und kann veraltet sein;
   bei Widerspruch gewinnt immer die Live-Quelle.

**Nie** `nixos.wiki` (alt, 403) - das aktive Wiki ist `wiki.nixos.org`.

## Was die Datei verraet (Werte nicht kopieren)

| Fundstelle in der Datei | Herkunft | Regel |
|---|---|---|
| `options.medinix.<x>` | repo-eigen | hier definieren |
| `services.<dienst>.<x>` | nixpkgs-Modul | Modul-Code pruefen (Schicht 2) |
| `medinix.manifest.<dienst>` | Manifest-Schema | Pflichteintrag, `lib/service-contract.nix` |
| `num`, `port`, `uid`, `stateDir` | `lib/registry.nix` / ADR-0000 | **ableiten**, nicht abschreiben |
| `JELLYFIN_*`/`FOO_*`-Env-Vars | Upstream-Doku | Schicht 3 |
| Hardening | `lib/hardening-profiles.nix` | nie lokal erfinden |

## Ablauf (6 Phasen)

1. **Discovery (read-only):** Schichten 1-4 in dieser Reihenfolge, **stop sobald die Frage beantwortet ist**.
2. **Kanonische Tabelle:** Information · Wert · Quelle · kanonisch? (Vorlage in
   `references/discovery-checkliste.md`). Widerspruch Repo vs. Upstream -> Repo gewinnt.
3. **Nix-Modul:** Struktur von der Geschwisterdatei uebernehmen; `medinix.manifest` setzen;
   Registry-Werte **gegen** `lib/registry.nix` pruefen (nicht kopieren).
4. **Provisioning-Skript** nur, wenn nach dem Start echte API-Calls noetig sind
   (Admin-User, Libraries). Dann: `requests` (kein `curl`), idempotent, Fehler explizit loggen.
5. **Pruef-Leiter** (`docs/CONVENTIONS.md`, alle Schritte lokal):
   `nixfmt` · `nix build .#checks.x86_64-linux.{nixfmt,statix,deadnix,nixmeta,unit-scripts}-check` ·
   `nix flake check --no-build --option eval-cache false` (**0 ❌**) ·
   `nix flake check --print-build-logs` (mit Builds) ·
   `scripts/{check_adrs,check_skills,check_banned_technologies}.py` · `folder_lint.sh` ·
   `gen_todo.py --check` · `gen_service_map.py --check` · `50-core/medinix-meta.py check-docs`.
6. **Korridor:** `.agent-state.json` pruefen (vorher!) und Neues eintragen; ROADMAP statt Prosa.

## Verbote (brechen die Pruef-Leiter oder ADR-0000)

- `users.users.<dienst>` im Modul - die **Engine** besitzt die Konten (ADR-0000, AB-042).
- `stateDir` mit Port-Suffix (`/var/lib/<dienst>-5510`) - Konvention ist `/var/lib/<name>`.
- `Group = "media"` als **Primaergruppe** (media nur als `extraGroups`, ADR-0000 §5).
- `DynamicUser = true` (AB-007) und handgeschriebene Units entgegen der Fabrik.
- Pruefung des **abgeleiteten** Ergebnisses als **Assertion** (gehoert in einen `check`).
- Neue Upstream-Quelle ohne Eintrag in `docs/UPSTREAM-SOURCES.md`.

## Anker als Pruefkriterien (Phase 2/5)

Beim Aufnehmen eines Dienstes die Anker aus `docs/NIXOS-ANCHORS.md` durchgehen - mindestens:
Least Privilege (Nr. 23), No Silent State (22), Fail-Closed (21), Defense in Depth (24),
Separation of Concerns (25). Jeder Anker nennt seine Durchsetzung (Check oder Korridor-Regel).
