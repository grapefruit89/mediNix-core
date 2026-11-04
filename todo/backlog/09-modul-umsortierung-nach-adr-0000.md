# Aufgabe 9 — Modul-Umsortierung nach ADR-0000

> [!CAUTION]
> **STATUS: GEPLANT — NICHT AUTOMATISCH AUSFÜHREN!**

---

## Problem

Drei Module liegen in der falschen Dekade, ein Ordner heißt semantisch falsch:

1. **`54-transfer/`** — `derive.nix` definiert Dekade 4 kanonisch als `processing`. Der Ordner heißt `transfer`. Das ist die einzige Dekade, bei der Ordnername und Framework-Name auseinanderfallen. „Transfer" ist Weiterleiten, „Processing" ist Verarbeiten — semantisch unterschiedlich. Der Ordner lügt über seinen Inhalt.

2. **`57-maintenance/572-recyclarr.nix`** — Recyclarr synct TRaSH-Quality-Profile in Sonarr/Radarr. Es ist ein *arr-Helfer, kein generischer Maintenance-Dienst. Gehört zu 53-acquisition.

3. **`57-maintenance/574-provisioning.nix`** — Provisioniert *arr-APIs deklarativ. Gleiches Bild: *arr-Helfer, gehört zu 53-acquisition.

4. **`57-maintenance/575-update-notifier.nix`** — Prüft täglich auf mediNix-Updates, schickt ntfy. Das ist Beobachten + Melden, nicht Wartung. Gehört zu 58-observability.

Nach der Umsortierung: 53 = 8 Module, 54 = 2, 55 = 3, 56 = 1, 57 = 6 real + 1 Placeholder, 58 = 8. Kein Ordner ist dann überladen oder unterbesetzt — 56 bleibt klein, weil Exposition inhärent klein ist (wächst mit readmeabook).

---

## Ziel

Jedes Modul sitzt in der Dekade, die `derive.nix` für seine Funktion vorsieht. `id:` im YAML-Header, `folder:` im YAML-Header, `num:` im Modul und `domain:` im Header stimmen alle mit dem tatsächlichen Ordner überein. Die ADRs sind umbenannt und alle Referenzen konsistent. Das Framework ist nicht mehr durch Ordnernamen verwässert.

---

## Aktionen

### Vorarbeit — nur kartieren, keine Änderung:

