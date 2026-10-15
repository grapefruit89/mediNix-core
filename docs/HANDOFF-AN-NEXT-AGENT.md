# HANDOFF AN DEN NÄCHSTEN AGENT — mediNix-core

> **Ersetzt die Termux-Fassung vom 2026-10-15** (sie beschrieb ein Handy ohne Nix und ist
> in der Git-Historie erhalten). Stand dieser Fassung: **2026-10-15 abends**, Branch `audit-2026-10-15`.

---

## 0. TL;DR

- **Repo:** `mediNix-core` — deklarative NixOS-Homelab-Konfiguration (Flake, ADR-0000 „Dezimalrahmen").
- **Zweig:** `audit-2026-10-15` (gepusht). `main` ist unberührt.
- **Stand:** `nix flake check --no-build` = **47 bestanden / 0 offen**; Lint-Checks **gebaut** grün;
  die **Voll-Stack-Ratsche deckt 18 Dienste**, dazu sieben Negativtests und der **Port-Verdrahtungs-Riegel**.
  GitHub-CI grün (`Flake Check` inkl. Paket-Build, `order-lint`, `Generate Docs Index`).
- **22 Commits** heute auf diesem Branch; Korridor/Roadmap/Ledger sind auf demselben Stand.
- **Vor jeder Änderung lesen:** `.agent-state.json` → `corridor` (Whitelist, 21 Blacklist-Regeln, offene Entscheidungen).
- **Einzige Roadmap:** `ROADMAP.md`. Altstände: `docs/audit/2026-10-15/`.
- **Harte Regeln:** messen → verstehen → **Diff vorlegen** → Go abwarten. Kein Push, Merge oder Löschen ohne Go.
- **Die Zielmaschine (q958) ist nie gelaufen** — keine Daten, keine Migration, Änderungen kosten nichts.

---

## 1. Umgebung (Nobara, nicht Termux)

- **System:** Nobara 44 (Fedora-Basis), btrfs, root auf `/dev/nvme1n1p3`.
- **Nix ist nativ installiert:** Determinate Nix 3.23.2 (nix 2.35.3) unter
  `/nix/var/nix/profiles/default/bin/`. In Shell-Aufrufen ggf. voranstellen:
  `export PATH=/nix/var/nix/profiles/default/bin:$PATH`.
- **Werkzeuge:** `nixfmt` 1.5.0 (`/home/moritz/.local/bin/nixfmt`), `actionlint` 1.7.12,
  `shellcheck` 0.11.0, `shfmt` 3.7.0, `yamllint` 1.38.0.
- **MCP-Server `nixos`** (`mcp-nixos` 3.1.0, installiert mit `uv tool install --python 3.12 mcp-nixos`,
  eingetragen in `/home/moritz/.config/opencode/opencode.jsonc`) — Echtzeit-Optionen/Pakete;
  hilft, Paketnamen nicht zu raten.
- **Bewusst nicht installiert:** sops, age/agenix, alejandra, podman als Nix-Träger (siehe Corridor).

---

## 2. Prüf-Leiter (jede Runde vollständig — die Reihenfolge ist der Punkt)

```bash
cd /home/moritz/repos/mediNix-core
export PATH=/nix/var/nix/profiles/default/bin:$PATH

# Stufe 0a: Format-SWEEP über alle .nix (nicht nur die geänderten!)
find . -name "*.nix" -not -path "./.git/*" | while read -r f; do \
  /home/moritz/.local/bin/nixfmt -c "$f" >/dev/null 2>&1 || echo "NICHT FORMATIERT: $f"; done

# Stufe 0b: Lint-Gates wirklich BAUEN (--no-build führt sie nicht aus!)
nix build .#checks.x86_64-linux.nixfmt-check .#checks.x86_64-linux.statix-check \
          .#checks.x86_64-linux.deadnix-check --no-link

# Stufe 1: Auswertung
nix flake check --no-build      # erwartet: 43 ✅ / 0 ❌

# Stufe 1b: PAKETE (sind NICHT Teil von flake check) - die CI baut alle
nix build .#packages.x86_64-linux.docs --no-link

# Stufe 1c: die zwei Ratsche-Checks einzeln (sie feuern nur hier)
nix build .#checks.x86_64-linux.mediNix-ports-verdrahtet --no-link

# Stufe 2: Workflows
/home/moritz/.local/bin/actionlint .github/workflows/*.yml
yamllint -d "{extends: default, rules: {line-length: disable, truthy: {allowed-values: ['true','false','on']}, document-start: disable}}" .github/workflows/*.yml
bash docs/agents/shared/scripts/folder_lint.sh .
```

**Vier Fallen, die Zeit gekostet haben:**

1. `nix flake check --no-build` **führt nixfmt/statix/deadnix nicht aus** — ein grüner Lauf beweist nur die Auswertung.
2. `nix flake check` **baut keine Pakete** — deshalb war `packages.docs` unbemerkt kaputt.
3. Einzelne Checks ohne erzwungenen `system.build.toplevel` sind **wertlos** für Voll-Stack-Fehler.
4. Die lokale `nixfmt`-Version kann von der in nixpkgs abweichen (hier 1.5.0 vs. 1.4.0) — Autorität ist
   `nix build .#checks.x86_64-linux.nixfmt-check`.

---

## 3. Die vier Denkfallen (alle teuer gelernt)

1. **`config.*` niemals aus einer Funktion lesen, die während der Config-Auswertung läuft** → Endlosrekursion
   (ein Lauf brachte 12 statt 43 grüne Checks). Werte explizit als Parameter übergeben (so macht es
   `lib/service-factory.nix` mit `ownsAccount`).
2. **Ein NixOS-Modul darf nur `imports`/`options`/`config` auf oberster Ebene haben** (`lib/modules.nix:670`).
   Helfer über `options` oder `_module.args` exponieren.
3. **Upstream-Module vor der Delegation prüfen:** `services.gatus` und `services.ntfy-sh` setzen
   `DynamicUser = true` (verboten) — Gatus band zusätzlich Port 8080 statt 5820.
4. **Optionen deklarieren, bevor man sie mit `meta ? x` prüft** — sonst ist der Zweig toter Code (statix findet es).

---

## 4. Was aktuell gilt (Architektur-Entscheidungen dieser Runde)

| Thema | Entscheidung |
|---|---|
| `users.users.<dienst>` | **Genau ein Eigentümer:** die Engine (`lib/decimal-framework.nix`). Die Factory nur für Units **ohne** Manifest-Eintrag (`caddy-media`, `cloudflare-ddns`) — Parameter `ownsAccount` |
| Gruppenmodell | **UPG**: Primärgruppe = Dienstname (= UID = Port), `media` (GID 5000) nur als Zusatzgruppe |
| Geteilte Ablagen | `2775 root:media` (**SetGID**) — neue Dateien erben `media` |
| `stateDir` | `/var/lib/<name>` **ohne** Port-Suffix (ADR-0000 §9), in Contract, Registry und Engine identisch |
| Upstream-Dienste | Gatus und ntfy sind **native** Units (Konfig via `pkgs.formats.yaml` → `environment.etc`) |
| Sabnzbd | UPG; `Group` kommt aus `cfg.group` des nixpkgs-Moduls |
| Voll-Stack-Ratsche | `checks.mediNix-stack-eval` aktiviert 12 Dienste und erzwingt `toplevel` |
| Korridor | `.agent-state.json` (Schema 1.1) |

---

## 5. Offene Punkte

**Die vollständige, priorisierte Liste steht in `ROADMAP.md` (Abschnitt `Backlog`).** Kurzfassung:

- **P0:** Verfassungs-Verstöße in Doku/Guardrails (OCI/Podman-Textstellen in `500-host-baseline.nix:73` und
- **Erledigt (2026-10-15):** P0-Verfassungs-Verstöße (`b9a146f`), Ankreuzbogen Schicht 2 (`24f5ee5`),
  Root-Audit (`967585f`), Ratsche auf 18 Dienste (`9d4d0a4`), Port-Riegel (`e6f910d`),
  `refactor/decades-conformance` gelöscht.
- **P1:** 516 CrowdSec, `lib/gpu.nix`, `network-cidrs.nix`, `noExec` auch für 514
  (erst nach Laufzeittest im QEMU).
- **P2:** 4 unverdrahtete `lib`-Module entscheiden, `AGENT_SOURCES.md` mit `UPSTREAM-SOURCES.md`
  zusammenlegen, jellyfin zusätzlich über den *gerenderten* XML-Inhalt prüfen.

---

## 6. Wo was liegt

| Zweck | Datei |
|---|---|
| Entscheidungs-Korridor (Pflichtlektüre) | `.agent-state.json` |
| Roadmap (die einzige) | `ROADMAP.md` |
| Befund-Gedächtnis (Quelle + Rollback je Zeile) | `docs/AUDIT-LEDGER.md` |
| Ordnungsregeln (Ordner, Root-Dateien) | `docs/CONVENTIONS.md` |
| Wissensbasis-Index | `docs/INDEX.md` |
| Altstände dieser Runde | `docs/audit/2026-10-15/` |
| Agenten-Verfassung | `AGENTS.md` (Root) |

*Bei Unsicherheit gilt: messen, verstehen, fragen — nicht raten.*
