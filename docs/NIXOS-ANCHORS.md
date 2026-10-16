---
id: "nixos-anchors"
title: "NixOS-Anchors - Vokabular mit Belegen"
domain: 50
folder: docs
status: active
complexity: 2
last_reviewed: 2026-10-16
links:
  adr: ADR-0000 (Verfassung), ADR-0002 (Grundfunktionen), ADR-0003 (Manifest)
---

# NixOS-Anchors

**Zweck:** etabliertes Vokabular fuer NixOS-Arbeit. Je Anker: **Details · Kernkonzepte · Wann
nutzen · Missverstaendnisse · Kritik · Status · Quelle · Durchsetzung**.

Der Anker steuert das Denken, die **Messung** liefert die Wahrheit. Unsere Konstrukte sind auf den
vendorten Katalog (`docs/anchors/`, Apache-2.0) gemappt in `docs/TERMINOLOGY.md`; diese Datei ist
das NixOS-spezifische Gegenstueck. Geprueft von `scripts/check_nixos_anchors.py` (Katalog-Lint:
alle Abschnitte vorhanden, Quelle identifizierbar - Jahr, Version, ADR-Bezug oder ausdrueckliches "o. J." -, Status
gesetzt, Durchsetzungs-Angabe zeigt auf eine existierende Datei oder Korridor-Regel).

## A) Was NixOS IST

### 1. Declarative Configuration
- **Details:** Der Zielzustand wird beschrieben, nicht der Weg dorthin.
- **Kernkonzepte:** Optionen statt Befehle · `configuration.nix` als SSoT · idempotente Auswertung.
- **Wann nutzen:** immer - jeder Zustand entsteht aus einer Option.
- **Missverstaendnisse:** "deklarativ" heisst nicht "einfach"; Optionen koennen Fallen haben.
- **Kritik:** Optionen sind nicht entdeckbar wie `--help`; man braucht Suche (`search.nixos.org`, Modul-Code).
- **Status:** Kern von NixOS, etabliert.
- **Quelle:** Dolstra 2006 (Dissertation, Kap. 1-2); NixOS Manual (Configuration).
- **Durchsetzung:** ADR-0002 §1 · `scripts/check_banned_technologies.py`

### 2. Pure Functional Model
- **Details:** Das Deployment-Modell ist eine Funktion: Inputs -> Store-Pfade, ohne Seiteneffekte.
- **Kernkonzepte:** reine Ausdruecke · Faulheit · kein Zustand im Eval · `builtins` statt Shell.
- **Wann nutzen:** beim Bauen von Ableitungen; wenn ein Wert "irgendwoher" kommt.
- **Missverstaendnisse:** "funktional" heisst nicht "keine Skripte" - Build-Skripte sind erlaubt, Eval-Code muss rein bleiben.
- **Kritik:** Fehlermeldungen sind schwer zu lesen, weil Ausdruecke verschachtelt sind.
- **Status:** Kern (Nix-Sprache), etabliert.
- **Quelle:** Dolstra 2004 ("Nix: A Safe and Policy-Free System for Software Deployment"); Dolstra 2006.
- **Durchsetzung:** AB-043 · `scripts/check_banned_technologies.py` (unreine Eval-Quellen) · `scripts/nixos_idiom_audit.py --p0-only`

### 3. Deterministic Builds
- **Details:** Gleicher Input -> gleicher Output; keine Uhrzeit, kein Zufall, kein Netz ohne Pin.
- **Kernkonzepte:** Sandbox · keine Zeitstempel im Ergebnis · Reproducible Builds.
- **Wann nutzen:** bei jeder Ableitung; besonders bei Downloads und Versionen.
- **Missverstaendnisse:** "deterministisch" heisst nicht "bit-identisch" - Reproduzierbarkeit ist die Zusage.
- **Kritik:** Upstream-Quellen (Webinhalte, Git-Branches) brechen die Zusage, wenn nicht gepinnt.
- **Status:** Kern (Flake-Lock), etabliert.
- **Quelle:** Dolstra 2006 (Kap. 3-5); nix.dev (Reproducibility).
- **Durchsetzung:** AB-043 · `scripts/check_banned_technologies.py` (unreine Quellen) · `flake.lock`-Pin

