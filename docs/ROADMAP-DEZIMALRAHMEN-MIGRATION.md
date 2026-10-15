# ROADMAP — Dezimalrahmen-Migration (Altstand → ADR-0000)

> Erstellt aus dem heutigen Stand des Clones (`main`, 2026-10-14) und dem Altstand
> im Export `/storage/emulated/0/Download/grapefruit89-medinix-core-8a5edab282632443.txt` (2026-09-25).
> Zweck: **Was vom Altstand ist gut und noch NICHT in den neuen Stand überführt? Was muss raus?**
>
> **Verifikations-Caveat:** Alle Befunde sind Quelltext-Analyse (file:line). Es lief **kein**
> `nix` / `nix flake check` — der Beweis „bricht die Evaluation" ist eine begründete Ableitung
> aus dem Modulsystem, kein Lauf. Vor dem nächsten Deploy: `nix flake check`.

---

## 0. Kernbefund in einem Satz

Der Dezimalrahmen (ADR-0000) ist **die richtige Richtung**, aber aktuell existieren **zwei
Engines nebeneinander**, die **dieselben Optionen mit widersprüchlichen Werten** schreiben —
und die **neue Engine hat die wertvollen Härtungs-Bausteine des Altstands noch nicht**.

| | NEU (ADR-0000) | ALT |
|---|---|---|
| Verfassung/Logik | `docs/adr/ADR-0000-…`, `lib/decimal-framework.nix` (via `50-core/501-decimal-engine.nix`) | — |
| Datenvertrag | `lib/service-contract.nix` (`options.medinix.manifest.<svc>`) | `lib/registry.nix` (Tabelle) |
| Generator | — (nur Defaults + `users.*`) | `lib/service-factory.nix` (`mkService`) |
| Härtung | **fehlt** | `lib/hardening-profiles.nix`, `lib/memory-policy.nix` |
| Credentials | **fehlt** | `LoadCredentialEncrypted` (TPM) in vielen Modulen |
| stateDir | `/var/lib/<name>` | `/var/lib/<name>-<port>` |

---

## 1. P0 — Harte Blockade: der Selbstwiderspruch (zuerst beheben)

Beide Lager erzeugen **dieselbe Option `users.users.<dienst>`** mit **verschiedenen Werten**:

- `lib/decimal-framework.nix:181-186` → `users.users.<name> = { uid; group = name; home = "/var/lib/<name>"; … }`
- `55-playback/551-jellyfin.nix:155-164` → `users.users.jellyfin = { uid; group = "media"; home = stateDir; … }`

