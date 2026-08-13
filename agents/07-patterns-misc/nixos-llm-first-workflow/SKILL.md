---
name: nixos-llm-first-workflow
description: >
  NixOS-Homelab-Projekte, die LLM-first, DB-zentriert und auf Windows 11 entwickelt werden.
  Deckt Patch-Erstellung, Validator-Design, Closed-Loop-Hooks und Projektkonventionen ab.
  Trigger: NixOS-Flakes, DB-SSoT (nixos_docs.db), Windows-Git-Bash + PowerShell,
  LLM-first ohne Menschenlesbarkeit.
---

# NixOS LLM-First Workflow

## Über dieses Repo (was IMMER gilt)

- **Harte Port-Definitionen (z.B. 8989, 7878) sind untersagt.** Module müssen Ports über `config.services.*.port` (mit Fallback auf ADR-Standard, falls zwingend nötig) oder über zentrale `mediNix.ports`-Optionen beziehen.
- **SQLite-Pragmas für SSD (Tier B):** Alle Datenbanken auf Tier B (SSD) müssen zwingend `WAL`-Mode, `synchronous=NORMAL`, `cache_size=-20000` und `temp_store=MEMORY` nutzen.
- **Zero-Spinup-Regel für HDDs:** Kein Zugriff auf Tier C (HDD) in Wartungsskripten, außer bei explizitem Stream-Bedarf. Metadaten-Scans und VACUUM/OPTIMIZE-Events müssen strikt auf Tier B verbleiben.
- **Kein Inline-Scripting für Wartung:** Keine Cronjobs. Alles muss über `systemd` Timer/Events (ExecStopPost etc.) abgebildet werden.
- **Single-Service-File-Modell:** Ein Modul pro Dienst (530-acquisition.nix, 540-transfer.nix) ist Pflicht, um Granularität bei Security-Sandboxing (systemd-native!) zu wahren.
- **Fehlende `cfg.ports`-Definition:** Wenn ein Modul `cfg.ports` verwendet, MUSS eine entsprechende `lib.mkOption` in der `500-mediNix-master.nix` oder dem Modul existieren. Spaghetti-Konfiguration (Modul nutzt Port-Var, die nirgends definiert ist) ist ein Fehler.
- Keine menschenlesbaren Reports (`CURRENT_STATUS.md`, `SOURCES.md` etc.).
- Andrew Grant-Stil: `00-core` → `90-policy`, aber nicht blind übernehmen.
- Pflichtfeld NIXMETA in jedem `.nix`-Modul: `domain`, `id`, `status`, `provides`, `requires`.
- Zielplattform: Windows 11 (Git Bash für Hooks, PowerShell für Aliase).
- Patch-Lieferung: immer als Anhang, nie als Volltext im Chat.

## Patch-Lieferung (niemals inline)

Regel: Bei mehr als ~3 kleinen Blöcken → eine Datei im `/tmp/nixos-patches/`-Tree,
dann `MEDIA:` liefern. Max 5 Zeilen Zusammenfassung im Chat.

Format der Patch-Datei:

```
══════════════════════════════════════════════
BESCHREIBUNG
══════════════════════════════════════════════

ANLEITUNG (max 4 Schritte)
...

........................................................................................................................
PATCH N: <zielpfad>  (neu/ergänzen)
........................................................................

<block>
...
........................................................................................................................
```

Keine Erklärungen zu *warum* der Patch so ist — nur *was* zu tun ist.
Der Patch selbst enthält Inline-Kommentare, falls nötig.

## Validator-Regeln (validate_ssot.py)

Diese Prüfungen sind hart (Build bricht ab):

1. Jede `.md`-Datei in `ADR/` hat erlaubten Status:
   `proposed | accepted | deprecated | superseded-by:ADR-YY`.
   Platzhalter wie `ADR-XX`, `draft # draft | active…` oder `Template` sind **Fehler**.
