# HANDOFF AN DEN NÄCHSTEN AGENT — mediNix-core

> **Ersetzt die Termux-Fassung vom 2026-10-15** (sie beschrieb ein Handy ohne Nix und ist
> in der Git-Historie erhalten). Stand dieser Fassung: **2026-10-15 abends**, Branch `audit-2026-10-15`.

---

## 0. TL;DR

- **Repo:** `mediNix-core` — deklarative NixOS-Homelab-Konfiguration (Flake, ADR-0000 „Dezimalrahmen").
- **Zweig:** `audit-2026-10-15` (gepusht). `main` ist unberührt.
- **Stand:** `nix flake check --no-build` = **49 bestanden / 0 offen**; Lint-Checks **gebaut** grün;
  die **Voll-Stack-Ratsche deckt 43 fachliche Units** (18 Dienste + acme-*, cloudflare-ddns, mediNix-*), dazu sieben Negativtests und der **Port-Verdrahtungs-Riegel**.
  GitHub-CI grün (`Flake Check` inkl. Paket-Build, `order-lint`, `Generate Docs Index`).
- **22 Commits** heute auf diesem Branch; Korridor/Roadmap/Ledger sind auf demselben Stand.
- **Vor jeder Änderung lesen:** `.agent-state.json` → `corridor` (Whitelist, **30** Blacklist-Regeln als `AB-001`…`AB-030`, offene Entscheidungen).
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
          .#checks.x86_64-linux.deadnix-check .#checks.x86_64-linux.nixmeta-check \
          .#checks.x86_64-linux.mediNix-unit-scripts --no-link

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

---

## 9. Nachtrag 2026-10-15 (später Abend) — 513/UPG + Repo-Aufräumen

- **513 lief als root** (L-038): der `hardeningOnly`-Modus der Service-Fabrik setzt kein
  `User`/`Group`; 513 legt seinen Account jetzt selbst an — **mit UPG** (uid = gid = 5130,
  Primärgruppe `cloudflare-ddns`) statt Primärgruppe `media`, und steht in
  `medinix.factoryUnits`, damit Guardrail 591 die Unit prüft. Guardrail 591 verlangt seit
  heute `Group == Unit-Name`, Primärgruppe == Unit-Name und `users.groups.<n>.gid == uid`
  (er hat beim Verschärfen sofort einen vergessenen Rest gefunden).
- **DDNS-Token nicht mehr in `argv`** (L-039): `curl --variable token@$RUNTIME_DIRECTORY/cf-token`
  + `--expand-header` (curl 8.21.0); `lib/mk-secure-curl.nix` ist damit `deprecated`.
- **Repo aufgeräumt** (L-040/L-041): Fremdregelwerke (`.agents/`, `docs/GEMINI.md`),
  flache Zweitfassungen (`docs/SKILL-*.md`, `docs/CHANGELOG.md`), Code-Dump
  (`59-guardrails-export.md`) archiviert → `docs/audit/2026-10-15/repo-cleanup/<original-pfad>/`;
  Zweitfassungen sind jetzt **Zeiger**; `docs/AGENT_SOURCES.md` ist in
  `docs/UPSTREAM-SOURCES.md` aufgegangen; die veraltete Service-Map (GID 5000 = flat) steht
  korrigiert (UPG) in `docs/INDEX.md`.
- **Neu:** `docs/TODO.md` ist **generiert** (`scripts/gen_todo.py`, `--check` prüft) — keine
  zweite Planungsquelle; Whitelist + Blacklist stehen in `docs/CONVENTIONS.md` §4/§5.
- **Merksatz (Korridor AB-024):** der `hardeningOnly`-Modus der Fabrik liefert eine
  **Unit**-Definition — `users.*`/`medinix.*` darin erzeugen
  „The option `systemd.services.<n>.users' does not exist".

## 10. Nachtrag — 516 CrowdSec (L-044)

- **Der Edge hat jetzt einen Bouncer:** `51-ingress/516-crowdsec.nix` — Engine nativ
  (`services.crowdsec`), Acquisition aus dem **journald** (`_SYSTEMD_UNIT=caddy-media.service`,
  `labels.type = caddy`), Hub-Collection `crowdsecurity/caddy`, Minimal-Profil (Ban 4h —
  **ohne Profil reagiert CrowdSec nicht**). Account: UPG **5160** + `extraGroups = systemd-journal`
  (Engine besitzt ihn, ADR-0000 §4).
- **Bouncer = Host-Hoheit:** nur aktiv bei `medinix.hostIntegration.nftables = "managed"`;
  sonst bricht eine Assertion ab (Negativtest `checks.mediNix-negative-crowdsec-bouncer`).
  Host-Pflicht steht in `docs/ADMIN-HANDOFF.md` §3.
- **RT-3 aufgelöst:** `fail2ban` ist jetzt Legacy (519) — ein Edge-Bouncer pro Rand.
- **Lehre (wieder):** eine neue `.nix`-Datei ist für `nix build`/`nix flake check` **unsichtbar,
  bis sie getrackt ist** → `git add -N <datei>` (bzw. `git add -A`) **vor** der Messung.
  Sonst meldet die Eval z. B. „The option `medinix.crowdsec' does not exist".
- **Weiter:** `589 Log-Sink` (P2) — Bestandsaufnahme + Entwurf liegen vor (Roadmap).

## 11. Uebernahme des Handy-Blocks (2026-10-16) — und der Branch ist ROT

- **Stand:** `3fc4d54` (19 Commits seit `822a0d2`), lokal per fast-forward uebernommen,
  **kein Verlust** (`822a0d2` ist Vorfahr).
- **Neu und gut:** AB-033..AB-038 (Friedhof + Zwei-Versuche-Stop), `scripts/agent-state-edit.py`
  (AB-037), `lib/derive.nix`, UID-Hartkodierungen entfernt, `docs/anchors/` (32 Dateien,
  Apache-2.0, in CONVENTIONS §4 als Fremdmaterial), `docs/RUNBOOK.md` + `medinix logs`,
  `scripts/nixos_idiom_audit.py` (0 P0-Signale), Roadmap-Plan 79-83.
- **ROT (hoechste Prioritaet):** `nix flake check` = **13/50**, CI `Flake Check` failure
  (`3fc4d54`, `e46359a`). Belegter Zirkel: `config.medinix.manifest` <-> `config.users.users`.
  Beteiligt: `585-exporters.nix` (liest manifest, schreibt users + factoryUnits) und der
  Guardrail aus `e803ba8` (prueft `config.users.users`, liest manifest). **Kein Fix ohne Go.**
- **589 Log-Sink ist verworfen** (AB-039/YAGNI): `medinix logs` + RUNBOOK deckt den
  Agent-Zugriff, Roadmap 67 (Vector+Loki) die Auswertung.
- **Merksatz:** zwei einzeln gruene Aenderungen koennen zusammen eine Eval-Rekursion bilden -
  nach jedem Merge die **volle Leiter** fahren, nicht nur den eigenen Check.

## 12. Nachtrag 2026-10-16 (Session 2) — roter Branch, Bisect-Beweis, T3-Plan

- **Lage:** Branch **lokal** bei `d6da997` (rot, 13/50) + ein **lokaler Commit** mit dem
  bewiesenen Fix: `fix(585): Exporter-Konten zurueckgenommen` -> **45/50 gruen**, kein
  `infinite recursion` mehr. **Kein Push** (1 Negativtest noch rot).
- **Beweis:** `git bisect run` im Worktree (`822a0d2` gut .. `3fc4d54` bad) ->
  **first bad = `2254f8c`** („Exporters mit eigenem UPG-Account"). `585` schreibt
  `users.users`/`groups` **und** liest im selben Modul `manifest` = Fixpunkt-Kreuz.
- **REST (genau einer):** `mediNix-negative-ankreuzbogen` — „ui.group = Observability
  scheitert - der Test beweist nichts": der Test erwartet die **neue** 585-Form.
- **Naechster Schritt = T3** (5 Stellen, exakt in `ROADMAP.md`): Exporter-Identitaet als
  **Absicht** `medinix.exporters` deklarieren, die **Engine** leitet die Konten ab.
  Dann 50/51 messen (cache-frei: `--option eval-cache false`) und **einmal** pushen.
- **Lehren im Korridor:** `AB-041` (bei Eval-Blockern **erst bisecten**),
  `AB-040` (Kanten nur Quelle -> Ableitung), `AB-038` (Zwei-Versuche-Stop).
- **Noch offen (nach T3):** Discovery-Skill `nixos-service-discovery` + `references/`,
  `AGENTS.md`-Zeilen, CI-Schicht 0a (`nixos_idiom_audit.py --p0-only` in `order-lint`).
