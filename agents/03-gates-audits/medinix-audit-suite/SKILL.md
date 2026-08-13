# medinix-audit-suite

This is a consolidated skill merging the capabilities of: nixos-decimal-audit, nixos-repo-audit, medinix-assertion-quality

## --- Inherited from nixos-decimal-audit ---

---
name: nixos-decimal-audit
description: Audit mediNix-core decimal conflicts, ports, duplicates.
---

# nixos-decimal-audit

Wiederverwendbarer Audit für das mediNix-core Boilerplate (grapefruit89/mediNix-core).
Prüft die Dezimalrahmen-Invarianten (ADR-0000) auf Verletzungen.

## Wann laden
- Nach jeder Umbenennung/Verschiebung von `.nix`-Modulen
- Vor jedem Commit in mediNix-core
- Bei Verdacht auf Duplikate ("Caddy zweimal", "SABnzbd mehrfach")
- Bei Inkonsistenz-Scans (User: "scan nach Inkonsistenzen")

## Invarianten (ADR-0000)
- Port = Dienstnummer × 10, UID = Port, GID = 5000
- Flat: `XX-domain/NNN-service.nix` — keine verschachtelten Service-Ordner
- Eine Datei pro Dienst (kein Caddy in 2 Dateien gespalten)
- 3-stellige Dienstnummer leitet ab; 4-stellige Zahlen leiten NICHTS ab
- 511=Caddy, 512=Pocket ID, 541=SABnzbd, 543=Mover (NICHT 541=Mover)
- 559=playback-tuning (Cross-deps inline in Service-Modulen, keine 559-cross-service.nix)

## Tools (in references/)
- `scan_duplicates.py` — voller Duplikat-Check (Namens-, Inhalt-, Nummern-, ID-Kollisionen + Caddy/SABnzbd-Spezial-Checks)
- `scan_inconsistencies.py` — Dezimalrahmen-Inkonsistenz-Check (Dateiname vs Port vs Dienstnummer, 5x0-Regel)

## Verwendung
```bash
python3 ../../shared/scripts/scan_duplicates.py
python3 ../../shared/scripts/scan_inconsistencies.py
```

ROOT in beiden Skripten ist hart auf `/opt/data/50-mediNix` gesetzt — bei anderem Pfad anpassen.

## Interpretation
- "NO NUMBER in filename" = Modul ohne Dienstnummer (ok bei default.nix/lib/, fehlerhaft bei Service-Modulen)
- "PORT X != file num Y*10" = Header-Port falsch (Dateiname korrekt, Port im NIXMETA-Header muss fix)
- "SUSPICIOUS 5x0" = 5x0 mit x≠0 ist kein gültiger Dienst (nur 500/520/570 sind Basis-ADRs)
- Namens-Duplikate über verschiedene Pfade = echtes Problem (zwei Dateien gleichen Namens)
- Inhalt-identisch = kopierte Datei (löschen)

## Bekannte false positives (ignorieren)
- `default.nix` mehrfach (Domain-Loader, gewollt)
- Port 22/2222/443/80 in Headern (SSH/Firewall, keine Service-Ports)
- `57-maintenance/*.nix` ohne Nummer (Provisioning-Submodule, gewollt)

## --- Inherited from nixos-repo-audit ---

---
name: nixos-repo-audit
description: Audit NixOS repos for mediNix Gold-Standards.
---

# nixos-repo-audit Skill

## Trigger
- "Analysiere Repo X für mediNix"
- "Suche Gold-Standards in Repo Y"

## Ablauf (Schritt-für-Schritt)

### 1. Repo klonen (falls nicht vorhanden)
```bash
cd /opt/data/github_repos
git clone https://github.com/<user>/<repo>.git
```

### 2. Struktur prüfen (Dezimalrahmen)
```bash
find <repo> -name "*.nix" -type f | grep -E "(00|10|20|30|40|50|60|70|80|90)" | sort
```

### 3. Gold-Standards extrahieren (Fokus: mediNix)

#### A. Isomorphie (UID = Port)
```bash
grep -r "uid = port" <repo>/lib/registry.nix
```