2. Jedes `Nix Files/modules/*.nix` hat einen `---NIXMETA---`-Block mit den
   vier Pflichtfeldern `domain`, `id`, `status`, `provides`, `requires`.
   **Keine Ausnahme.** NIXMETA ist für LLM-first obligatorisch, weil es die
   einzige maschinenlesbare Schnittstelle zum Modul ist.
3. In ADRs referenzierte Pfade (`guide`, `modules:[…]`) existieren physisch.
4. Datenbankeinträge (`documents.status`) enthalten keine Template-Rohlinge.

Leichte Warnungen (kein Abbruch):

- Fehlende `ref.code`-Bindung in ADRs an ein konkretes Nix-Modul.

## Windows-Zwänge

- Pre-Commit-Hook: Bash-Skript, funktioniert unter Git Bash auf Windows.
- Deployment-Alias: PowerShell-Skript (`#!/usr/bin/env pwsh`), Einrichtung über `$PROFILE`.
- Keine Unix-Pfade wie `/usr/bin/foo` ohne Windows-Äquivalent, keine `sudo`.
- `python` statt `python3` in Hooks verwenden (Git Bash auf Windows findet meist nur `python`).

## Fokus-Regel (Single-Repo Disziplin)
- **Nur mediNix (50-media) fokussieren.** User korrigierte: "kognitiv bei der Geschichte Media PC bleiben... kein zweites, drittes Repo aufmachen".
- **Kein Abschweifen:** Repos wie `devNIX`, `Nix-Grok`, `NixmitGROK` nur als **Gold-Standard Quellen** nutzen, nicht als eigene Projekte.
- **Gold-Standards extrahieren:** Mit Skill `medinix-audit-suite` (siehe unten) Patterns aus anderen Repos ziehen und in `/opt/data/50-mediNix/` integrieren.
- **Arbeitsbereich:** `/opt/data/50-mediNix/` (Boilerplate), `/opt/data/docs/` (Doku), `/opt/data/github_repos/mediNix/` (Original-Repo). Keine neuen Repos eröffnen.

## Skill-basierte Audit-Pipeline
- **Skill `medinix-audit-suite`** (user-owned, via `hermes curator adopt medinix-audit-suite` für Updates) ist der empfohlene Workflow für Repo-Analysen.
- **Ablauf:** Repo klonen → Struktur prüfen (Dezimalrahmen) → Gold-Standards extrahieren (Isomorphie, Anti-Lockout, systemd Isolation, SQLite Tuning, Provisionierung) → Bewerten (für mediNix brauchbar?) → Integrieren in Boilerplate.
- **Output:** ADR in `/opt/data/docs/ADR/`, Dateien in `/opt/data/50-mediNix/` aktualisiert.

- Deutsch, knapp, direkt.
- Kein Smalltalk, keine theatralischen Formulierungen ("schlimmster Fehler", "Katastrophe").
- Keine langen Einleitungen. Erste oder zweite Nachricht bereits Ergebnis.
- **Keine unnötigen Rückfragen.** Wenn der Nutzer "Mach das" sagt, dann machen, nicht nochmal fragen "Bist du sicher?". Das führt zu Frustration ("Warum? fragst du zum Scheiße nochmal doppelt und dreifach").
- **Direkte Umsetzung bevorzugt.** User will Ergebnis, nicht Diskussion. Bei klarer Anweisung sofort Befehle liefern, nicht erst lang erklären.
- **Bei TTY-Zugriff (Monitor/Tastatur am Server):** Kommandos extrem kurz halten. User hat "keinen Bock, einen Harry-Potter-Roman in die Tastatur reinzuhämmern". Nur essenzielle Befehle liefern, keine langen Erklärungen.
- **People-Pleaser vermeiden:** Nicht immer nur "Ja und Amen" sagen, sondern kritisch hinterfragen wenn etwas technisch nicht sinnvoll ist. User will ehrliche Einschätzung, kein blindes Bestätigen.
- Wenn der Nutzer korrigiert ("Das Repository ist NICHT für Menschen lesbar konzipiert"),
  dann die Regel sofort in die Skill übernehmen und zukünftige Vorschläge daran ausrichten.
