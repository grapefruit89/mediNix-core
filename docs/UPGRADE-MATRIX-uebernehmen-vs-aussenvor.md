# Upgrade-Matrix: ÜBERNEHMEN vs. AUSSEN VOR (für mediNix-core)

> **Prämisse:** Wir wollen `mediNix-core` **maßgeblich verbessern** — nicht kosmetisch.
> **Quellen:** die 14 Salvage-Audits unter `/storage/emulated/0/Obsidian/SalvageAudits/mediNix/`
> (Untersuchung des Repos `grapefruit89/mediNix`, Stand 2026-07-30) plus der heutige
> `mediNix-core`-Clone.
> **Ergänzt** das Dokument `ROADMAP-DEZIMALRAHMEN-MIGRATION.md` (dort: der interne
> Engine-Konflikt). Dieses Dokument beantwortet: *Was holen wir rüber, was lassen wir weg?*

---

## 0. Kernerkenntnis

`mediNix` besaß **einen** Motor: `lib/registry.nix` (die eine Tabelle) → `lib/service-factory.nix`
(+ `hardening-profiles.nix`, `memory-policy.nix`) → Module. `mediNix-core` hat diesen Motor
**dupliziert** statt erweitert (`decimal-framework.nix` neben `service-factory.nix`). Das ist
der eigentliche Rückschritt — und die Leitlinie für diese Matrix: **mediNix' Ein-Motor-Architektur
übernehmen, die Zwei-Motor-Spaltung nicht.**

---

## 1. ÜBERNEHMEN

### 1A. Engine / `lib/` (Herzstück)

| # | Was übernehmen | Quelle (Audit → Datei) | Warum | Prio |
|---|---|---|---|---|
| A1 | `registry.nix` als **die eine Tabelle** mit **explizit begründeter Ableitungsgrenze** (Port/UID/Tier/mDNS/Ingress *ableiten*; Unit-Name/`/var/lib/<name>`/DNS-Name *nicht*) | `lib-audit` → `lib/registry.nix:72-323` | „Eine Zahl ersetzt eine Zahl (Gewinn); eine Zahl ersetzt keinen Namen (Verlust)" — verhindert `/var/lib/media-512`-Unsinn | P0 |
| A2 | Factory-**Chamäleon**: `harden = if enforce then lib.mkForce else lib.mkDefault` | `lib-audit` → `service-factory.nix:37` | Portabilität: Host gewinnt bei `mkDefault`. Ersetzt die 26× `mkForce` des Altstands | P0 |
| A3 | `SystemCallErrorNumber = "EPERM"` als **Servernorm** | `lib-audit`/`52` → Factory `node`-Profil, L4 | Verhindert stillen **SIGSYS-Tod** bei seccomp-Filter | P0 |
| A4 | `memory-policy.nix`: **OOM-/Weight-Leiter**, `CPUWeight` (nicht `CPUQuota`), `high75`, `forceOom` für postgres(−800)/pocketId(−900), skaliert aus `ramGB` | `lib-audit` → `lib/memory-policy.nix:34-211` | Eine Zahl skaliert alles; CPUQuota verschenkt Leerlauf | P0 |
| A5 | **Peer-Isolation** (`InaccessiblePaths` fremder State-Dirs, `-`-Präfix) + **MediaCover-Offload** (`BindPaths`, state≠cache) | `lib-audit`/`53` → factory | Fremde State-Dirs unsichtbar; Artwork aufs schnelle Pool | P0 |
| A6 | `lib/gpu.nix` **Vendor-Abstraktion** (intel/amd/nvidia/none) mit ehrlicher Grenze „Nix kann HW zur Bauzeit nicht abfragen" | `lib-audit` → `lib/gpu.nix:22-151` | Eine Option → Geräte, Pakete, Gruppen, ffmpeg-Methode; kein stiller CPU-Fallback | P0 |
| A7 | `rebuild-guard.nix` (Sentinel `/run/nixos/rebuild-in-progress` + `ConditionPathExists = "!…"`) | `lib-audit` → `rebuild-guard.nix:10-14` | Verhindert Path-Unit-Trigger (Transcode-Cleanup/VPN-Verify) **während** `nixos-rebuild` | P1 |
| A8 | `network-cidrs.nix` (loopback+RFC1918) als eine Quelle für `IPAddressAllow` | `lib-audit` → `network-cidrs.nix:15-27` | Kein CIDR-Wissen mehrfach schreiben | P1 |
| A9 | `dns.nix` als **reine Funktion, ohne IPs/Domain/Provider**; `nameOf` erlaubt Hostname ≠ Servicename | `lib-audit` → `dns.nix:21-57` | Trennt Namensmodell (Core) von konkreter Domain (Host) | P2 |

