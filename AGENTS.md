# mediNix-core — AGENTS.md

> [!IMPORTANT]
> **REINE LOKALE AUSFÜHRUNG:** Es existieren keine externen Remote-Hosts. Jeglicher SSH- oder rsync-Zugriff auf externe Test-Hosts ist strikt untersagt. Alle Builds, AST-Checks und Flake-Prüfungen finden ausschließlich lokal statt.

---

## Eiserne Agenten-Arbeitsregeln (Strikte Arbeitsdisziplin)

1. **Vor jeder Code-Änderung (Pre-Check):**
   - Prüfe zwingend [`.agent-state.json`](file:///home/moritz/repos/mediNix-core/.agent-state.json) auf bekannte Sackgassen und Fehler (`dead_ends_and_failures`).
   - Konsultiere [`docs/adr/llm-index.json`](file:///home/moritz/repos/mediNix-core/docs/adr/llm-index.json) für aktive Architekturentscheidungen und Namenskonventionen.
2. **Nach jeder Code-Änderung (Post-Record):**
   - Dokumentiere jeden Fix, Refactor oder Invarianten-Schutz in [`.agent-state.json`](file:///home/moritz/repos/mediNix-core/.agent-state.json) unter `recent_refactorings`.
   - Trage genutzte GitHub-Repositories, Doku-Quellen oder Upstream-Muster in [`docs/UPSTREAM-SOURCES.md`](file:///home/moritz/repos/mediNix-core/docs/UPSTREAM-SOURCES.md) ein.
3. **Ideen-Verwaltung (Zero Code-Drift):**
   - Neue Projekt-Ideen, Erweiterungen oder Refactoring-Gedanken gehören **ausschließlich** in die [`ROADMAP.md`](file:///home/moritz/repos/mediNix-core/ROADMAP.md) (Abschnitt `Backlog`), niemals unaufgefordert oder spekulativ in den Code.
4. **Verfassungs-Zwang (ADR-0000):**
   - Jede Code-Änderung muss die Kern-Invarianten einhalten und wird per `nix flake check` lokal verifiziert.
5. **systemd-first (kernel-nah):**
   - Jede Aufgabe, die man mit einem **Programm/Extra-Daemon** lösen würde, wird **zuerst** auf ein **systemd-/Kernel-Äquivalent** geprüft: `journald`, `systemd.timer`, `systemd-tmpfiles`, `systemd-creds`, `systemd-coredump`, `systemd-timesyncd`, `systemd-resolved`, Socket-Activation, cgroup v2 (`MemoryMax`/`CPUWeight`), `nftables`, `systemd-oomd`, `WatchdogSec`.
   - Ist das systemd-Äquivalent **brauchbar**, wird **dieses** genommen — **kein** zusätzliches Programm.
   - Nur wenn **kein** brauchbares Äquivalent existiert (z. B. App-Metriken, S.M.A.R.T.), kommt ein Programm dazu — dann **leicht + Go + aus nixpkgs**.
6. **Etablierte Begriffe (Semantic Anchors):**
   - Methoden/Konzepte mit **etabliertem Namen** benennen statt Eigenschöpfung → siehe `docs/TERMINOLOGY.md` (unser Konstrukt → Katalog-Anker + Link).
   - Nur Namen aus dem Katalog zitieren; bei Zweifel dort nachsehen, nicht aus dem Gedächtnis.

---

## NixOS-Denkrahmen (zwei Skills)

- **Beim Schreiben:** Skill `nixos-mental-model` — welche Eigenschaft ist relevant (faul / zyklische Ableitung / hermetisch / zweistufig), welcher Klassische-Distro-Reflex zieht?
- **Beim Prüfen:** Skill `nixos-idiom-audit` — Schicht 1 Signal → Schicht 2 Kontext → Schicht 3 `nix flake check` **ohne** `--impure`.
- **Regel daneben:** `docs/adr/ADR-040-gerichtete-abhaengigkeiten.md` (Kanten nur Quelle → Ableitung; Guardrails lesen nie das Abgeleitete, das sie prüfen).
- Kompakt-Nachschlagewerk: `docs/concepts/nixos-eigenschaften.md`.

## Architektur-Invarianten (ADR-0000, NICHT verhandelbar)

- **Dezimalrahmen (UPG):** `Port = UID = Primär-GID = ServiceNum × 10`. Die geteilte Gruppe `media` (GID 5000) ist **ausschließlich** als `extraGroups`/supplementary zulässig, niemals als Primärgruppe. Geteilte Ablagen: `2775 root:media` (SetGID), damit neue Dateien die Gruppe `media` erben.
- **Flache Struktur:** `XX-domain/NNN-service.nix` — nie tiefer verschachteln.
- **systemd-native:** Kein Docker, keine Container-Engines, kein Network Namespace (`netns`). VPN-Confinement erfolgt rein über `meta skuid` und Route-Hook Policy Routing.
- **systemd-first (kernel-nah):** Jede Aufgabe wird **zuerst** auf ein systemd-/Kernel-Äquivalent geprüft; ein **brauchbares** Äquivalent gewinnt gegen ein Extra-Programm (Arbeitsregel 5). Ein Programm nur, wo **kein** Äquivalent existiert — dann leicht (Go), aus nixpkgs.
- **Chameleon Caddy:** `config.services.caddy.enable` → inject in globalen Caddy | sonst → dedizierter `caddy-media` Unit-Besitzer.
- **Binding:** Alle Backend-Dienste binden ausschließlich an `127.0.0.1` (nur Ingress ist exponiert).
- **Fail-closed:** Assertions bedeuten sofortigen Build-Abbruch (`throw`), niemals stille Warnungen oder Ignorieren.
- **Keine Inline-Secrets:** Ausschließlich `LoadCredentialEncrypted` oder `EnvironmentFile`.

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
| `docs/adr/` | 33 Entscheidungen — `ADR-0000` ist die Verfassung, `ADR-00-nixmeta-v3` der Header-Standard |
| `docs/agents/` | Skill-Tree (Ordner-`AGENTS.md` sind **generiert** aus den nixmeta-Headern!) |
| `docs/audit/` | Altstände (`<jahr-monat>/`) — **nicht** aktuell |
| `docs/{arch,patterns,guides,concepts,learn,examples}/` | Wissensbasis (mkdocs-Paket `.#docs`) |
| `.agent-state.json` | **Korridor**: Whitelist, 23 Blacklist-Regeln, getroffene Entscheidungen, Sackgassen |
| `ROADMAP.md` | die einzige Roadmap (Backlog priorisiert · Verworfen · Done mit Hashes) |
| `docs/AUDIT-LEDGER.md` | Befund-Gedächtnis mit Messung + Rollback je Zeile |
| `docs/CONVENTIONS.md` | Ordner- und Root-Regeln |
| `docs/RUNBOOK.md` | Betrieb & Triage — maschinenlesbare Playbooks (`medinix triage <id>`) |
| `docs/TERMINOLOGY.md` | Etablierte Begriffe (Semantic Anchors): unser Konstrukt → Katalog-Anker + Link |
| `scripts/` | `nixmeta_check.py` (Header-Check) · `medinix-seal-secret.*` · `migrate-uids.sh` |
| `flake.nix` | Outputs + **49 Checks** (Voll-Stack-Ratsche, 15 Negativtests, Port-Riegel, Unit-Skripte) |

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