### 4. Reproducible Systems
- **Details:** Ein System ist aus dem Lockfile nachbaubar - auf anderer Hardware oder Jahre spaeter.
- **Kernkonzepte:** `flake.lock` · Input-Pins · Rollback als Teil der Rekonstruierbarkeit.
- **Wann nutzen:** bei Upgrades; bei "laeuft bei mir" auf einem zweiten Rechner.
- **Missverstaendnisse:** Reproduzierbarkeit schuetzt nicht vor Hardware-Unterschieden (GPU-Treiber etc.).
- **Kritik:** Fuer Uneingeweihte wirkt der Lock als "irgendwas Unsichtbares".
- **Status:** etabliert.
- **Quelle:** Dolstra 2006; NixOS Manual (Upgrading NixOS).
- **Durchsetzung:** AB-043 · `flake.lock` (committed) · `nix flake check`

### 5. Atomic Upgrades
- **Details:** Ein Upgrade ist ein Wechsel von Store-Pfaden - ganz oder gar nicht.
- **Kernkonzepte:** Generationen · Profil-Symlink · `switch-to-configuration`.
- **Wann nutzen:** bei jedem Systemwechsel; niemals "halb" upgraden.
- **Missverstaendnisse:** "atomar" heisst nicht "ohne Neustart" - Dienste werden neu gestartet, der Kernel braucht `boot`.
- **Kritik:** Laufende Prozesse koennen alte Pfade weiter benutzen (selten sichtbar).
- **Status:** etabliert.
- **Quelle:** NixOS Manual (Upgrading NixOS); Dolstra 2006 (Profiles/Generations).
- **Durchsetzung:** manuell (Betrieb, `docs/RUNBOOK.md`)

### 6. Rollbacks
- **Details:** Jede vorherige Generation bleibt startbar/waehlbar.
- **Kernkonzepte:** `nixos-rebuild --rollback` · Boot-Eintraege · Profile-Historie.
- **Wann nutzen:** wenn ein Wechsel etwas kaputt macht; Rollback ist die erste Option, nicht der Neubau.
- **Missverstaendnisse:** Ein Rollback der Konfiguration rollt **Daten** nicht zurueck (DBs, State-Dirs).
- **Kritik:** Rollback-Kultur verleitet dazu, Daten-Backups zu vernachlaessigen.
- **Status:** etabliert.
- **Quelle:** NixOS Manual (Rollbacks); Dolstra 2006.
- **Durchsetzung:** manuell · `docs/RUNBOOK.md`

