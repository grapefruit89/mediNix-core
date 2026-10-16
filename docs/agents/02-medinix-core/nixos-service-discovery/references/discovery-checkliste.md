# Discovery-Checkliste (Vorlage)

Zum Abhaken bei jeder Dienst-Aufnahme. Kopieren, ausfuellen, in den PR/Commit-Verweis legen.

## Phase 1 - Quellen (read-only)

- [ ] **Repo:** gibt es ein Geschwister in derselben Dekade? Welche Nummer ist frei
      (`lib/registry.nix`)? Welches ADR gilt (`docs/adr/llm-index.json`)?
- [ ] **Repo:** `lib/service-contract.nix` (Manifest-Felder), `lib/hardening-profiles.nix`
      (Profil), `lib/memory-policy.nix`, `lib/creds.nix`.
- [ ] **nixpkgs:** welches Modul/Attribut? Optionen pruefen, **nicht erinnern**:
      `nix eval --raw nixpkgs#path` bzw. `grep -rn "options.services.<dienst>"
      /nix/store/*-source/nixos/modules/services/ | head` bzw. nix-MCP.
- [ ] **Upstream:** `<dienst>.org/docs/…` (Konfig-Felder, Env-Vars, Verzeichnisse);
      `api.<dienst>.org` **nur** wenn Provisioning noetig ist (OpenAPI nie komplett laden).
- [ ] **Context7** nur, wenn 1-3 nichts liefern - und als Sparformat behandeln.

## Phase 2 - Kanonische Tabelle

| Information | Wert | Quelle | Kanonisch? |
|---|---|---|---|
| NixOS-Option | `services.<x>.<y>` | Modul-Code (Store) | ☐ |
| Nummer/Port/UID | z. B. `551 / 5510 / 5510` | `lib/registry.nix` (ADR-0000) | ☐ |
| StateDir | `/var/lib/<name>` | ADR-0000 §4 | ☐ |
| Shared Group | `media` **nur** `extraGroups` | ADR-0000 §5 | ☐ |
| Env-Vars | `FOO=bar` | Upstream-Doku | ☐ |
| Hardening | `profile = "<x>"` | `lib/hardening-profiles.nix` | ☐ |
| Upstream-Quelle | URL | Phase 1 | ☐ |

Regel: widersprechen sich zwei Quellen -> die **repo-interne** gewinnt; ohne repo-interne
Quelle gewinnt der **Modul-Code**, nicht die Doku.

## Phase 3-4 - Artefakte

- [ ] `XX-domain/NNN-<dienst>.nix` mit V3-Header (id/title/domain/folder/status/complexity/
      last_reviewed/links.adr + Upstream-Angabe; geprueft von `scripts/nixmeta_check.py`)
- [ ] `medinix.manifest.<dienst>` gesetzt; `num` stimmt gegen `lib/registry.nix`
- [ ] Kein `users.users.*` im Modul (Engine), kein `DynamicUser`, kein media als Primaergruppe
- [ ] Provisioning nur, wenn noetig: idempotent, `requests`, Fehler explizit geloggt
- [ ] Neue Quelle in `docs/UPSTREAM-SOURCES.md` eingetragen

## Phase 5 - Pruef-Leiter (alles lokal, Exit-Status pruefen - nie durch eine Pipe maskieren)

```bash
nix fmt -- <datei>
nix build .#checks.x86_64-linux.nixfmt-check .#checks.x86_64-linux.statix-check \
          .#checks.x86_64-linux.deadnix-check .#checks.x86_64-linux.nixmeta-check \
          .#checks.x86_64-linux.mediNix-unit-scripts
nix flake check --no-build --option eval-cache false   # 0 ❌ ist das Kriterium, nicht "viele ✅"
nix flake check --print-build-logs                     # wie die CI (mit Builds)
python3 scripts/check_adrs.py ; python3 scripts/check_skills.py
python3 scripts/check_banned_technologies.py ; bash docs/agents/shared/scripts/folder_lint.sh .
python3 scripts/gen_todo.py --check ; python3 scripts/gen_service_map.py --check
python3 50-core/medinix-meta.py check-docs
```

- [ ] Alle Schritte gruen; bei rot: **Ursache benennen, nicht raten** (bei Eval-Blockern erst
      `git bisect` im Worktree, AB-041)
- [ ] `git add -A` **vor** der Messung (untracked Dateien sind im Nix-Build unsichtbar)

## Phase 6 - Korridor

- [ ] `.agent-state.json` vorher gelesen (Sackgassen!) und hinterher ergaenzt
- [ ] ROADMAP-Punkt statt Prosa; ggf. neues ADR nach `docs/adr/ADR-<id>-<slug>.md` (Formregel:
      `scripts/check_adrs.py`) + Eintrag in `docs/adr/llm-index.json`