- **Vorhandene Konfiguration prüfen BEFORE raten.** Wenn der Nutzer sagt "ich habe schon einen
  Google API Key gesetzt", dann zuerst `.env` und Config lesen, nicht erst annehmen, dass nichts
  gesetzt ist.
- **Keine Entschuldigungs-Schleifen.** Wenn ein Fehler passiert ist, einmal kurz eingestehen, dann direkt zur Lösung. Kein "das ist peinlich von mir" — das ist Zeitverschwendung.
- **Bei Tool-Blockaden (Security, Approvals):** Kurz sagen was geblockt wurde und was der Nutzer
  tun kann. Keine 3-4 Retry-Versuche mit leicht abgewandelten Commands — das frustriert.
- **People-Pleaser vermeiden (WICHTIG):** Nicht immer nur "Ja und Amen" sagen, sondern kritisch hinterfragen wenn etwas technisch nicht sinnvoll ist. **User will ehrliche Einschätzung, kein blindes Bestätigen.** Wenn eine Idee schlecht ist, direkt sagen: "Das ist technisch falsch/ineffizient/riskant, weil...". Beispiel aus Session: User wollte Flake-Isolation testen, aber die Container-Isolation funktionierte nicht — stattdessen das Problem ehrlich analysieren statt "Ja, machen wir".

## SSH-Key-Sicherheit (kritisch)

- **Private SSH-Keys NIEMALS unverschlüsselt in Chat kopieren.** Wenn der Nutzer einen privaten Key postet, ihn NICHT nutzen, sondern warnen: "Das ist ein Sicherheitsrisiko — Key sollte sofort rotiert werden."
- **Keine privaten Keys in Git-Repos.** Keys gehören in `~/.ssh/` mit `chmod 600`, niemals ins Repo.
- **Ed25519 bevorzugen.** RSA < 4096, DSA, ECDSA sind unsicher (nicht quantensicher genug).
- **SSH-Keys in 590-assertions prüfen.** mediNix hat `592-ssh-hardening.nix` — das verhindert unsichere Key-Typen per Build-Assertion.

## Infrastruktur-Unterscheidung (WICHTIG!)

**Hermes Agent läuft auf Unraid (192.168.2.250:53844) in einem Docker Container.**
- **Unraid = Host-System** (Hermes Container läuft hier)
- **q958 (192.168.2.73:22) = Remote NixOS Target** (Deployment-Ziel, User: jarvis)
- **SSH-Zugriff:** Von Hermes-Container zu q958 funktioniert (Key: `/tmp/q958_key`)
- **Kein SSH-Zugriff:** Von Hermes-Container zu Unraid (Key wird nicht akzeptiert)
- **MCP-Server:** Auf q958 installieren (via `nix-env`), nicht im Hermes-Container
- **Bei Hard-Reset von q958:** User muss physisch Strom ziehen (kein IPMI/IDRAC). Backup-SSH (Port 2222) wurde in alten Repos (`mynixos-v5`) erwähnt, aber auf jungfräulichem q958 nicht konfiguriert.

**Konsequenz:**
- NixOS Deployments laufen auf q958 (via SSH)
- Unraid ist nur der Host für den Hermes Agent
- Dateien für q958: Per `scp` vom Hermes-Container auf q958 übertragen
- Config-Tests: Auf q958 mit `nixos-rebuild dry-run --flake .#check`

## Container-Isolation (systemd-native, kein netns!)

