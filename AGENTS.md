# mediNix-core — AGENTS.md

> [!IMPORTANT]
> **REINE LOKALE AUSFÜHRUNG:** Es existieren keine externen Remote-Hosts. Jeglicher SSH- oder rsync-Zugriff auf externe Test-Hosts ist strikt untersagt. Alle Builds, AST-Checks und Flake-Prüfungen finden ausschließlich lokal statt.

---

## Eiserne Agenten-Arbeitsregeln (Strikte Arbeitsdisziplin)

1. **Vor jeder Code-Änderung (Pre-Check):**
   - Prüfe zwingend [`.agent-state.json`](./.agent-state.json) auf bekannte Sackgassen und Fehler (`dead_ends_and_failures`).
   - Konsultiere [`docs/adr/llm-index.json`](./docs/adr/llm-index.json) für aktive Architekturentscheidungen und Namenskonventionen.
2. **Nach jeder Code-Änderung (Post-Record):**
   - Dokumentiere jeden Fix, Refactor oder Invarianten-Schutz in [`.agent-state.json`](./.agent-state.json) unter `recent_refactorings`.
   - Trage genutzte GitHub-Repositories, Doku-Quellen oder Upstream-Muster in [`docs/UPSTREAM-SOURCES.md`](./docs/UPSTREAM-SOURCES.md) ein.
3. **Ideen-Verwaltung (Zero Code-Drift):**
   - Neue Projekt-Ideen, Erweiterungen oder Refactoring-Gedanken gehören **ausschließlich** in die [`ROADMAP.md`](./ROADMAP.md) (Abschnitt `Backlog`), niemals unaufgefordert oder spekulativ in den Code.
4. **Verfassungs-Zwang (ADR-0000):**
   - Jede Code-Änderung muss die Kern-Invarianten einhalten und wird per `nix flake check` lokal verifiziert.
5. **systemd-first (kernel-nah):**
   - Jede Aufgabe, die man mit einem **Programm/Extra-Daemon** lösen würde, wird **zuerst** auf ein **systemd-/Kernel-Äquivalent** geprüft: `journald`, `systemd.timer`, `systemd-tmpfiles`, `systemd-creds`, `systemd-coredump`, `systemd-timesyncd`, `systemd-resolved`, Socket-Activation, cgroup v2 (`MemoryMax`/`CPUWeight`), `nftables`, `systemd-oomd`, `WatchdogSec`.
   - Ist das systemd-Äquivalent **brauchbar**, wird **dieses** genommen — **kein** zusätzliches Programm.
   - Nur wenn **kein** brauchbares Äquivalent existiert (z. B. App-Metriken, S.M.A.R.T.), kommt ein Programm dazu — dann **leicht + Go + aus nixpkgs**.
6. **Etablierte Begriffe (Semantic Anchors):**
   - Methoden/Konzepte mit **etabliertem Namen** benennen statt Eigenschöpfung → siehe `docs/TERMINOLOGY.md` (unser Konstrukt → Katalog-Anker + Link).
   - Nur Namen aus dem Katalog zitieren; bei Zweifel dort nachsehen, nicht aus dem Gedächtnis.
7. **Generatoren, CI-Beweis, Dead-Config, Absicht (Kurzfassung von `docs/CONVENTIONS.md` §6):**
   - **Generatoren-Pflicht:** Wer ADRs/Dienste/Dateien ändert, lässt `docs/generate_index.py`, `scripts/gen_todo.py` und `50-core/medinix-meta.py generate-docs` **im selben Commit** laufen — sonst wird `Docs Index` bzw. `order-lint` rot.
   - **CI-Beweis statt -Behauptung:** „grün" nur nach Zählung **aller** Workflows des Head-SHA (`gh run list --limit 12 --json name,conclusion,headSha`).
   - **Deklariert ≠ wirkt:** jede Option/jedes Feld braucht einen **Leser** (`grep -rn "<name>" --include=*.nix .`).
   - **Absicht vor Konsistenz:** ein Review-/Subagent-Befund ist Rohmaterial, kein Auftrag — der Fix darf **kein laufendes Feature abschalten** (Default umlegen, Paket-Flag überschreiben).

---

## NixOS-Denkrahmen (zwei Skills)

