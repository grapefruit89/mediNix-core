---
id: "ADR-57-backup-data-classification"
title: "ADR 5721 backup data classification and applied strategy"
domain: 57
status: active
complexity: 3
last_reviewed: 2026-08-28
tags:
  - backup
  - storage
  - classification
links:
  adr: "ADR-5721"
  repo-harvest: ""
supersedes: ["5720"]
---
# ADR-5721: Backup — Datenklassifizierung (allgemein) und angewandte Strategie (mediNix)

## Status: active
## Date: 2026-08-28
## Supersedes: ADR-5720 (docs/adr/ADR-57-backup-strategy.md)
## Source: Review zweier fast identischer Konzept-Dokumente (ChatGPT + Grok) zu
"Backup-Strategie nach Datenklassen", plus Grounding-Runde mit den realen
Rahmenbedingungen dieses Hosts (0 €/Monat Cloud-Budget, Koofr-Account bereits im
Einsatz, zweite externe Platte vorhanden).

## Warum dieses ADR zwei Teile hat

Der Nutzer hat ausdrücklich gebeten, sowohl das *allgemeine Wissen* aus der Recherche
festzuhalten als auch klar zu benennen, *welcher Teil davon* tatsächlich auf mediNix
angewendet wird. Beides in einem ADR zu vermischen wäre unehrlich gegenüber künftigen
Lesern (Mensch oder Agent) — deshalb ist Teil 1 Referenzwissen (gilt unabhängig von
diesem Repo), Teil 2 die konkrete Entscheidung für dieses System, Teil 3 explizit das,
was abgelehnt wurde und warum.

---

## Teil 1 — Allgemeines Wissen (Referenz, nicht mediNix-spezifisch)

**Begriff:** Das beschriebene A/B/C-Schema ist "Datenklassifizierung nach Kritikalität"
bzw. "Backup-Tiering" — Standardvokabular in ISO 27001, BSI-Grundschutz (CON.3) und
NIST SP 800-34, die im Kern dasselbe tun: Daten nach Schutzbedarf und
Wiederbeschaffungsaufwand in Klassen einteilen und je Klasse eine eigene RPO/RTO-Zielgröße
und Backup-Topologie festlegen.

**Verfeinerung der drei Grobklassen:**
- **A1** — unersetzlich, keine Quelle zur Wiederbeschaffung (Fotos, Dokumente,
  Passwort-Datenbank, private Kommunikation). Höchster Schutzbedarf, meist niedriges
  Volumen.
- **A2** — wichtig, aber mit Aufwand wiederbeschaffbar (Konfigurationen, Anwendungs-DBs,
  die man manuell neu aufbauen könnte, aber ungern würde).
- **B** — flüchtig, automatisch regenerierbar (Caches, Transcodes, temporäre Downloads).
  Kein Backup nötig.
- **C** — Mediendaten aus öffentlichen/käuflichen Quellen (Filme, Musik, Serien).
  Wiederbeschaffbar, aber mit Zeitaufwand — Backup ist eine Kostenfrage, keine
  Notwendigkeit.

**RPO/RTO:** Recovery Point Objective (wie viel Datenverlust ist tolerierbar) und
Recovery Time Objective (wie schnell muss wiederhergestellt sein) machen eine
Klassifizierung erst operational — ohne sie ist "A1 ist wichtig" nur eine Meinung, kein
Plan. Beide Werte sind pro Anwendungsfall verschieden: ein Firmenserver mit hoher
Schreibfrequenz braucht ein RPO von Minuten, ein privates Fotoarchiv, das sich kaum
ändert, braucht das nicht.

**3-2-1(-1-0)-Regel:** 3 Kopien der Daten, auf 2 verschiedenen Medientypen, davon 1 Kopie
offsite (räumlich getrennt). Die erweiterte Variante 3-2-1-1-0 ergänzt: 1 Kopie
offline/unveränderlich (Schutz vor Ransomware, die auch angeschlossene Backup-Ziele
verschlüsseln kann) und 0 Fehler bei regelmäßigen Restore-Tests (ein ungetestetes Backup
ist eine Vermutung, kein Backup).

