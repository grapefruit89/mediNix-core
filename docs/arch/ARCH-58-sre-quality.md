---
id: "ARCH-58-sre-quality"
title: "ARCH 5800 sre quality"
domain: 58
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - observability
  - quality
  - sre
links:
  adr: ""
  repo-harvest: ""
---
# Strategy: SRE Quality Standard & Roadmap (V6.x)

## 1. User Layer (KISS)
Dieses Dokument ist unsere Qualitäts-Checkliste. Wir haben dein System gegen den "Goldstandard" der NixOS-Community geprüft. Das Ziel ist nicht nur ein funktionierender Server, sondern ein System, das so professionell aufgebaut ist wie die offiziellen NixOS-Pakete. Wir führen einen "Ein/Aus-Schalter" für jedes Modul ein und sorgen dafür, dass die Sicherheit (Sandboxing) deine Grafikkarte nicht versehentlich aussperrt.

## 2. Technical Layer (Aviation-Grade)

### Community-Konformes Modul-Design
Jedes Modul muss dem `options`/`config`-Pattern folgen, um bedingte Aktivierung zu ermöglichen:
```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.mynixos.services.jellyfin;
in {
  options.mynixos.services.jellyfin.enable = lib.mkEnableOption "Jellyfin Service";
  
  config = lib.mkIf cfg.enable {
    services.jellyfin.enable = true;
    # ... restliche Config
  };
}
```
*   **Vorteil:** Dienste werden zentral in der `hosts/q958/default.nix` via `mynixos.services.jellyfin.enable = true;` gesteuert, anstatt Dateien im Dateisystem zu verschieben.

### Systemd Sandboxing (GPU-Spezialfall)
Um Hardware-Transcoding (Intel QuickSync) zu ermöglichen, müssen die Sicherheitsregeln für GPU-Dienste angepasst werden:
*   **Regel:** `PrivateDevices = false` (da `/dev/dri` benötigt wird).
*   **Zusatz:** Explizite Freigabe via `DeviceAllow = [ "char-drm rw" "char-dri rw" ];`.
*   **Validierung:** Ziel-Score bei `systemd-analyze security <service>` ist < 4.0.

### Roadmap Meilensteine
1.  **Refactoring (Aktuell):** Umstellung aller bestehenden Module auf das `mkEnableOption`-Pattern.
2.  **Secret-Cleanup:** Verschiebung aller verbliebenen Klartext-Passwörter in `sops-nix`.
3.  **DNA-Implementation:** Scharfschaltung des Network-Fingerprintings in der `initrd`.

## 3. Reasoning Layer (History)

### [ADR-015] Adoption of mkEnableOption Pattern
*   **Status:** Entschieden (März 2026).
*   **Kontext:** In der Version 2.3 wurden Module durch das Vorhandensein im Import-Stack aktiviert. Dies verhinderte die Nutzung derselben Modul-Sammlung für unterschiedliche Hosts mit verschiedenen Anforderungen.
*   **Entscheidung:** Einführung einer globalen Options-Hierarchie unter `mynixos.*`.
*   **Vorteile:** Volle Kompatibilität zum offiziellen NixOS-Stil, einfacheres Management von Multi-Host-Setups.

### [ADR-016] Precision Hardening vs. Global Sandbox
*   **Status:** Entschieden (März 2026).
*   **Kontext:** Ein globales Sicherheits-Modul für alle Dienste ist zu unflexibel für Spezialfälle (GPU, Netzwerk-Namespaces).
*   **Entscheidung:** Individuelles Hardening pro Dienst innerhalb der Modul-Datei.
*   **Begründung:** Maximale Sicherheit bei gleichzeitiger Funktionsgarantie für komplexe Hardware-Zugriffe.

---
**Sources:**
*   `/home/Knowledge-Pipeline/raw/_duplikate/SRE_AUDIT_NMS_v2.3.md`
*   `/home/Knowledge-Pipeline/raw/_duplikate/Gemini-NixOS Projektprüfung_ Bugs und Verbesserungen.md`