- **Beim Schreiben:** Skill `nixos-mental-model` — welche Eigenschaft ist relevant (faul / zyklische Ableitung / hermetisch / zweistufig), welcher Klassische-Distro-Reflex zieht?
- **Beim Prüfen:** Skill `nixos-idiom-audit` — Schicht 1 Signal → Schicht 2 Kontext → Schicht 3 `nix flake check` **ohne** `--impure`.
- **Regel daneben:** `docs/adr/ADR-040-gerichtete-abhaengigkeiten.md` (Kanten nur Quelle → Ableitung; Guardrails lesen nie das Abgeleitete, das sie prüfen).
- Kompakt-Nachschlagewerk: `docs/concepts/nixos-eigenschaften.md`.

## Semantic Anchors (NixOS-Vokabular)

`docs/NIXOS-ANCHORS.md` - 25 Anker in drei Gruppen (was NixOS IST · was es NICHT IST ·
Anti-Patterns), je mit Details, Kernkonzepten, Wann-nutzen, Missverstaendnissen, Kritik,
Status, Quelle+Jahr und **Durchsetzung** (welcher Check/welche Korridor-Regel). Geprueft
von `scripts/check_nixos_anchors.py` (Katalog-Lint) in `order-lint`. Der Anker steuert das
Denken, die **Messung** liefert die Wahrheit; unsere Konstrukte sind auf den vendorten
Katalog (`docs/anchors/`) gemappt in `docs/TERMINOLOGY.md`.
Skill-Hinweis: `nixos-mental-model` (Denkrahmen) und `nixos-service-discovery` (Aufnahme)
nutzen die Anker als Pruefkriterien.

## Verbotene Technologien (Denylist) + Architektur-Manifest

- **Denylist:** `50-core/BANNED_TECHNOLOGIES.md` - geprueft von
  `scripts/check_banned_technologies.py` in `order-lint` (nur **aktivierende** Muster; verbietende
  Assertions, Guard-Namen und Meldungen sind erlaubt).
- **Manifest:** `docs/adr/ADR-0003-architektur-manifest.md` - die fuenf bindenden Prinzipien
  (Tri-State-Boundary · additive Config ohne `mkForce` · fail-closed · nix-native/Zero-Container ·
  dendritic/SSoT) als Korridor-Regeln **AB-047…AB-051**.

## Die Kette (Knoten/Kanten) - jede Kante hat einen Check

