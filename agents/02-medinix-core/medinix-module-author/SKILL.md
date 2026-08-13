---
name: medinix-module-author
category: devops
description: "Core skill for creating or integrating a new 50-mediNix .nix service module. Enforces Decimal Framework (Dienstnummer, Port, UID), exact path rules, NIXMETA headers, strict hardening profiles, and zero-hardcoded-IP portability."
---

# medinix-module-author

Dieses Skill kombiniert die Erstellung neuer Module und die Integration aus Referenz-Quellen (wie Grok oder anderen GitHub Repos) in die mediNix-core Architektur.

## 1. Trigger & Fokus
- **Wann nutzen:** Jedes Mal, wenn ein neues `.nix` Service-Modul in `50-mediNix` (bzw. mediNix-core) erstellt oder Code dorthin integriert wird.
- **Hard Focus Rule:** Schreibe NUR nach `51-ingress` bis `59-guardrails`. Nutze niemals Docker oder netns; mediNix ist strikt systemd-nativ.

## 2. Die Dienstnummer (3 Digits, 500–599)
- **Vergabe:** Muss FREI sein (prüfe `lib/registry.nix`). Zwei Files mit demselben 3-Digit-Prefix = Kollision (illegal).
- **Ableitung:**
  - Port = Nummer × 10
  - UID = Port
  - GID = 5000 (Media-Gruppe)
  - ADR-Prefix = Port (z.B. ADR-5510 für Jellyfin)
- **Anchors:** `511` = Ingress/Caddy, `5x2` = Sicherheit, `5x9` = Guardrails/Timer.

## 3. Dateistruktur & Header
- **Flat Structure:** Ein Service = Genau EINE Datei (z.B. `55-playback/551-jellyfin.nix`). Niemals Ordner verschachteln!
- **NIXMETA Header:** Jede Datei muss oben einen Kommentar-Block mit Metadaten haben (`# id: NNN-name`, `# domain:`, `# status:`, `# layer:`, `# purpose:`, `# tags:`, `# requires:`).
- Verwende bei Integrationen immer das mediNix-Idiom (`config.grapefruitMedia.*` statt fremden `my.*` Parametern).

## 4. Hardening (Sicherheitsprofile)
- **Regel:** Kopiere niemals isolierte Security-Settings. Nutze *immer* das Profil-System!
- Lade das passende Profil aus `lib/hardening-profiles.nix` (z.B. `network`, `dotnet`, `dotnet-gpu`, `python`, `nodejs`, `script`).
- **Pattern:** `serviceConfig = lib.mkMerge [ profiles.<profil> { service-specific } ]`
- **Isolierung:** Container-Isolation in Systemd MUSS eine Liste sein (z.B. `lib.mkMerge [ [ isolation ] {…} ]`).

## 5. Portabilität (K.O. Kriterium)
- **Niemals:** Harte IPs (wie `192.168.x.x`), hartkodierte Hostnamen (`q958`, `jarvis`), oder spezifische `/opt/data/` Pfade, die nicht als Option konfigurierbar sind.
- Das Modul muss isoliert kompilieren können, egal auf welchem Host es ausgerollt wird.

## 6. Verifikation & Nächste Schritte
- Bevor du das Modul abschließt, nutze **`medinix-build-gate`** für Context7-Validierung neuer Nix-Optionen und den Portability-Check.
- Danach feuert die **`medinix-audit-suite`** für den finalen Kollisions- und Invarianten-Scan.