### 1B. CI-Ratsche (Compile-Time-Beweise)

| # | Was übernehmen | Quelle | Warum | Prio |
|---|---|---|---|---|
| B1 | **Zweiter Riegel** `ports-verdrahtet`: vergleicht **effektive NixOS-Optionen** (`c.services.sonarr.settings.server.port` …) gegen `reg.ports.*` | `00-root-audit` → `flake.nix:144-173` | decimalFrameworkCheck prüft nur Zahlen; erst das prüft die **Verdrahtung** bis in nixpkgs | P0 |
| B2 | **`nixosTest`-Boot-Test** end-to-end (Kette Registry→Port→UID): `wait_for_unit`, `wait_for_open_port`, `id -u`, `getent group media` | `00-root`/`checks` → `flake.nix:177-199` | `nix build` beweist Syntax, **nicht** Laufzeit (3 reale Fehler waren runtime) | P0 |
| B3 | Zwei-Stufen-Checks `minimal-host` (Eval) + `full-host` (voller `toplevel`) | `checks-audit` → `checks/*.nix` | Dienst-spezifischer Build-Fehler bricht CI statt erst den Switch | P1 |
| B4 | Beispiel **Negativ-Test** („kaputte Konfiguration muss brechen") | `checks-audit` §4 | Assertions selbst testen | P2 |

### 1C. Ingress & Security (die „£-Fehler")

| # | Was übernehmen | Quelle | Warum | Prio |
|---|---|---|---|---|
| C1 | **Caddy-OOM-Schutz**: `MemoryMin=64M`, `MemoryLow=128M`, `MemoryMax=768M`, `OOMScoreAdjust=-500` **und** `ManagedOOMPreference="avoid"` | `51-zugang` → `511-caddy.nix:320-360` | `OOMScoreAdjust` allein schützt **nicht** — `systemd-oomd` ist ein **zweiter Killer**; `MemoryMax` ist Obergrenze, keine Zusicherung. **Höchster Einzelwert in 51.** | P0 |
| C2 | Kill-Switch (522): nftables **`type route`**-Marking + Policy-Routing (`ip rule fwmark`→`table`) + **fail-closed Drop** (`family=inet`, v4+v6) + privates `resolv.conf` (`BindReadOnlyPaths`) + 8 Assertions („Identität = Firewall-Adresse") | `52-sicherheit` → `522-killswitch.nix` | Naive Mark-in-Filter-Chain leakt; `type route` ist zwingend; DNS-Leak ist der häufigste Leak | P0 |
| C3 | **Leak-Verify** (`operstate`-Sonderfall WireGuard, IP-**Vergleich** Host vs. Usenet, Dienste stoppen bei Leak) | `52-sicherheit` → `521:28-141` | Unabhängig vom (toten) netns wertvoll als periodischer Egress-Check | P1 |
| C4 | `RestrictNetworkInterfaces = [ "lo" iface ]` als **zweite Verteidigungslinie** | `52-sicherheit` → `521:143-157` | Schutz routing-unabhängig: echte Dichtheit statt „Routing-Trick" | P1 |
| C5 | Ingress-**Mengenableitung** aus `registry.uiServices` (SPA `static` via `try_files`+`file_server`, kein Proxy) | `51-zugang` → `511:55-82,138-142` | Handgepflegte vHost-Liste driftet; SPA-Deep-Links 404 ohne `try_files` | P1 |
| C6 | `forward_auth`-Muster: Upstream **ohne Pfad** + `uri` + `copy_headers`; separater `@skip`-Zweig | `51-zugang` → `511:92-201` | Reeller Bug 2026-07-15; falsch gebaut = „Domain kaputt, .local geht" | P1 |
| C7 | mDNS Publikation mit **Erfolgsprüfung** (`publish.userServices=true`; LAN-IP via `ip route get 1.1.1.1`; nach 2 s `kill -0`, sonst `exit 1`) | `51-zugang` → `512-mdns.nix:39-109` | **Scheinerfolg-Falle** (L1): Dienst meldet `exit 0`, publiziert aber nichts | P1 |
| C8 | DDNS: `LoadCredentialEncrypted` + LAN-IP per **Kernel-Routing** (kein hartcodiertes Subnetz) + Assertion „genau eine Token-Quelle" | `51-zugang` → `513-ddns.nix:67-126` | Zero-Trust-Cred; hardware-/subnetz-agnostisch | P2 |

### 1D. Media / Services (der 551-Goldstandard)

| # | Was übernehmen | Quelle | Warum | Prio |
|---|---|---|---|---|
| D1 | **Config-Seeds erst nach** `data/jellyfin.db` (`preStart` early-exit; idempotent; `install` ohne `-o/-g` = kein CAP_CHOWN) | `55-wiedergabe` → `551:123-191` | **L7:** Pre-Seeding lässt Jellyfin gegen nicht existente DB migrieren → Endlos-Neustart (`no such table: ActivityLog`) | P0 |
| D2 | **tmpfs-Transcode** + **RAM-adaptives Cleanup** (`/proc/meminfo`-Stufen, `TriggerLimitBurst`, `rebuildGuard`, `ExecStopPost`) | `55-wiedergabe` → `551:94-256` | SSD-Schonung **ohne** Vollaufen des tmpfs; Trigger-Stürme verhindert | P0 |
| D3 | **Egress-Lock** `IPAddressDeny=any` + `IPAddressAllow=<trustedPrivate+loopback>` + `RestrictAddressFamilies` | `55-wiedergabe` → `551:289-322` | Dienst nur auf privaten Adressen, kein WAN-Egress | P0 |
| D4 | **Hardware/Codec-Seeds** Gen9 (UHD 630): `intel-media-driver`, `vpl-gpu-rt`, `LIBVA_DRIVER_NAME=iHD`, LP-H264/HEVC, HevcRext aus, Trickplay QuickSync | `55-wiedergabe` → `551:258-287` | Erfahrungswissen, das eine grüne Wiese nicht hat | P1 |
| D5 | **tmpfiles-Reihenfolge**: Elternverzeichnis **zuerst**, Eigentümer **explizit** (sonst `root:root`) | `53-beschaffung`/`50-core` → L2/L5 | „AppFolder not writable" / `226/NAMESPACE`; Frische-Install-Falle | P0 |
| D6 | **`.dotnet`-Profil**: moderater `SystemCallFilter`, **kein** `MemoryDenyWriteExecute` (JIT braucht W+X) | `53-beschaffung` → `53:127-149` | `.NET` sonst reproduzierbar gebrochen | P0 |
| D7 | **WAL-Pragma-`ExecStartPre`** für SQLite-Apps (Seerr) | `56-anfragen` → `561:45-55` | `PRAGMA journal_mode=WAL` → weniger `database is locked`/Korruption | P1 |
| D8 | **On-Demand Socket-Aktivierung** (`systemd-socket-proxyd`, `internalOffset`, `mkIdleStop`) | `53-beschaffung`/`lib` → `on-demand-http.nix` | Selten genutzte Dienste sparen dauerhaft RAM ohne Erreichbarkeitsverlust | P1 |

### 1E. Ops / Provisioning / Scripts

| # | Was übernehmen | Quelle | Warum | Prio |
|---|---|---|---|---|
| E1 | `provision-unit.nix`: **eine** Härtungsstelle für 8 Units + Trennung „Kern deklarativ / Provisionierung opt-in (Default aus)" | `57-pflege` → ADR-5037/5035 | 8 getrennte Units statt Über-Skript; systemd besitzt die Orchestrierung | P1 |
| E2 | Idempotenter **per-Service-Key-Generator** (`[ ! -f ]`, korrekter Env-Var `…__AUTH__APIKEY`, `chmod 600`) | `53-beschaffung` → `secrets-generator.nix` | Rebuild darf Keys **nicht** rotieren (sonst 401) | P1 |
| E3 | **Exportarr-Muster**: `DynamicUser` + `LoadCredential` + `ExecCondition` Key-Validator (selbst-deaktivierend) | `57-pflege` → `573-exportarr.nix` | Zero-Trust-Cred, `/proc`-sicher, crasht nicht ohne Key | P1 |
| E4 | `arr-provision`: **stdlib-only**, Secrets **nur als Dateipfade** (`read_key_file`), `.tests` in CI verdrahtet | `packages` → `common.py`, `default.nix:53` | Kleiner Closure, reproduzierbar, `/proc`-sicher | P2 |
| E5 | `scripts/`: `migrate-uids.sh` (**check/apply**), `vpn-killswitch-test.sh` (**realer Leak-Test**), `gen-ports-doc.sh` (Registry→Doku), `install-hooks.sh` (schnell) | `scripts` → alle vier | Einmalige UID-Migration sicher; Leak-Test = „der reine Laufzeitfakt"; Doku kann nicht lügen | P1 |
| E6 | „Never blind POST" + `/schema`+`/test`-Muster + Quell-URLs als Architektur | `50-core`/`packages` → `api-reference.md`, `common.py:4-25` | Hartcodierte Feldnamen brechen erst Wochen später | P2 |

### 1F. Doku / Governance

| # | Was übernehmen | Quelle | Warum | Prio |
|---|---|---|---|---|
| F1 | **`LEARNINGS.md` (L1–L7) + `RUNBOOK.md` mit maschinenlesbarem `error_pattern`** | `50-core` → beide | Fehler→Ursache-Landkarte, die grüne Wiesen nie haben; agent-greppbar | P1 |
| F2 | **ADR-5040 (Härtung Modul vs. Host)** inkl. Liste der *abgelehnten* Härtungen mit Befund | `50-core` → `adr/5040` | Verhindert Übergriffe; die Ablehnungsliste ist wertvoller als die Zustimmung | P1 |
| F3 | Auto-Import (Ordner→Modul), keine Handimport-Liste | `00-root` → `default.nix:67-73` | Neuer Dienst = ein Ordner, keine 7 Einträge | (hat mediNix-core schon) |
| F4 | `PORTS.md` aus Registry **generiert** | `50-core`/`scripts` | Einzige Doku, die strukturell nicht driftet | P2 |

---

## 2. AUSSEN VOR (bewusst NICHT übernehmen)

### 2A. Deprecatete Konzepte — nicht zurückholen
| # | Was | Quelle | Grund |
|---|---|---|---|
| N1 | **netns-Usenet-Confinement** (521) | `52-sicherheit` | Von ADR-5220 abgelöst; bricht direkte LAN-Erreichbarkeit (socat/veth-Frickelei), confinet zu breit. **Nur** den Leak-Verify (C3) herauslösen. |
| N2 | `lib.recursiveUpdate sandboxAttrs` | `52-sicherheit` → `521:241-250` | Fragil (überschreibt später `ExecStartPre` kommentarlos); `lib.mkMerge` nutzen |
| N3 | Double-`status`-Frontmatter (`deprecated` **und** `active`) | `52`/`521:3-5` | Copy-Paste-Rest |

### 2B. Anti-Patterns — nicht kopieren
| # | Was | Quelle | Grund |
|---|---|---|---|
| N4 | **`mkForce`-Orgie** (26×) in Modulen | `lib-audit`, `59-leitplanken` | MANIFEST §2 verbietet; Chamäleon (`mkDefault`) ist die Lösung |
| N5 | **Handgepflegte Listen**, die widersprechen der Ableitung (`591` `uiServices`; `513` `enabledServices`) | `59`/`51` | Drift-anfällig; aus Registry **ableiten** |
| N6 | **Inline-Hardening** statt Fabrik (SAB `541:60-77`) | `54-transfer` | Zweiter Ort für Hardening-Policy; vereinheitlichen |
| N7 | **`on-demand-http.nix` „alles mkForce"-Block ohne Kommentar** | `lib-audit` | Sieht nach Rückbau aus; nur mit Kommentar übernehmen (Sidecar-Ausnahme) |
| N8 | **Provisionierungs-Units als root ohne Sandbox** | `57-pflege`/`packages` | Bewusster Follow-up, aber **nicht** so übernehmen — härten |
| N9 | **Gebrochene Schalter** `573 exporters.enable` („erzeugt weder Units noch Ports") | `57-pflege` → Status.md | Nicht als fertig melden/kopieren |
| N10 | Toter Code: `_ARR_SERVICES` (py), tote `recyclarr.quality/*`-Optionen | `packages`/`53` | Aufräumen, nicht mitnehmen |

### 2C. Doku-Drift — nachziehen, nicht erben
| # | Was | Quelle | Grund |
|---|---|---|---|
| N11 | Alte Nummerierung (Caddy 501, Jellyfin 541/8096, SAB 5210/5007) in `STATUS.md`, div. `CLAUDE.md`, Modul-Headern | `50/51/53/54/55/57/checks` | Entstand **vor** ADR-5043; konsistent falsch. Ziel: aus Registry generieren (F4) |
| N12 | `591:98` prüft `cfg.ingress.auth.upstream` (Option existiert nicht → Assertion greift ins Leere) | `59-leitplanken` | **Echter Bug**; auf `forwardAuthUpstream` nachziehen — Bug **nicht** kopieren |
| N13 | `lib/CLAUDE.md` „UID = 5000 + Rest" vs. korrekt „Nummer×10" | `lib-audit` | Widerspruch in derselben Datei |
| N14 | `common.py` Pfad `../../docs/api-reference.md` (verschoben) | `packages` | Nachziehen |

### 2D. Bewusst HOST-Level (nicht in den Core)
| # | Was | Ziel | Grund |
|---|---|---|---|
| H1 | Konkrete IPs/Domain/Cloudflare/DDNS-Keys, `vpn.interface`-Wert | **nix-hermes** | Modul kennt keine IPs (ADR-5040/5115) |
| H2 | `allowUnfreePredicate` (unrar) | **nix-hermes** | Lizenzentscheidung des Betreibers |
| H3 | `wireFixedUids` **`chown`/`usermod`-Migration** (`migrate-uids.sh`) | **nix-hermes** | Dateisystem-/Useränderung am konkreten Host |
| H4 | `compat-my.nix` (my.*→Modul-Adapter) | **nix-hermes** | Nur für Nix-Grok-Importe; nicht portabel |
| H5 | Kernel-Sysctls/Firewall/journald/SSH | **nix-hermes** | Host besitzt diese (ADR-5040) |
| H6 | `50-core/archiv/` (K2/K4/H4.2-Verweise) | Core, aber **isoliert** | Nie löschen (Code-Kommentare verweisen darauf), nur nicht darauf bauen |
| H7 | Physical GPU-Wahl (`enableQuickSync`/`renderDevice`-Wert) | **nix-hermes** | Hardware-Wissen |

### 2E. Nicht-belegte Behauptungen — nicht übernehmen
| # | Was | Quelle | Grund |
|---|---|---|---|
| U1 | `jellyfin_setup.py:333` „fehlender Import" | `packages-audit` | Audit widerspricht sich selbst (Exec-Summary sagt Bug, §5 findet **keinen**). Erst mit `python -c import` prüfen, dann urteilen |
| U2 | `read -r _` im Killswitch-Test als „fertig" | `scripts` | Bewusst **manuell**; für Automatisierung erst in `nixosTest` gießen |

---

## 3. Umsetzungsreihenfolge

**P0 (Richtung + Sicherheit):** A1–A6, B1–B2, C1–C2, D1–D3, D5–D6.
**P1:** A7–A8, B3, C3–C7, D4, D7–D8, E1–E3, E5, F1–F2.
**P2:** A9, B4, C8, E4, E6, F4, alle N*/H*-Aufräumarbeiten.

**Führung durch die Datei:** Erst die Engine vereinheitlichen (Doc 1 §1 + hier A1–A6), **dann**
C1/C2/D1–D3 (die teuer bezahlten Runtime-Fehler), **dann** CI-Ratsche B1/B2 — sonst fehlt der
Beweis, dass die Migration trägt.

---

## 4. Bezug

- Doc 1: `ROADMAP-DEZIMALRAHMEN-MIGRATION.md` — *was im aktuellen mediNix-core selbst kaputt/doppelt ist.*
- Doc 2 (dieses): *was aus `mediNix` das Core maßgeblich besser macht (übernehmen) und was bewusst draußen bleibt.*
- Quellen: `/storage/emulated/0/Obsidian/SalvageAudits/mediNix/*-SALVAGE-AUDIT.md` (14 Dateien).