Code · ADRs · Docs · Skills · MCP · Korridor sind ueber sieben Kanten verbunden; die Kettentabelle
mit den zugehoerigen Checks steht in `docs/CONVENTIONS.md` („Die Kette: sechs Knoten, sieben
Kanten"). Kurzfassung: Code->Manifest (`check_manifest_edge.py`), Code/ADR->Index
(`check_adrs.py`), Docs->Generatoren (`gen_todo`/`gen_service_map`/`check-docs`/`generate_index`),
Skills (Sichtbarkeit lokal per `link-skills.sh`, Form **und MCP-Deklaration** per `check_skills.py`:
wer `tools["<server>"]` aufruft, braucht `mcp: [<server>]` im Front-Matter - Server-Liste in
`scripts/mcp-servers.txt`, Details in `docs/MCP-SETUP.md`), Korridor->Checks
(`check_corridor.py`), NixOS-Idiome (`nixos_idiom_audit.py --p0-only`) - alle in `order-lint`
bzw. `flake check`. Fund ohne Check ist eine offene Kante: **fixen oder Ausnahme eintragen**.

## Grundfunktionen sind bindend (ADR-0002)

Deklarativ, deterministisch/reproduzierbar, faul+eval-zeit-sicher, fail-closed,
systemd-native ohne Container - als **Regel**, nicht als Empfehlung
(`docs/adr/ADR-0002-nixos-grundfunktionen.md`). Mechanisch geprueft in `order-lint`
(`scripts/check_banned_technologies.py`): keine aktivierte Container-Engine, keine unreinen
Eval-Quellen. Korridor: AB-042 (Assertions lesen nur Quellen), AB-043 (diese fuenf Funktionen).
ADR-Formregel + Index: `docs/adr/llm-index.json`, geprueft von `scripts/check_adrs.py`.

## Projekt-Skills: Ablage, Sichtbarkeit, Durchsetzung (2026-10-16)

- **Ablage:** Projekt-Skills leben **im Repo** unter `docs/agents/<kategorie>/<skill>/SKILL.md`
  (versioniert). `~/.config/opencode/skills/` ist **kein** Ablageort, sondern nur der
  Discovery-Pfad des Agenten.
- **Sichtbarkeit:** `bash scripts/link-skills.sh` legt/aktualisiert die Symlinks
  `~/.config/opencode/skills/<name>` -> `docs/agents/.../<name>` (idempotent, `--dry-run` dabei).
  Symlinks sind maschinenlokal und daher nicht versionierbar: nach jedem frischen Clone einmal
  ausfuehren, sonst sieht die Session die Projekt-Skills nicht.
- **Formregel:** Front-Matter mit `name` (== Ordnername, eindeutig) und `description`. Die
  `description` ist das Einzige, was die Session ohne Laden sieht - sie muss den **Ausloeser**
  nennen, nicht das Thema.
- **Durchsetzung:** `python3 scripts/check_skills.py` laeuft in `order-lint` (fail-closed bei
  Formfehlern; zu kurze Beschreibungen werden als Hinweis gelistet).
- **Kuration:** `scripts/skills-exclude.txt` listet Skills, die **nicht** verlinkt werden
  (fremde Workflows/andere Projekte). Inhalt bleibt im Repo - nur die Sichtbarkeit ist aus.
  Der Linker raeumt solche Symlinks beim naechsten Lauf selbst weg.

## Architektur-Invarianten (ADR-0000, NICHT verhandelbar)

- **Dezimalrahmen (UPG):** `Port = UID = Primär-GID = ServiceNum × 10`. Die geteilte Gruppe `media` (GID 5000) ist **ausschließlich** als `extraGroups`/supplementary zulässig, niemals als Primärgruppe. Geteilte Ablagen: `2775 root:media` (SetGID), damit neue Dateien die Gruppe `media` erben.
- **Flache Struktur:** `XX-domain/NNN-service.nix` — nie tiefer verschachteln.
- **systemd-native:** Kein Docker, keine Container-Engines, kein Network Namespace (`netns`). VPN-Confinement erfolgt rein über `meta skuid` und Route-Hook Policy Routing.
- **systemd-first (kernel-nah):** Jede Aufgabe wird **zuerst** auf ein systemd-/Kernel-Äquivalent geprüft; ein **brauchbares** Äquivalent gewinnt gegen ein Extra-Programm (Arbeitsregel 5). Ein Programm nur, wo **kein** Äquivalent existiert — dann leicht (Go), aus nixpkgs.
- **Chameleon Caddy:** `config.services.caddy.enable` → inject in globalen Caddy | sonst → dedizierter `caddy-media` Unit-Besitzer.
- **Binding:** Alle Backend-Dienste binden ausschließlich an `127.0.0.1` (nur Ingress ist exponiert).
- **Fail-closed:** Assertions bedeuten sofortigen Build-Abbruch (`throw`), niemals stille Warnungen oder Ignorieren.
- **Keine Inline-Secrets:** Ausschließlich `LoadCredentialEncrypted` oder `EnvironmentFile`.
- **Login-Zugang (L-047):** Die Engine setzt `users.mutableUsers = lib.mkDefault false`. Der **Host liefert** das privilegierte Konto: `medinix.security.loginKeys = [ "ssh-ed25519 …" ]` — oder er setzt `users.mutableUsers = true;`. Ohne beides bricht die nixpkgs-Assertion den **Build** ab (fail-closed, **kein** Lockout). Siehe `docs/ADMIN-HANDOFF.md` §Credentials.

---

## Repo-Landkarte (damit niemand neu explorieren muss)

**Struktur = Dezimalrahmen (ADR-0000):** `XX-domain/NNN-dienst.nix` — `XX` = Dekade, `NNN` = Dienstnummer; daraus folgen Port, UID und Primär-GID (`NNN × 10`, UPG).

| Dekade | Rolle (ADR-0000 §3) | Inhalt |
|---|---|---|
| `50-core` | Foundation | Host-Baseline, Engine-Anbindung, Host-Integration |
| `51-ingress` | Access | Caddy (511) · Pocket-ID (512) · Cloudflare-DDNS (513) · ACME (514) · mDNS (515) · Landingpage (518) · Ingress-Guardrails (519) |
| `52-security` | Security | nftables-Baseline (520) · sealed Credentials (521) · WireGuard (525) · VPN-Killswitch (526) |
| `53-acquisition` | Ingestion | Sonarr · Radarr · Readarr · Lidarr · Prowlarr |
| `54-transfer` | Processing | SABnzbd (541) · Mover (543) |
| `55-playback` | Core UI/App | Jellyfin (551) · Audiobookshelf (552) · Navidrome (553) · Feishin (554) |
| `56-exposition` | Exposition | Seerr (561) |
| `57-maintenance` | Maintenance | Storage/SetGID (570) · SQLite-WAL (571) · Recyclarr (572) · Provisioning (574) · Update-Notifier (575) · Backup/restic (576) · Drift (577) · Orphan-Cleanup (578) · Backup-SSH (579) |
| `58-observability` | Observability | ntfy (581) · Gatus (582) · Runtime-Guard (583) · Boot-Watchdog (584) · Exporter (585) · Disk-Health/smartd (587) |
| `59-guardrails` | Guardrails | Cross-Domain-Assertions (591) |

| Ort | Was |
|---|---|
| `lib/` | **Engine** `decimal-framework.nix` (besitzt `users.users.<dienst>`, StateDirectory, UPG) · `service-factory.nix` / `service-contract.nix` (Unit-Gerüst + Manifest-Schema) · `hardening-profiles.nix` (**einzige** Hardening-Quelle) · `registry.nix` (SSoT) · `creds` · `memory-policy` · `arr-settings` |
| `docs/adr/` | 47 Entscheidungen — `ADR-0000` ist die Verfassung, `ADR-00-nixmeta-v3` der Header-Standard |
| `docs/agents/` | Skill-Tree (Ordner-`AGENTS.md` sind **generiert** aus den nixmeta-Headern!) |
| `docs/audit/` | Altstände (`<jahr-monat>/`) — **nicht** aktuell |
| `docs/{arch,patterns,guides,concepts,learn,examples}/` | Wissensbasis (mkdocs-Paket `.#docs`) |
| `.agent-state.json` | **Korridor**: Whitelist, 53 Blacklist-Regeln, getroffene Entscheidungen, Sackgassen |
| `ROADMAP.md` | die einzige Roadmap (Backlog priorisiert · Verworfen · Done mit Hashes) |
| `docs/AUDIT-LEDGER.md` | Befund-Gedächtnis mit Messung + Rollback je Zeile |
| `docs/CONVENTIONS.md` | Ordner- und Root-Regeln |
| `docs/RUNBOOK.md` | Betrieb & Triage — maschinenlesbare Playbooks (`medinix triage <id>`) |
| `docs/TERMINOLOGY.md` | Etablierte Begriffe (Semantic Anchors): unser Konstrukt → Katalog-Anker + Link |
| `scripts/` | `nixmeta_check.py` (Header-Ratsche + `nixmeta-baseline.txt`) · `check_adrs.py` · `check_skills.py` + `link-skills.sh` (+ `skills-exclude.txt`) · `check_banned_technologies.py` · `gen_todo.py`/`gen_service_map.py` (generierte Sichten) · `medinix-seal-secret.*` · `migrate-uids.sh` |
| `flake.nix` | Outputs + **41 Checks** (Voll-Stack-Ratsche, 15 Negativtests, Port-Riegel, Unit-Skripte) |

**Einstieg in 4 Schritten:** 1. `.agent-state.json` (Korridor) → 2. `ROADMAP.md` (was als Nächstes) → 3. `docs/AUDIT-LEDGER.md` (was schon gefunden wurde) → 4. `docs/CONVENTIONS.md` (Regeln).

---

## Shell-Amok-Schutz (Permissions)

`opencode.json` im Root ist **absichtlich gitignoriert** (maschinenspezifische Modell-/Provider-Config), enthält aber seit 2026-10-15 ein `permission`-Regelset. Damit die Regeln reproduzierbar sind, hier die verbindliche Liste (`"*": "allow"` als Catch-all, danach auf **`ask`**):

```text
rm -rf /  ·  rm -rf ~ / $HOME / /home/*  ·  rm -rf .git*
git push*  ·  git reset --hard*  ·  git clean -*  ·  git branch -D*  ·  git checkout -- *
sudo *  ·  systemctl *  ·  nixos-rebuild *  ·  nix store gc*  ·  nix-collect-garbage*
dd *  ·  mkfs*  ·  shutdown*  ·  reboot*  ·  chmod -R *  ·  chown -R *
> /etc/*  ·  >> /etc/*
```

Zwei Regeln erzwingen Korridor-Beschlüsse technisch: **jeder Push** und **jedes `git checkout -- <datei>`** (verwirft Änderungen) verlangen eine Bestätigung. Muster-Regeln werden von der **letzten** passenden Regel entschieden (Catch-all zuerst); Schema: <https://opencode.ai/docs/permissions/>. Die Config wird **nicht** hot-reloaded — sie greift nach einem Neustart von opencode.