- **NIEMALS netns (Network Namespaces) verwenden.** Das war ein Fehler in `521-usenet-confinement.nix`. User hat es explizit verboten.
- **systemd-native Isolation verwenden:** `RestrictNetworkInterfaces`, KEINE `IPAddressDeny = [ "any" ]` (blockiert Inter-Service-Kommunikation).
- **Inter-Service Kommunikation ist PFLICHT:** Alle mediNix Dienste (Sonarr, Radarr, Jellyfin, etc.) MÜSSEN sich über Loopback (`127.0.0.1`) erreichen können.
- **Caddy-Only Ingress:** Nur Caddy braucht Zugriff von außen (LAN), alle anderen Dienste nur Loopback.
- **Richtig:** `RestrictNetworkInterfaces = [ "lo" ]` (beschränkt auf Loopback), ohne `IPAddressDeny`.
- **Falsch:** `IPAddressAllow = [ "127.0.0.1" ]` + `IPAddressDeny = [ "any" ]` (blockiert Dienste komplett).
- **Zentralisierung in `lib/service-factory.nix`:** `containerIsolation` Funktion nutzen, nur `RestrictNetworkInterfaces` setzen, keine IP-basierte Filterung.

### Debugging: Warum `RestrictNetworkInterfaces` nicht greift

**Häufiger Fehler (2026-08-09):** `containerIsolation` Funktion ist definiert, aber nicht korrekt in `systemd.services.${name}.serviceConfig` injiziert.

**Korrekte Implementierung:**
```nix
# In mkService:
isolation = containerIsolation { inherit tier vpnInterface extraInterfaces; };
systemd.services.${name}.serviceConfig = lib.mkMerge (
  [ (systemdHardening { ... }) ]
  ++ [ isolation ]  # WICHTIG: Als Liste einfügen, nicht als einzelnes Element!
  ++ [ extraSystemd ]
);
```

**Fehlererkennung:**
1. `nixos-rebuild build --flake .#check` ausführen
2. Config prüfen: `grep 'RestrictNetworkInterfaces' /nix/store/.../etc/systemd/system/sonarr.service`
3. Wenn nicht da: `inherit tier vpnInterface extraInterfaces` fehlt in `mkService` Aufruf
4. Oder: `tier = "none"` nicht in `arrApps` gesetzt

**Test-Deployment:**
- `nix flake check` evaluiert erfolgreich
- `nixos-rebuild dry-run --flake .#check` läuft durch
- Aber: Systemd-Optionen tauchen in gebauter Config nicht auf, wenn Injection fehlt

**Live-Debugging auf q958:**
```bash
# Auf q958 einloggen
ssh jarvis@192.168.2.73

# Config bauen
cd /home/jarvis/mediNix
nixos-rebuild build --flake .#check

# Systemd-Unit prüfen
grep 'RestrictNetworkInterfaces' /nix/store/.../etc/systemd/system/sonarr.service

# Wenn leer: Config-Problem, nicht Deployment-Problem
```

## NixOS MCP-Server (Live-Debugging)

- **nixos-mcp** ist der offizielle NixOS MCP-Server für Live-Abfragen von Optionen, Services, etc.
- **Installation auf q958:** `ssh jarvis@192.168.2.73` dann `nix-env -iA nixpkgs.nixos-mcp` (falls in nixpkgs verfügbar)
- **Alternative:** `nix search nixpkgs ^nixos-mcp^` um Paket zu finden
- **Nutzen:** Hilft beim Debuggen, warum `RestrictNetworkInterfaces` nicht greift (Live-Inspektion von `systemd.services.*.serviceConfig`)
- **Ohne MCP:** `nixos-rebuild build` + `grep` in `/nix/store/.../etc/systemd/system/` Configs
- **Hinweis:** MCP-Server kann nicht im Hermes-Container installiert werden (kein Nix im PATH). Muss auf q958 installiert werden.

## 10/10 Review-Prozess

- **Batch-Review mit `claudereview_prompt.md`:** 12 Batches, idempotent, für Repository-Audits.
- **Score 10/10 erreichen:** Security-Härtung (systemd-Isolation, SSH, nftables) konsequent durchziehen.
- **Review abschließen VOR Deployment:** Erst Review (10/10), dann deployen.
- **Gold-Extraktion aus alten Repos:** `mynixos-v5` hat wertvolle Patterns (Service Slimming, nftables, Kernel Hardening).

## Knowledge-Base (read-only Mount)

Die Obsidian-Vaults und NixOS-Konfig-Dateien sind als read-only Mount unter `/opt/data/knowledge/` verfügbar:

- `/opt/data/knowledge/INDEX.md` — Verzeichnisübersicht (erste Anlaufstelle)
- `/opt/data/knowledge/obsidian/nixos/` — NixOS Obsidian-Vault (ADRs, Guides, Quellen, DBs: nixos_docs.db, memdb.db)
- `/opt/data/knowledge/obsidian/websites_software/` — Websites & Software Vault (Caddy, Context Bundler, DIN-Brief Neo etc.)
- `/opt/data/knowledge/nixos_local/` — Echte NixOS-Konfig-Dateien (modules/50-mediNix: 510-590, GEMINI.md, ADRs)

**Kritisch:** Der Obsidian-Vault enthält eine `AGENTS.md`, die explizit als NO-WORK-ZONE markiert ist. Die lokalen `.nix`-Dateien im Vault sind NOTIZEN, keine produktiven Configs. Die echten Configs liegen in `nixos_local/` oder auf dem Remote-Server. Vault-Dateien niemals als Basis für Deployments verwenden.

Siehe `references/knowledge-base-layout.md` für detaillierte Struktur.

## User-Kommunikationskanal und operative Grenzen

- **Primärer Kanal: WhatsApp.** Der Nutzer hat keinen direkten Terminal-Zugriff auf die Hermes-Instanz.
- **Bash-Befehle:** Der Nutzer kann `hermes config set ...` etc. nicht selbst ausführen — er weiß nicht wo und hat keine Shell.
- **Config.yaml:** Der Agent kann `/opt/data/config.yaml` nicht direkt editieren (Security-Restriction). Config-Änderungen (Model-Switch, Matrix-Setup, etc.) erfordern entweder:
  - Desktop-App-GUI (falls verfügbar), oder
  - Ein Setup-Script als Download, das der Nutzer auf einer Maschine mit Hermes-CLI ausführt.
- **Frustrations-Trigger:** Dem Nutzer zu sagen "führe diesen Bash-Befehl aus" wenn er keine Shell hat, führt zu Frustration. Lieber direkt sagen was möglich ist und was nicht, ohne Workaround-Schleifen.
- **Unraid-Server:** 192.168.2.250, SSH Port 53844. SSH-Key ist in der Session verfügbar. Nicht verwechseln mit Windows-PC.

## Pitfalls

- **Caddy-DNS-Konflikt**: Cloudflare blockiert Updates von IPs für Subdomains, wenn CNAME-Einträge existieren. Lösung: CNAME in Cloudflare durch A-Record ersetzen, bevor Caddy automatisches Update versucht.
- **Jellyfin-Timeout-Ursache**: Fehlerhafte Caddy-Upstream-Konfiguration in den `docker-proxy`-Labels oder Snippets (z.B. falsche Platzhalter `{args[n]}`) führen zu 404/502/Timeout, noch bevor der Request Jellyfin erreicht. Jellyfin-Logs sind in diesem Fall leer.
- **Caddy-Service-Log-Analyse**: Bei Proxy-Fehlern immer `docker exec caddy_grok_new cat /data/caddy.log` prüfen, nicht nur die Standard-Stdout-Logs.
- `nixos-rebuild switch` lokal auf Windows geht **nicht** — alias nur für den *Zielrechner*.
- SSH-Passwort-Login scheitert auf jungfräulichen Maschinen oft (PubkeyOnly). In dem Fall: NixOS-Installer/USB oder vorher Key-Setup.
- `rclone move` im Code, wenn `rsync` in SSOT-Doku als Primärwerkzeug deklariert ist — Konflikt sofort als ADR/Validator-Auffälligkeit markieren, nicht stillschweigend ersetzen.
- Wenn mehrere Patch-Blöcke existieren, **nicht** jeden Block mit eigenem Erklärungspaukenschlag umgeben — Struktur reicht.
- SSH-Passwort-Login aus Agenten-Umgebung scheitert meist (`/dev/tty` fehlt). Agent hat **keinen SSH-Client** für externe Hosts. Feste Regel: Nutzer lokal am Remote-Host die Vorbereitung ausführen lassen, Agent liefert nur Kommandos. Nutzer widerspricht manchmal ("Ich weiss das du dich per ssh verbindne kannst") — einmal klären, dann direkt zum Befehl wechseln.
- `nix` nach Installer-Lauf nicht im PATH: Dann `. /root/.nix-profile/etc/profile.d/nix.sh` ausführen oder eine neue SSH-Session öffnen.
- Validator-Pfade sind an die **tatsächliche Projektstruktur** gebunden: Realer ADR-Ordner kann `/ADR`, `/docs/adr` oder anders heißen. Vor dem Patch prüfen, ob `ADR/` existiert, sonst Pfad anpassen oder Warnung ausgeben.
- `nixos-anywhere` braucht einen **echten Hostnamen** aus der `flake.nix` (z. B. `.#q958`), kein Placeholder wie `<HOSTNAME>`.
- Neue Maschinen werden **unter `<project-root>/hosts/<hostname>/` angelegt** (aktuell: `Nix Files/hosts/<hostname>/`, siehe `references/project-structure.md`). Name muss eindeutig sein, idealerweise hostname-basiert.
- Curl-Installer-Abbruch: Wenn der Nutzer `^C` drückt, ist Nix nur teilweise installiert und danach nicht im PATH. Bessere Diagnose: `ls /nix`, dann gezielt nachinstallieren statt Installer blind zu wiederholen.