#### B. Anti-Lockout (SSH, Assertions)
```bash
find <repo> -name "*ssh*" -o -name "*assert*" -o -name "*lockout*"
```

#### C. systemd-native Isolation
```bash
grep -r "RestrictNetworkInterfaces" <repo>/
```

#### D. SQLite Optimierungen
```bash
grep -r "PRAGMA" <repo>/ | grep -E "(WAL|NORMAL|cache_size)"
```

#### E. Provisionierung (API-Bootstrap)
```bash
find <repo> -name "*provision*" -o -name "*bootstrap*"
```

### 4. Bewertung (für mediNix brauchbar?)
**Kriterien:**
- ✅ Portabel (keine `my.*` Referenzen)
- ✅ Dezimalrahmen (50-media Struktur)
- ✅ Sicher (Anti-Lockout, SSH-Keys)
- ✅ Systemd-native (kein Docker/netns)

### 5. Integration in Boilerplate
**Ziel:** `/opt/data/50-mediNix/`

```bash
cp <repo>/path/to/gold-standard.nix /opt/data/50-mediNix/<target>/
```

**Wichtig:** Nur Dateien kopieren, die **mediNix-fokussiert** sind (50-media).

## Output
- **ADR:** `ADR-XXXX-<repo>-gold-standards.md` in `/opt/data/docs/ADR/`
- **Integration:** Dateien in `/opt/data/50-mediNix/` aktualisiert

## Pitfalls
- Nicht alles kopieren (nur 50-media relevant)
- Isomorphie prüfen (alte UIDs/Ports nicht übernehmen)
- YAML-Header ergänzen

## Verification
1. `find /opt/data/50-mediNix -name "*.nix" | xargs grep -l "my\."` → Leer
2. `nix flake check` in `/opt/data/50-mediNix/` → Erfolgreich

## --- Inherited from medinix-assertion-quality ---

---
name: medinix-assertion-quality
description: Enforces readable mediNix assertion messages what/why/fix.
---

# mediNix Assertion Quality (ADR-5043)

When you add, edit, or review any `assertions = [` or `warnings = [` block in
`/opt/data/50-mediNix/**/*.nix`, enforce this format. Reference impl:
`59-guardrails/595-ssh-assertions.nix`.

## Trigger
- Creating a new guardrail/assertion module in mediNix.
- Reviewing an existing assertion whose message is terse (e.g. `"ERROR: X aborted!"`).
- Any `nixos-rebuild` failure analysis where the message was unhelpful.

## Rule — every assertion message MUST contain
1. **Tag prefix** `[<module-id>]` so the message is traceable to a file (e.g. `[595]`, `[525]`).
2. **What** broke — the observed/blocked state.
3. **Why** — one sentence of rationale (security, lockout risk, contract).
4. **How** — the exact option or file to change to fix it.

Non-fatal reminders go in `warnings` (not `assertions`) — inform without blocking.

## Good vs Bad

Bad:
```
message = "ERROR: SSH disabled. Deployment aborted!";
```

Good:
```
message = ''
  [595] SSH service is DISABLED.
  A mediNix host without SSH is unreachable after reboot.
  Fix: set grapefruitMedia.ssh.enable = true.
'';
```

## Steps
1. Locate the `assertions`/`warnings` block.
2. For each entry, check the 4-part shape (tag, what, why, fix).
3. If missing, rewrite the message — keep the `assertion =` boolean unchanged.
4. Verify `warnings` are used for soft reminders, `assertions` for hard blockers.
5. Bracket-balance check: `for f in <file>; do o=$(grep -o "{" $f|wc -l); c=$(grep -o "}" $f|wc -l); echo "$f $o $c"; done` (must match).

## Pitfalls
- Do NOT put a live port number in a "deprecated" warning as if it were active — only as documentation text (grep must show no live assignment).
- Assertion booleans must stay correct; only the message string changes.
- `lib.singleton { assertion = ...; message = ...; }` is the idiomatic single-entry form.

## Verification
- `grep -rn "ERROR:" --include="*.nix" /opt/data/50-mediNix` should return nothing (all old terse messages migrated).
- Each message is self-explanatory without opening the source file.