**Werkzeuge:** restic und borg sind die zwei relevanten Open-Source-Optionen für
deduplizierte, verschlüsselte Backups. restic hat breitere Backend-Unterstützung (lokal,
SFTP, S3, und über `rclone:`-Repositories praktisch jeden Cloud-Anbieter inkl. WebDAV);
borg ist tendenziell effizienter beim Deduplizieren sehr ähnlicher großer Dateien, hat
aber ein engeres Backend-Set (lokal/SSH).

**Compliance-Rahmenwerke (DSGVO Art. 5/32/17, BSI-Grundschutz, NIS2, GoBD):** regeln
Aufbewahrungs- und Nachweispflichten für Unternehmen und Behörden — Löschfristen,
Dokumentationspflichten, Meldewege bei Datenverlust. Fachlich korrekt, aber Instrumente
für eine andere Zielgruppe.

---

## Teil 2 — Angewandt auf mediNix (die eigentliche Entscheidung)

**Erste Einordnung: was für Daten verwaltet dieses Repo überhaupt?**
mediNix ist ein Media-Server-Stack (Sonarr/Radarr/Prowlarr/Lidarr/Readarr, SABnzbd,
Jellyfin, Audiobookshelf, Navidrome). Es gibt hier keinen Foto-, Dokumenten- oder
Passwortmanager-Dienst — **Klasse A1 (Fotos/Dokumente/Passwort-DB) existiert im Scope
dieses Repos nicht** und wird hier deshalb auch nicht "gebackupt", weil es hier nichts
davon gibt. Das ist eine bewusste Scope-Feststellung, kein vergessener Punkt: falls
A1-Daten auf demselben Host liegen (z.B. ein separat verwalteter Foto-Ordner), gehört
deren Backup NICHT in dieses Flake, sondern in die Host-Konfiguration oder ein eigenes,
dafür angelegtes Modul.

Was mediNix tatsächlich hält:

| Daten | Klasse | Pfad(e) | Aktuelle Behandlung |
|---|---|---|---|
| *arr/Jellyfin/SABnzbd State (SQLite-DBs, API-Keys, Config) | A2 (wichtig, aber neu konfigurierbar) | `mediaStateDirs` (Registry-generiert) + `secrets.secretsDir` | restic, täglich 02:00, DB-Safety-Stop |
| Transcodes/Downloads/Incomplete | B (flüchtig) | `jellyfin-*/transcodes`, `sabnzbd-*/incomplete`, `.../Downloads` | kein Backup — explizit per `--exclude` ausgeschlossen |
| Filme/Serien/Musik/Bücher (Bibliothek) | C (wiederbeschaffbar) | `storage.mediaRoot/media/*` | kein Backup — korrekt nicht in `mediaStateDirs` enthalten |

**Konkrete Entscheidung (umgesetzt in `57-maintenance/576-backup.nix`, `default.nix`):**

1. **Ein Werkzeug: restic**, nicht restic+borg wie in ADR-5720 vorgesehen. Medien
   (Klasse C) werden gar nicht gesichert, also gibt es auch keinen zweiten Job mit
   anderer Kadenz zu verwalten — das reduziert Komplexität, ohne etwas zu verlieren.
2. **3-2-1 statt nur einer Kopie:** Primär-Repository (`maintenance.backup.repository`,
   lokal bzw. zweite externe Platte, täglich, DB-Safety-Stop der neun Media-Dienste) plus
   ein neues, optionales Offsite-Repository (`maintenance.backup.offsite.*`), das per
   `restic copy --from-repo` NACH einem erfolgreichen Primär-Lauf repliziert — kein
   zweiter Service-Stop nötig, da bereits konsistente Snapshots kopiert werden. Ziel:
   Koofr (WebDAV, Account bereits vorhanden) via `rclone:koofr:...`-Repository-Syntax und
   `offsite.rcloneConfigFile`.