## Remote-Deploy: Servereigene Provisionierung per lokalem Nix (ohne nixos-anywhere)

Für neue Maschinen, bei denen der Build auf dem Ziel selbst laufen soll oder `nixos-anywhere` nicht einsetzbar ist (z. B. wenn der Deploy-Host identisch mit dem Zielhost wäre), diesen Workflow verwenden:

1. Nix lokal auf dem Ziel installieren (inklusive `nixbld`-Gruppe).
2. `experimental-features = nix-command flakes` in `/etc/nix/nix.conf` schreiben.
3. `configuration.nix` und `flake.nix` lokal auf dem Ziel ablegen.
4. `nix build .#<host>.system.toplevel` lokal ausführen.
5. `switch-to-configuration boot` gefolgt von `switch-to-configuration switch` lokal ausführen.
6. Nur am Ende `reboot` durch den Nutzer ausführen lassen.

## Remote-Provisioning (vserver, jungfräuliche Debian-Systeme)

### Häufige Fallstricke auf Debian-Trixie-vservern

- **`apt-get install xz` scheitert mit `Unable to locate package xz`**: Der Paketname ist **`xz-utils`**, nicht `xz`.
  ```bash
  apt-get update && apt-get install -y xz-utils
  ```
- **`/usr/local/bin` existiert nicht**: Zu erst anlegen, sonst schlägt jeder Download fehl.
  ```bash
  mkdir -p /usr/local/bin
  ```
- **GitHub-Release-Binary für xz funktioniert nicht**: Die URL `https://github.com/tukaani-project/xz/releases/download/v5.6.4/xz-5.6.4-linux-x86_64-static` liefert nur eine 9-Byte-Fehlerseite (404). **Nicht verwenden.** Stattdessen `xz-utils` aus den Debian-Repos installieren.
- **Root-Installation von Nix schlägt fehl mit `group 'nixbld' does not exist`**:
  ```bash
  groupadd -f nixbld && useradd -r -g nixbld -G nixbld -s /usr/sbin/nologin -d /var/empty nix
  ```
- **`nix` nach Installation nicht im PATH**: Neue SSH-Session öffnen oder `. /root/.nix-profile/etc/profile.d/nix.sh` ausführen.
- **`nix build` mit absolutem Pfad zur `configuration.nix` bricht mit `access to absolute path ... is forbidden in pure evaluation mode`**:
  Abhilfe: `nix build --impure ...` verwenden. Ohne `--impure` akzeptiert der Eval-Kontext keine absoluten Pfade aus der Flake, und die Module werden nicht geladen.