`group`: `"jellyfin"` vs `"media"`; `home`: `/var/lib/jellyfin` vs `/var/lib/jellyfin-5510`.
NixOS-Optionstypen (`str`) verwenden `mergeEqualOption` → **ungleiche Werte = harter
Evaluationsfehler** („conflicting definition values"). Betrifft jeden Dienst, den beide Seiten
berühren (551/552/553, 512, 532–536, 581/582 …).

**Zusatzwiderspruch:** `59-guardrails/591-cross-domain.nix:86-88` **fordert** `group == "media"` —
also gegen die UPG der Verfassung (§4: `primaryGid = uid = num×10`, `media` nur *supplementary*).

**Konsequenz:** `users.users.<svc>` braucht **genau einen Eigentümer** (Engine **oder**
Factory/Module), nicht beide. Das ist die erste Aufgabe.

---

## 2. VOM ALTSTAND ÜBERNEHMEN (gut, noch nicht im neuen Stand)

Priorität absteigend. „Status NEU" = ist das im `decimal-framework.nix` vorhanden?

### 🔴 P0 — systemd-creds / TPM (`LoadCredentialEncrypted`) — *vom User als absolut wichtig markiert*
- **Im Altstand (11+ Stellen):** `513-cloudflare-dns.nix:116`, `514-acme.nix:123`,
  `525-vpn-interface.nix:75`, `532-536` (arr-API-Keys), `541-sabnzbd.nix:272`,
  `551-jellyfin.nix:230`, `553-navidrome.nix:184`, `572-recyclarr.nix:216`,
  `574-provisioning.nix:151`, `576-backup.nix:167/181/201`; Options-Felder in `default.nix`
  (`passwordCredentialPath`, `privateKeyCredentialPath`, `acmeCredential`, `cloudflareTokenCredential`).
- **Status NEU:** `decimal-framework.nix` hat **null** Credential-Bezug (Grep 0 Treffer).
- **Übernehmen:** Die Engine muss erstklassiges Credential-Konzept bekommen — `LoadCredentialEncrypted`
  als Manifest-Feld (z. B. `meta.credentials = [ "sonarr-api-key:<credPath>" ]`), plus die
  Fail-Closed-Regel: „Dienst mit Secret, aber ohne Credential-Pfad ⇒ Build-Fehler".

### 🔴 P0 — Hardening-Profile (`lib/hardening-profiles.nix`)
- **Altstand:** zentrale `serviceConfig`-Profile (`base`, `network`, `script`, `python`, `nodejs`,
  `dotnet`, `dotnet-gpu`, …) mit `SystemCallErrorNumber=EPERM`, `CapabilityBoundingSet`,
  `ProtectSystem`, `RestrictAddressFamilies`, `MemoryDenyWriteExecute` usw.
- **Status NEU:** Engine setzt nur `User/Group/UMask/StateDirectory/StateDirectoryMode/WorkingDirectory`.
- **Übernehmen:** Engine soll pro Zustand ein Profil aufrufen (oder `service-factory` als Unit-Body nutzen).

### 🔴 P0 — Memory- & OOM-Policy (`lib/memory-policy.nix`)
- **Altstand:** pro Dienst `MemoryMax`/`MemoryHigh`/`OOMScoreAdjust` (z. B. Jellyfin 4–6G, Postgres-Schutz, ntfy zuerst OOM).
- **Status NEU:** keine Memory/OOM-Attribute.
- **Übernehmen:** Manifest-Feld `meta.memory = { max; oomScore; }` → Engine injiziert.

### 🟠 P1 — Deep-Sandbox-Muster (Benchmark §3)
- **Altstand/Goldstandard `551-jellyfin.nix:206-234`:** `TemporaryFileSystem = "/transcode:size=4G"`
  (RAM-Transcode), `InaccessiblePaths = [ "-${creds.storeDir}" ]`, `BindReadOnlyPaths`,
  `RuntimeDirectory`, `CacheDirectory`.
- **Übernehmen:** Engine-Fähigkeit: RAM-Disks (`TemporaryFileSystem`), `InaccessiblePaths`,
  `BindReadOnlyPaths` — als Manifest/Profil-Bausteine.

### 🟠 P1 — Peer-Isolation (`service-factory.nix:29-48`)
- **Altstand:** `mkPeerIsolation` → fremde State-Dirs via `-`-präfix `InaccessiblePaths` (mit
  Kommentar zum `226/NAMESPACE`-Fehler). Sehr wertvoll, rein engine-seitig.
- **Übernehmen:** in die Engine.

### 🟠 P1 — RAM-Tempfs / MediaCover-Offload (`service-factory.nix:91-93,134-138,149-152`)
- **Altstand:** `BindPaths` State→Cache, `tmpfiles` mit „Parent zuerst" (L2-Regel), RAM-Temp für SAB.
- **Übernehmen:** Engine-Bausteine „state≠cache" + tmpfiles-Reihenfolge.

### 🟠 P1 — First-Boot-/DB-Marker-Guard (`551-jellyfin.nix:185-205`)
- **Altstand:** `preStart` seedet Configs **erst**, wenn `data/jellyfin.db` existiert (L7 — sonst
  Endlos-Migration). 
- **Übernehmen:** als generisches Manifest-Feld `meta.seedAfterMarker = "<path>"`.

### 🟡 P2 — Domain-Fail-Closed-Assertions mit `[AI/Admin Context]` (MANIFEST §3)
- **Altstand:** `551` erzwingt Admin-Cred **und** RAM-Transcode **und** `JELLYFIN_TRANSCODE_DIR`;
  `512` Deadlock-Schutz; `511` CIDR-Fail-Closed.
- **Status NEU:** Engine prüft nur I1–I4 (Nummernbereich) — **keine** fachlichen Invarianten.
- **Übernehmen:** Engine um Manifest-getriebene Assertions erweitern (oder Module behalten).

### 🟡 P2 — Capability-Whitelist (schon gut!)
- Engine HAT `allowedCapabilities = [CAP_NET_BIND_SERVICE, CAP_NET_RAW]` (ADR §4). ✅ Behalten.
  Lücke: `58-observability/583-…:119` nutzt `CAP_NET_ADMIN` außerhalb der Whitelist unentdeckt.

---

## 3. MUSS RAUS (schlecht — aus Alt *und* Neu)

| # | Was | Beleg | Grund |
|---|-----|-------|-------|
| 1 | Doppel-Eigentum `users.users.<svc>` (Engine + Module/Factory) | `decimal-framework.nix:181` vs `551:155` | Harter Eval-Konflikt (P0 §1) |
| 2 | `gid = 5000` als **Primary** + Assertion `group=="media"` | `registry.nix:16`, `591:88` | Widerspricht ADR-0000 §4 (UPG primary, media *supplementary*) |
| 3 | Port-suffizierte StateDirs `<name>-<port>` | `registry.nix:17`, `service-contract.nix:294` | Von ADR-0000 §9 **explizit verworfen** |
| 4 | `registry.nix` als **dritte** Parallel-Wahrheit | `registry.nix`, `default.nix:823-830` | SSoT-Verstoß — Manifest `num` ist die Wahrheit |
| 5 | Tautologische „Identitätsprüfung" | `service-contract.nix:372-375` | `port==num*10` ist immer wahr (Werte *sind* so definiert) → prüft nichts. Ersetzen: prüfen, dass systemd/User die Ableitung **benutzen**. |
| 6 | `mkForce` trotz MANIFEST §2 | `500-host-baseline.nix:116`, `541-sabnzbd.nix:265-266` | Verboten; „wenn mkForce nötig → Architektur falsch" |
| 7 | Podman/OCI-Widerspruch | `55x-service.example.nix:9-12` + `500-host-baseline.nix:73` („Podman ok") vs `591:153-154` (Docker **und** Podman verboten), MANIFEST §4 | Inkonsistent — OCI ist zu 100 % verboten |
| 8 | `config.decimalFramework.manifest` wird gelesen, aber nie definiert | `decimal-framework.nix:81` | Toter Pfad; nur `medinix.manifest` existiert → verwirrende Namensdoppelung |
| 9 | Engine-Defaults mit `lib.mkOptionDefault` (Priorität 1500) | `decimal-framework.nix:197-202` | Schwächste Priorität → die Engine kann systemd-Werte faktisch nie durchsetzen; wirkt halbherzig |
| 10 | Ordner→Rollen-Isomorphie nicht erzwungen | `flake.nix:72-99` prüft nur „führende Ziffer == 5" | ADR-0000 §2/§3 (Dekaden-Rolle _0.._9) wird von keiner Assertion geprüft |
| 11 | Hartkodierte Ports/UIDs in Modulen (statt `inherit (meta)`) | div. Module | SSoT-Verstoß (Registry/Manifest ist Wahrheit) |

---

## 4. MIGRATIONSPLAN (Reihenfolge)

**Schritt 1 — Konflikt auflösen (P0).** Entscheiden: *wer* besitzt `users.users.<svc>`?
- **Empfehlung:** Engine besitzt sie (Manifest-getrieben), per-service-`users.users.*`-Blöcke
  (551/552/553/512/… ) und die Factory-User-Erzeugung entfernen. UPG + `media` als
  `SupplementaryGroups` gemäß ADR §4; `591:88` von „group==media" auf „SupplementaryGroups
  enthält media" umstellen.

**Schritt 2 — Credentials (P0, dein Top-Punkt).** Manifest-Feld `credentials` → Engine
injiziert `LoadCredentialEncrypted`; Fail-Closed-Assertion „Secret ohne Cred *⇒* throw".
Alle `LoadCredentialEncrypted`-Stellen (§2) darauf umziehen.

**Schritt 3 — Härtung & Resources (P0/P1).** `hardening-profiles.nix` + `memory-policy.nix`
in die Engine einbinden (oder Engine → `service-factory` delegieren). RAM-Tempfs,
`InaccessiblePaths`, Peer-Isolation, BindPaths, `<name>` (owner) / `media` (supplementary).

**Schritt 4 — stateDir & Registry (P1).** `stateDir = /var/lib/<name>` überall (ADR §9);
`registry.nix` aus `medinix.manifest` generieren (oder löschen) — keine dritte Wahrheit.

**Schritt 5 — Assertions (P1/P2).** Fachliche Fail-Closed-Assertions (Jellyfin-Cred,
Transcode-RAM, Ingress-CIDR) zurückholen; tautologische Prüfung (#3.5) ersetzen; Ordner-Rolle
prüfen (#3.10).

**Schritt 6 — Aufräumen (P2).** `mkForce` raus (#3.6), Podman/OCI-Widerspruch auflösen (#3.7),
`decimalFramework.manifest`-Totpfad entfernen (#3.8), Engine-Prioritäten bewusst setzen (#3.9).

---

## 5. VERIFIKATION (nach jedem Schritt)

```bash
cd /etc/nixos   # bzw. Clone
nix flake check                 # fängt Konflikte + Assertions
nixos-rebuild dry-build --flake .#check
# Konflikt-Schnelltest (ohne vollen Build):
nix eval .#nixosConfigurations.check.config.users.users --apply builtins.attrNames
```

---

## 6. OFFENE ENTSCHEIDUNGEN (User)

1. **UPG vs. `gid=5000`-primary:** ADR-0000 §4 (UPG) vs. gelebte Realität (`media`-primary,
   Unraid-Kompatibilität?). Das entscheidet Schritt 1.
2. **stateDir:** `/var/lib/<name>` (ADR) — bricht bestehende Daten (`/var/lib/<name>-<port>`)?
   Migration nötig (`migrate-uids.sh`-Analogon).
3. **Engine vs. Factory:** eine Engine, aber welche? Empfehlung: **Engine (ADR) = Kopf,
   Factory = Körper** (Engine ruft Factory für den Unit-Body auf).

---

## 7. GITHUB-ISSUE (Vorlage — kann ich nicht posten: `gh` nicht auth.)

**Titel:** `[ADR-0000] Dezimalrahmen-Rollout: Engine/Altstand zusammenführen (P0: user-/cred-Konflikt)`

**Body:**
```
Der Dezimalrahmen (ADR-0000) + lib/decimal-framework.nix sind verdrahtet (50-core/501),
aber der Rollout ist inkonsistent:

P0 Blocker
- users.users.<svc> wird von Engine (group=name) UND Modulen/Factory (group="media")
  definiert -> conflicting definition values (551:155 vs decimal-framework.nix:181).
- gid=5000 als Primary + 591:88 "group==media" widerspricht ADR-0000 §4 (UPG).

Zu übernehmen (gut im Altstand, fehlt in der Engine)
- LoadCredentialEncrypted (TPM) ueberall (13+ Stellen) -> Manifest-Feld in Engine.
- hardening-profiles.nix + memory-policy.nix.
- TemporaryFileSystem (RAM-Transcode), InaccessiblePaths, Peer-Isolation, BindPaths,
  First-Boot-DB-Marker-Guard.

Raus
- doppelte users.users-Definition; port-suffizierte StateDirs (<name>-<port>);
  registry.nix als 3. Wahrheit; mkForce (500-host-baseline:116, 541:265);
  Podman/OCI-Widerspruch; tautologische Assertion service-contract.nix:372.

Verifikation: nix flake check (noch nicht gelaufen).
```

---

## 8. QUELLEN (Belege)

- Altstand: `Download/grapefruit89-medinix-core-8a5edab282632443.txt` (25.09., 332 Dateien;
  noch **ohne** `lib/decimal-framework.nix`, `lib/service-contract.nix`, `500-baseline`, `501`, `502`).
- Neu: `lib/decimal-framework.nix` (207 Z.), `lib/service-contract.nix` (378 Z.),
  `lib/registry.nix` (69 Z.), `lib/service-factory.nix` (162 Z.), `50-core/501-decimal-engine.nix`,
  `flake.nix:72-99` + `:725-790`, `default.nix:53-79`, `551-jellyfin.nix`, `591-cross-domain.nix`.
- Benchmark: `55-playback/551-jellyfin.nix` (Goldstandard: Creds + RAM-Transcode + DB-Guard).