3. **0 €/Monat:** Kein Hetzner Storage Box, kein Backblaze B2, kein sonstiger bezahlter
   Cloud-Speicher. Koofr (Bestandsaccount) + zweite externe Platte statt Neuanschaffung.
4. **Passwort Fail-Closed über systemd-creds:** `passwordCredentialPath`
   (LoadCredentialEncrypted) ist jetzt der empfohlene Weg — exakt das Muster aus
   `52-security/525-vpn-interface.nix` (WireGuard-Key), erzeugt über das bereits
   vorhandene `medinix-seal-secret.sh`. Der alte `passwordFile`-Weg bleibt als
   "external"-Fallback bestehen (Tri-State: managed/vorher/host-eigen), damit
   bestehende Host-Configs nicht brechen — Default bleibt unverändert `passwordFile`,
   `passwordCredentialPath` ist opt-in.
5. **Integritätscheck:** neuer wöchentlicher Timer (`mediNix-backup-check`,
   `restic check` auf dem Primär-Repo) mit ntfy-Alarm bei Fehlschlag — vorher gab es gar
   keine automatische Verifikation, nur den (ungetesteten) Anspruch, dass Backups
   funktionieren.
6. **Restore-Tests bleiben manuell.** Das ist der einzige Teil von "0 Fehler bei
   Restore-Tests" (3-2-1-1-0), der hier NICHT automatisiert ist — ein automatischer
   Restore-Test in eine temporäre Umgebung ist ein größeres Stück Arbeit, das eine
   eigene, bewusste Entscheidung verdient statt nebenbei mitgezogen zu werden. Offener
   Punkt, siehe unten.

---

## Teil 3 — Explizit abgelehnt (und warum)

Diese Punkte kamen im Zuge eines "heb das aufs Profi-Niveau"-Prompts in einem der beiden
Ausgangsdokumente dazu und wurden bewusst NICHT übernommen — nicht aus Unwissenheit,
sondern weil sie an der Realität dieses Systems vorbeigehen:

| Vorschlag | Warum abgelehnt |
|---|---|
| RPO 15–60 Min für Klasse A1 | Wurde für Fotos vorgeschlagen, die der Nutzer selbst "fast statisch" nennt. Das ist eine Firmenserver-Anforderung, keine für ein privates Archiv. Und: A1 existiert in mediNix ohnehin nicht (s.o.). |
| Hetzner Storage Box / Backblaze B2 als Offsite | Direkter Widerspruch zu "für Cloud möchte ich im Monat nichts ausgeben". Koofr (Bestand) + zweite Platte erreichen dieselbe 3-2-1-Eigenschaft ohne laufende Kosten. |
| DSGVO Art. 5/32/17, BSI-Grundschutz, NIS2, GoBD | Compliance-Pflichten für Unternehmen/Behörden. Für ein privates Homelab nicht "professioneller", sondern falsch verortet — es gibt keine Aufsichtsbehörde, der dieses System Rechenschaft schuldet. |
| Neue Klasse D ("Archiv") | Für die genannte Größenordnung (persönliche Daten + ein paar Configs) braucht es keine vierte Tier-Stufe — das wäre Komplexität ohne Gegenwert. |
| Borg zusätzlich zu restic für Medien-Dedup (ADR-5720) | Medien (Klasse C) werden gar nicht gesichert — es gibt nichts zu dedupen. Ein zweites Backup-Tool nur für eine Datenklasse, die man ohnehin nicht sichert, wäre reiner Wartungsaufwand. |
| Bare-Metal-Recovery-Stick | Bereits in ADR-5720 abgelehnt (Homelab, kein Prod-System) — Einschätzung bleibt gültig, hier bestätigt. |