### 7. Immutable Infrastructure
- **Details:** Zielsysteme werden nicht gepatcht, sondern neu erzeugt; das Artefakt ist unveraenderlich.
- **Kernkonzepte:** Store ist read-only · Konfiguration ersetzt statt aendern.
- **Wann nutzen:** als Denkrahmen fuer "soll ich das jetzt schnell auf dem Host fixen?" -> **nein**.
- **Missverstaendnisse:** "immutable" heisst nicht "kein Zustand" - Daten und State-Dirs existieren weiter.
- **Kritik:** Braucht Disziplin bei Daten (Migrationen statt Klick-Reparaturen).
- **Status:** Begriff aus dem DevOps-Umfeld, auf NixOS zutreffend.
- **Quelle:** Fowler 2013 (Bliki: ImmutableServer); NixOS Manual.
- **Durchsetzung:** ADR-0003 §1 (Publish-Don't-Apply) · AB-047

### 8. Content-Addressable Store
- **Details:** Store-Pfade sind Hash des Inhalts (+ Inputs) - gleicher Inhalt, gleicher Pfad.
- **Kernkonzepte:** `/nix/store/<hash>-<name>` · Deduplizierung · Referenzen als Graph.
- **Wann nutzen:** beim Verstehen von "warum liegt das zweimal im Store?" und bei Cache-Fragen.
- **Missverstaendnisse:** Der Hash ist **kein** Pruefsummen-Beweis fuer Reproduzierbarkeit des Upstreams, sondern des Bauprozesses.
- **Kritik:** Pfade sind unleserlich; Debugging erfordert `nix-store -q`.
- **Status:** Kern (Nix), etabliert.
- **Quelle:** Dolstra 2004; Dolstra 2006 (Kap. 5).
- **Durchsetzung:** manuell (Diagnose) · `scripts/nixmeta_check.py` (Header zeigen auf Quellen)

### 9. Dependency Isolation
- **Details:** Jede Ableitung sieht nur ihre deklarierten Abhaengigkeiten - kein globales `/usr/lib`.
- **Kernkonzepte:** Closure · kein impliziter Suchpfad · RPATH-Patching.
- **Wann nutzen:** bei "Programm findet Bibliothek nicht" und bei zweistufigen Bauplaenen.
- **Missverstaendnisse:** Isolation gilt zur **Build**-Zeit; zur Laufzeit kann ein Dienst trotzdem Dateien lesen, die ihm das Sandboxing erlaubt.
- **Kritik:** grosse Closures (mehrere Versionen derselben Lib) kosten Plattenplatz.
- **Status:** Kern, etabliert.
- **Quelle:** Dolstra 2006 (Kap. 5-6).
- **Durchsetzung:** manuell · ADR-0002 §3

### 10. Directed Acyclic Graph (DAG)
- **Details:** Ableitungen bilden einen gerichteten, azyklischen Graphen; Zyklen sind Konstruktionsfehler.
- **Kernkonzepte:** Abhaengigkeiten zeigen in **eine** Richtung (Quelle -> Ableitung) · Fixpunkt-Auswertung.
- **Wann nutzen:** wenn `infinite recursion` auftritt - erst den Graphen zeichnen, dann patchen.
- **Missverstaendnisse:** NixOS-Fixpunkt erlaubt `config`-Zugriffe quer - aber nicht in **einem** Modul gleichzeitig schreiben und lesen.
- **Kritik:** Fehlermeldungen zeigen den Zyklus nicht immer direkt; `--show-trace`/Bisect noetig.
- **Status:** Kern; im Repo konkret gelernt (L-046).
- **Quelle:** Dolstra 2006 (Kap. 4); NixOS Manual (Module/`lib/modules.nix`).
- **Durchsetzung:** AB-040 · AB-042 · ADR-040 · `scripts/check_adrs.py`

## B) Was NixOS NICHT IST

### 11. Imperative Configuration
- **Details:** "Fuehre Befehl X aus, dann ist es gut" - kein NixOS-Modell.
- **Kernkonzepte:** `system.activationScripts` mit imperativem Shell-Inhalt · `nix-channel`/`nix-env -i` als Zustandsquelle.
- **Wann nutzen:** nie - stattdessen Option oder `systemd.tmpfiles`/Unit.
- **Missverstaendnisse:** `activationScripts` sind nicht "verboten", aber sie sind der letzte Ausweg und nicht deklarativ.
- **Kritik:** Manche Upstream-Doku erklaert nur den imperativen Weg.
- **Status:** Anti-Anker (steht fest).
- **Quelle:** NixOS Manual (nixos.org/manual/nixos, Stand 26.11); nix.dev (Anti-Patterns, Stand 2026).
- **Durchsetzung:** `scripts/check_banned_technologies.py` (activationScripts mit imperativem Inhalt, `nix-channel`/`nix-env -i`) · `scripts/nixos_idiom_audit.py --p0-only`

### 12. Mutable State
- **Details:** Zustand, der ausserhalb der Konfiguration lebt und sich unbemerkt aendert.
- **Kernkonzepte:** `users.mutableUsers = true` (imperatives `useradd`) · handgeaenderte Dateien im Store-Pfad-Baum.
- **Wann nutzen:** als bewusste Ausnahme (dokumentiert), nicht als Default.
- **Missverstaendnisse:** State-Dirs (`/var/lib/<dienst>`) sind **erlaubt** - "mutable state" meint Konfigurationszustand.
- **Kritik:** Fuer Secrets/Benutzer ist mutableUsers bequem - deshalb muss die Doku die Alternative nennen (L-047).
- **Status:** Anti-Anker; im Repo Engine-Default `mutableUsers = false`, Host-Ausweg dokumentiert.
- **Quelle:** Dolstra 2006 (Kap. 2); NixOS Manual.
- **Durchsetzung:** `lib/decimal-framework.nix` (mkDefault false) · `medinix.security.loginKeys` · `docs/ADMIN-HANDOFF.md`

### 13. Non-Atomic Upgrades
- **Details:** Upgrade in Teilschritten, die einzeln fehlschlagen koennen.
- **Kernkonzepte:** "erst Paket A, dann B" · Zustand zwischen zwei Schritten.
- **Wann nutzen:** nie; NixOS hat Generationen.
- **Missverstaendnisse:** "`nixos-rebuild switch` kann auch fehlschlagen" - ja, aber dann bleibt die alte Generation aktiv.
- **Kritik:** manche Dienste brauchen Datenmigrationen, die per se schrittweise sind.
- **Status:** Anti-Anker.
- **Quelle:** NixOS Manual (Upgrading NixOS, Stand 26.11).
- **Durchsetzung:** manuell · `docs/RUNBOOK.md`

### 14. Snowflake Server
- **Details:** Ein Server, dessen Zustand durch Handarbeit einmalig geworden ist und nicht nachbaubar.
- **Kernkonzepte:** unaufgezeichnete Aenderungen · "weiss niemand mehr".
- **Wann nutzen:** nie - jede Aenderung gehoert in eine Datei (Flake, ADR, Runbook).
- **Missverstaendnisse:** "nur schnell auf dem Host" ist genau die Ursache.
- **Kritik:** In Notfaellen ist der schnelle Fix verlockend - deshalb Rollback + `docs/RUNBOOK.md` als Antwort.
- **Status:** Anti-Anker.
- **Quelle:** Fowler, Bliki "SnowflakeServer" (martinfowler.com, undatiert/o. J.).
- **Durchsetzung:** ADR-0003 §1/§5 · AB-047 · AB-051

### 15. Dependency Hell
- **Details:** Konflikte zwischen global installierten Versionen.
- **Kernkonzepte:** kein globaler Namensraum · Closures statt Konfliktloesung.
- **Wann nutzen:** als Beschreibung des Problems, das Nix loest - nicht als Ausrede fuer mehrere Versionen **im selben** Closure.
- **Missverstaendnisse:** Nix verhindert auch "parallele Versionen" nicht magisch - es macht sie sichtbar.
- **Kritik:** Closure-Groesse ist der Preis.
- **Status:** Anti-Anker.
- **Quelle:** Dolstra 2006 (Kap. 1, Motivation).
- **Durchsetzung:** manuell · `lib/registry.nix` (eine Quelle fuer Versionen)

### 16. Configuration Drift
- **Details:** Produktion weicht unbemerkt von der Beschreibung ab.
- **Kernkonzepte:** Soll (Flake) vs. Ist (Host) · Drift-Erkennung.
- **Wann nutzen:** als Warnung: jede Handarbeit auf dem Host erzeugt Drift.
- **Missverstaendnisse:** Drift entsteht auch durch **Daten** (Datenbank-Schemata), nicht nur Konfiguration.
- **Kritik:** Drift-Tools sind selbst wieder Systeme, die gepflegt werden wollen.
- **Status:** Anti-Anker; im Repo gibt es dafuer Dienst 577 (Drift-Erkennung).
- **Quelle:** NixOS Manual (Declarative, Stand 26.11); Fowler, Bliki "ConfigurationDrift" (o. J.).
- **Durchsetzung:** `medinix.knownStateDirs` + 577 (Drift) · 578 (Orphan-Cleanup) · AB-051

### 17. Golden Image
- **Details:** Ein vorbereitetes Festplatten-Image als Deployment-Einheit.
- **Kernkonzepte:** Image-Backen · Patch-Zyklen statt Deklaration.
- **Wann nutzen:** nie in diesem Stack - die Deployment-Einheit ist der Flake, nicht ein Image.
- **Missverstaendnisse:** ein "Snapshot" als Rollback ist kein Golden Image (Snapshots sind Generationen).
- **Kritik:** Golden Images sind in VM-Welten manchmal pragmatisch - fuer Bare-Metal-NixOS hier nicht.
- **Status:** Anti-Anker.
- **Quelle:** DevOps-Folklore (o. J.) - Gegenmodell: NixOS Manual (Declarative, Stand 26.11).
- **Durchsetzung:** ADR-0003 §4 · AB-050

### 18. Pet Server
- **Details:** Ein unersetzlicher, einzeln gepflegter Server (Gegenteil: "Cattle").
- **Kernkonzepte:** Nachbaubarkeit ist die Eigenschaft, nicht "nie ausfallen".
- **Wann nutzen:** als Realitaetscheck: dieser Host **ist** ein Pet (Heimserver) - also muss er aus dem Flake nachbaubar sein und Daten-Backups haben.
- **Missverstaendnisse:** "Pet" heisst nicht "schlecht" - es heisst "Backups und Nachbau sind Pflicht".
- **Kritik:** Begriffe aus der Cloud-Welt passen nur halb auf einen Homelab.
- **Status:** Anti-Anker mit Begruendung (Heimserver = Pet, deshalb Backup + Reproduzierbarkeit).
- **Quelle:** Bill Baker 2012 ("Cattle vs Pets", Folklore/OpenStack); NixOS Manual.
- **Durchsetzung:** 576 (Backup-Klassifikation) · AB-051

## C) Anti-Patterns, die wir hier ausschliessen

### 19. Anti-Docker Reflex
- **Details:** Keine Container-Engine, wo native systemd-Units reichen - und keine "Nur weil ich es kenne"-Container.
- **Kernkonzepte:** Container nur mit ADR-Begruendung · Sandboxing via systemd (nicht via Namespace-Stapel).
- **Wann nutzen:** als Antwort, wenn ein Compose-File auftaucht.
- **Missverstaendnisse:** Isolation bekommt man mit systemd (`PrivateTmp`, `RootDirectory`) billiger.
- **Kritik:** Manche Software liefert nur Images - dann ist es eine begruendete Ausnahme, kein Reflex.
- **Status:** verbindlich (Denylist).
- **Quelle:** ADR-5000; `50-core/BANNED_TECHNOLOGIES.md`.
- **Durchsetzung:** AB-017 · AB-050 · `scripts/check_banned_technologies.py`

### 20. No mkForce
- **Details:** `lib.mkForce` ueberschreibt fremde Definitionen - Komponierbarkeit kaputt.
- **Kernkonzepte:** additiv mergen · Tri-State-Grenze · Prioritaeten (`mkDefault`/`mkOptionDefault`).
- **Wann nutzen:** nie als Problemloeser; wenn man es braucht, ist die Architektur falsch.
- **Missverstaendnisse:** `mkDefault` ist **kein** `mkForce` - es erlaubt Ueberschreiben durch den Host.
- **Kritik:** es gibt Grenzfaelle (Test-Configs) - die brauchen einen Kommentar, kein Muster.
- **Status:** verbindlich (Manifest §2).
- **Quelle:** Nixpkgs Manual (Optionen/Prioritaeten); ADR-0003 §2.
- **Durchsetzung:** AB-008 · AB-048 (manuell: Urteilsvermoegen)

### 21. Fail-Closed, not Fail-Open
- **Details:** Lieber Build-Abbruch als unsicherer Default.
- **Kernkonzepte:** `assertion`/`throw` · `lib.mkIf` mit Vollstaendigkeit · keine stillen Fallbacks.
- **Wann nutzen:** bei Secrets, Netz, Storage - ueberall, wo "weiterlaufen" schlimmer ist als "nicht bauen".
- **Missverstaendnisse:** fail-closed heisst nicht "sofort rot"; es heisst "die Regel greift, bevor Schaden entsteht".
- **Kritik:** zu viele Assertions werden unlesbar; deshalb dezentral und mit Begruendung im Text.
- **Status:** verbindlich (Manifest §3, ADR-0002 §4).
- **Quelle:** ADR-5043 (Assertion-Qualitaet); ADR-0003 §3.
- **Durchsetzung:** AB-049 · `scripts/check_adrs.py` · `scripts/check_banned_technologies.py`

### 22. No Silent State
- **Details:** Kein Zustand, den niemand kennt - jede Ablage ist registriert.
- **Kernkonzepte:** `medinix.knownStateDirs` · Orphan-Cleanup · "Drop & Forget" (Modul weg = Reste weg).
- **Wann nutzen:** beim Bauen jedes Moduls mit Daten.
- **Missverstaendnisse:** "registriert" heisst nicht "gesichert" - Backup-Klassifikation ist ein eigener Schritt.
- **Kritik:** Registrierung kostet eine Zeile und wird gern vergessen - deshalb Guardrail/Ratsche.
- **Status:** verbindlich (Manifest §5).
- **Quelle:** ADR-0003 §5.
- **Durchsetzung:** AB-051 · Dienst 577 (Drift) · 578 (Orphan-Cleanup)

### 23. Least Privilege
- **Details:** Jeder Dienst bekommt **nur** die Rechte, die er braucht.
- **Kernkonzepte:** eigene UPG-Identitaet statt geteilter Gruppen · keine `capabilities` ohne Grund · sudo nur whitelisted.
- **Wann nutzen:** bei jedem Dienst und bei jedem `extraGroups`/`AmbientCapabilities`.
- **Missverstaendnisse:** "shared group" ist nicht "least privilege"; `media` als Primaergruppe ist der klassische Fehler.
- **Kritik:** Least Privilege erzeugt mehr Konten/Regeln und damit Pflegeaufwand - der Preis fuer Nachvollziehbarkeit.
- **Status:** verbindlich (ADR-0000 §4/§5, ADR-0003 §1).
- **Quelle:** Saltzer/Schroeder 1975 (Least Privilege, "The Protection of Information in Computer Systems").
- **Durchsetzung:** AB-025 · **AB-052** · `scripts/check_corridor.py` · `scripts/check_banned_technologies.py`

### 24. Defense in Depth
- **Details:** Mehrere unabhaengige Schichten statt einer "perfekten".
- **Kernkonzepte:** Hardening-Profile aus **einer** Quelle · Firewall + Routing + Sandboxing kombiniert.
- **Wann nutzen:** bei Sicherheitsentscheidungen; keine Schicht allein tragen lassen.
- **Missverstaendnisse:** Defense in Depth ist kein Freibrief fuer redundante eigene Daemons (systemd-first gilt weiter).
- **Kritik:** Mehr Schichten = mehr Fehlerquellen; jede muss begruendet sein.
- **Status:** etabliert (Hardening-Baseline).
- **Quelle:** NSA 1999 ("Defense in Depth"); vendorter Anker `docs/anchors/defense-in-depth.md`.
- **Durchsetzung:** AB-009 · ADR-5050 · `lib/hardening-profiles.nix`

### 25. Separation of Concerns
- **Details:** Ein Modul tut **eine** Sache; Abhaengigkeiten zeigen in eine Richtung.
- **Kernkonzepte:** Domänen-Ordner (ADR-0000 §3) · Quelle vs. Ableitung (ADR-040) · Assertions ohne Ableitungs-Zugriff (AB-042).
- **Wann nutzen:** beim Zuschnitt von Modulen und beim Debuggen von Zyklen.
- **Missverstaendnisse:** "eine Datei" heisst nicht automatisch "eine Verantwortung" (Wrapper-Dateien sind ein Beispiel dafuer).
- **Kritik:** zu feine Aufteilung erzeugt Indirektion (Wrapper, die nur importieren).
- **Status:** verbindlich (ADR-0000, ADR-040).
- **Quelle:** Dijkstra 1974 ("On the Role of Scientific Thought", Separation of Concerns).
- **Durchsetzung:** AB-040 · AB-042 · `scripts/check_adrs.py` · `scripts/check_corridor.py`