- Alle Referenzen auf `54-transfer`, `572-recyclarr`, `574-provisioning`, `575-update-notifier` finden: in `.nix`-Dateien, `flake.nix`, `default.nix`, Skripten, `docs/`, ADRs, `mkdocs.yml`, `AGENTS.md`, `README.md`, `.claude/skills/`. Vollständige Liste liefern.
- Prüfen: `537`, `538`, `588` sind in `registry.nix` und `derive.nix` frei (keine Kollision mit existierenden Slots).
- Prüfen: Gibt es Assertions in Modulen, die die Dekaden-Zugehörigkeit erzwingen (z. B. „Modul XY muss in Dekade 7 sein")? Falls ja: vollständig auflisten. Diese Assertions müssen ggf. angepasst werden.
- Prüfen: Existieren die ADRs `ADR-572-recyclarr.md`, `ADR-574-provisioning.md`, `ADR-575-update-notifier.md`? Wie lauten die exakten Dateinamen?
- Prüfen: Enthält die `registry.nix` die Services `recyclarr`, `provisioning`, `update-notifier`? Wie sind deren `num`-Werte heute?

### Move 1 — `54-transfer` → `54-processing`:

- Ordner per `git mv` umbenennen.
- YAML-Header in `541-sabnzbd.nix` und `543-mover.nix`: `folder: 54-transfer` → `folder: 54-processing`.
- `54-processing/AGENTS.md` und `54-processing/README.md` — Header und interne Referenzen auf `54-transfer` umstellen.
- Alle Referenzen aus der Vorarbeit umstellen.
- `derive.nix` `decadeNames."4" = "processing"` bleibt unverändert (war schon korrekt).

### Move 2 — `572-recyclarr.nix` → `53-acquisition/537-recyclarr.nix`:

- Datei per `git mv` verschieben.
- YAML-Header: `id: "537-recyclarr"`, `folder: 53-acquisition`, `domain: 53`.
- Im Modul: `num: 572` → `num: 537`. Falls Registry-Eintrag existiert: dort ebenfalls `num` anpassen.
- ADR umbenennen (`ADR-572-recyclarr.md` → `ADR-537-recyclarr.md`). Inhalt der ADR: alle `572` auf `537` umstellen.
- Alle Referenzen aus der Vorarbeit umstellen.
- **Option-Pfad bleibt:** `medinix.maintenance.recyclarr.enable` und alle anderen `medinix.maintenance.recyclarr.*` bleiben exakt wie sie sind. Der Optionsname ist ein Vertrag mit der Host-Config, nicht der Dateipfad.

### Move 3 — `574-provisioning.nix` → `53-acquisition/538-provisioning.nix`:

- Wie Move 2, mit `538` statt `537`.
- ADR umbenennen.
- **Option-Pfad bleibt:** `medinix.maintenance.provisioning.*`.

### Move 4 — `575-update-notifier.nix` → `58-observability/588-update-notifier.nix`:

- Wie Move 2, mit `588` statt `537`.
- ADR umbenennen.
- **Option-Pfad bleibt:** `medinix.maintenance.updateNotifier.*`.

### Doku-Ergänzung — Kern vs. Zulieferer:

- In `55-playback/AGENTS.md` und im root `AGENTS.md` einen Absatz ergänzen: Die drei Dienste in 55-playback (Jellyfin, Audiobookshelf, Navidrome) sind der Kern des Systems. Alle anderen Dekaden existieren, um diesen Kern mit Content zu versorgen. Das ist die Antwort auf die Frage, warum der Kern klein und die Zulieferer breiter sind.

### Validierung nach jedem Move:

- `python3 scripts/nixmeta_check.py` — grün
- `python3 scripts/medinix-meta.py check-docs` — grün (generiert die `AGENTS.md`-Tabellen neu)
- `python3 scripts/check-nixmap.py` — grün
- `python3 scripts/check_manifest_edge.py` — grün (falls Manifest betroffen)
- `nix flake check --no-build` — 61/61 grün
- `git status` sauber

---

## Was nicht zu tun ist

- **Keine Option-Pfade ändern** (`medinix.maintenance.*` bleibt, wo es ist). Der Optionsname ist ein stabiler Vertrag, der Dateipfad ist intern.
- **Keine anderen Module verschieben** außer den vier genannten.
- **Keine Assertions entfernen oder abschwächen.** Falls Assertions die alte Dekaden-Zuordnung prüfen: anpassen, nicht löschen.
- **`56-exposition` bleibt bei 1 Modul** (Seerr), bis `readmeabook` aufgenommen wird.
- **Keine Modul-Logik inhaltlich ändern** außer `num`-Anpassung und Header.
- **Kein Commit ohne Rückmeldung.**

---

## Akzeptanzkriterien

- `54-processing/` existiert, `54-transfer/` weg.
- `53-acquisition/` enthält `537-recyclarr.nix` und `538-provisioning.nix`.
- `58-observability/` enthält `588-update-notifier.nix`.
- Alle vier YAML-Header konsistent (`id`, `folder`, `domain`).
- `derive.nix` unverändert.
- ADRs umbenannt und inhaltlich konsistent.
- Alle Referenzen im Repo umgestellt.
- Doku-Satz („Kern vs. Zulieferer") in beiden `AGENTS.md`.
- Alle fünf Validierungen grün.
- Kein Commit — auf Freigabe warten.

---

## Vorgesehene Commit-Nachricht

```
refactor(domains): align folder names and module placement with ADR-0000

- 54-transfer → 54-processing (matches derive.nix decade "processing")
- 572-recyclarr → 53-acquisition/537-recyclarr (arr helper, not maintenance)
- 574-provisioning → 53-acquisition/538-provisioning (arr helper)
- 575-update-notifier → 58-observability/588-update-notifier (watch, not maintenance)
- ADRs renamed accordingly
- Option paths unchanged (host-config contract stays stable)
- AGENTS.md: add note that 55-playback is the system core
```
