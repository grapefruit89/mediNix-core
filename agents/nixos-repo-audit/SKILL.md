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