**Das Muster dahinter:** Ein wiederholtes "mach das professioneller"-Prompt ohne neue
Fakten führt bei einem Sprachmodell tendenziell dazu, mehr Normen/Frameworks/Fachbegriffe
einzubauen, weil das nach mehr Substanz aussieht — nicht weil es bessere Entscheidungen
für den konkreten Fall produziert. Sprach-/Vokabular-Upgrade ist nicht dasselbe wie
Entscheidungs-Upgrade. Deshalb steht das hier explizit dokumentiert, nicht nur implizit
verworfen.

---

## Offene Punkte (bewusst nicht in diesem ADR gelöst)

1. **`579-backup-ssh.nix` (SSH-Pull-Backup, zweiter Mechanismus):** existierte bereits vor
   diesem ADR, unabhängig von restic. Eine Sicherheitslücke wurde in diesem Zuge behoben
   (Polkit-Regel war blanket `manage-units` für JEDE Unit — nicht nur die Media-Dienste —
   jetzt auf die neun Media-Services eingeschränkt, analog zu `mediaServices` in
   `576-backup.nix`). NICHT behoben: der Dump nach `/tmp/backup-dump` ist unverschlüsselt
   und hat keine sichtbare Aufräum-/Retention-Logik. Ob dieser Pfad überhaupt noch
   gebraucht wird (er dupliziert im Kern, was restic jetzt leistet, nur unverschlüsselt
   und ohne Versionierung) ist eine Entscheidung, die der Nutzer treffen sollte, bevor
   jemand das Modul weiter ändert oder löscht.
2. **Automatisierte Restore-Tests** fehlen (s. Teil 2, Punkt 6).
3. **`mediaServices`-Liste ist dupliziert** zwischen `576-backup.nix` und
   `579-backup-ssh.nix` (Polkit-Whitelist). Ein gemeinsamer Ort (`lib/registry.nix`) wäre
   sauberer, wurde hier aber nicht angefasst, um den Diff auf das Notwendige zu begrenzen.
4. **Keine echte Nix-Evaluation möglich:** weder im Cloud-Workspace noch auf dem
   Zielgerät war `nix`/`nix-instantiate` verfügbar. Verifiziert wurde stattdessen: (a)
   Assertion-/Options-Zählung vor/nach dem Edit (keine Abnahme — `default.nix` +5
   `mkOption`, `576-backup.nix` +3 Assertions, `579-backup-ssh.nix` unverändert), (b)
   Klammer-/Anführungszeichen-Balance aller drei geänderten Dateien. Ein echter
   `nix flake check` bzw. `nixos-rebuild dry-build` auf einem Host mit Nix-Toolchain
   steht noch aus, bevor das als vollständig verifiziert gilt.

## Consequences

- ✅ Klarer Scope: A1 existiert in mediNix nicht, wird auch nicht so behandelt (kein
  falscher Sicherheitsanspruch).
- ✅ 3-2-1 tatsächlich erreichbar (Primär + Offsite via Koofr/zweite Platte), ohne
  laufende Kosten.
- ✅ Passwort-Handling Fail-Closed und konsistent mit dem Rest des Repos
  (systemd-creds statt Klartextdatei), rückwärtskompatibel (Default unverändert).
- ✅ Erstmals eine automatische Integritätsprüfung statt eines ungetesteten Anspruchs.
- ⚠️ Offsite-Replikation und `passwordCredentialPath` sind erst nutzbar, wenn der Host
  die konkreten Werte setzt (Repository-String, `.encrypted`-Datei via
  `medinix-seal-secret.sh`) — das Nix-Modul liefert nur die Struktur, keine
  Host-spezifischen Geheimnisse (ADR-5710-Prinzip).
- ⚠️ Zwei offene Punkte bei `579-backup-ssh.nix` bleiben bestehen (s. Offene Punkte, #1).