- **`nixos-anywhere` auf dem Zielhost selbst ausführen**: Endet in einer Endlosschleife über `ssh-copy-id` (der sich selbst kontaktieren will). Workaround: Lokalen Build mit `nix build --impure` ausführen und danach `switch-to-configuration boot` + `switch` lokal aufrufen. **Keinen Remote-Deploy auf demselben Host erzwingen.**
- **`ssh-copy-id` schlägt mit `Connection reset by peer` / `Permission denied (publickey,password)` fehl**: Ursache ist meistens, dass der Bootstrap-Key des Tools nicht dem vorhandenen SSH-Key des Agenten entspricht oder die Gegenstelle den Login für den neuen Key sofort verwirft. Lokaler Build umgeht das.

### Korrekte Sequenz (vom Nutzer auf der Remote-Konsole auszuführen)

```bash
apt-get update && apt-get install -y xz-utils
groupadd -f nixbld && useradd -r -g nixbld -G nixbld -s /usr/sbin/nologin -d /var/empty nix
sh <(curl -L https://nixos.org/nix/install) --no-daemon
. /root/.nix-profile/etc/profile.d/nix.sh
nix --version
```

Hinweis: Diese Schritte müssen vom Nutzer auf der Remote-Konsole ausgeführt werden. Der Agent kann nur Anweisungen geben, keine interaktiven Logins mit Passwort-Eingabe durchführen.

## Windows-Netzwerkpfade und Unraid-Shares

Der Nutzer referenziert häufig Windows-Pfade wie `Z:\\hermes_knowledge\\...`. Das ist ein auf Unraid gemountetes SMB-Share. Die zugehörige Server-Seite ist:

- Server: `192.168.2.250` (SSH Port `53844`)
- Server-Pfad: `/mnt/user/data/hermes_knowledge/...`
- Lokaler Hermes-Mount: `/opt/data/knowledge/...` (read-only)

**Regel:** Bei `Z:\\hermes_knowledge\\...` sofort zu `/mnt/user/data/hermes_knowledge/...` auf dem Unraid mappen. Nicht lokal im Hermes-Dateibaum suchen.

## Harte Grenze: Remote-Write auf Unraid-Shares aus dieser Session

- Der lokale Hermes-Mount unter `/opt/data/knowledge/` ist **read-only**.
- SSH auf den Unraid-Server (`192.168.2.250:53844`) ist aus dieser Session **nicht möglich**, weil die Auth fehlschlägt.
- Folge: **Löschen, Verschieben oder Schreiben in `Z:\\hermes_knowledge\\...` kann hier nicht ausgeführt werden.**

Wenn der Nutzer so etwas verlangt, direkt sagen: *"Das geht aus dieser Session nicht, weil der Mount read-only ist und ich keinen SSH-Zugang zum Unraid habe."* Dann anbieten, stattdessen lokal in `/opt/data/` zu arbeiten, oder dem Nutzer die nötigen Schritte/Script zum direkten Ausführen auf Unraid zu geben.

## Harte Grenze: Agent hat keinen Remote-SSH-Zugriff

Der Agent kann **keine externen SSH-Verbindungen** zu Nutzer-Hosts aufbauen. Es gibt keinen `ssh mcp server`, keinen Remote-SSH-Client und keinen TTY für interaktive Passwort-Eingaben.

Was das bedeutet:
- Kurze, nicht-interaktive Kommandos auf bereits eingerichteten Keys funktionieren.
- Alle Schritte, die `curl`, `apt`, `nix install`, Tastatureingaben oder Root-Passwörter erfordern, müssen **vom Nutzer lokal auf dem Remote-Host** ausgeführt werden.
- Der Nutzer kopiert die Kommando-Blöcke des Agenten, führt sie aus und schickt die Ausgabe zurück. Der Agent analysiert und steuert dann weiter.

Diese Grenze **niemals** mit "probier doch mal ssh" umgehen — das führt nur zu Frustration wie in dieser Sitzung.
