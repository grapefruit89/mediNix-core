---
id: "ARCH-52-vault-sidecar"
title: "ARCH 5200 vault sidecar"
domain: 52
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - security
  - vault
links:
  adr: ""
  repo-harvest: ""
---
# Strategy: Native Vault Integration (Sidecar Architecture)

## 1. User Layer (KISS)
Dieses Dokument beschreibt die "Elite-Stufe" der Passwort-Verwaltung. Anstatt Passwörter verschlüsselt in Dateien zu speichern (wie bei sops-nix), nutzen wir einen speziellen Sicherheits-Dienst (Vault Agent), der die Passwörter erst in dem Moment herbeizaubert, in dem ein Programm startet. Sobald das Programm beendet wird, verschwinden die Passwörter restlos vom Server. Das ist die sicherste Methode, die es aktuell für Linux-Server gibt.

## 2. Technical Layer (Aviation-Grade)

### Das Sidecar-Prinzip
Das Modul implementiert ein **Sidecar-Pattern** auf systemd-Ebene:
*   **Isolierung:** Für jeden Dienst (z.B. Postgres) wird ein eigener  gestartet.
*   **Namespace-Sharing:** Durch  und  teilen sich der Agent und der Zieldienst einen unsichtbaren, flüchtigen Speicherbereich.
*   **Dynamic Injection:** Geheimnisse werden via Consul-Templates direkt in Konfigurationsdateien oder Umgebungsvariablen injiziert.

### SRE Sicherheits-Vorteile
*   **Zero-Persistence:** Geheimnisse existieren niemals dauerhaft auf der Festplatte (Tier A/B/C), sondern nur im RAM-geschützten  Bereich des Dienstes.
*   **Auto-Rotation:** Wenn ein Passwort in Vault geändert wird, merkt der Agent das sofort, schreibt die neue Datei und startet den Dienst automatisch neu ().
*   **Identity-Based Access:** Jeder systemd-Dienst bekommt eine eigene Identität (AppRole) und kann nur exakt die Passwörter lesen, die er zum Überleben braucht.

### Implementierung (Nix-Snippet)


## 3. Reasoning Layer (History)

### [ADR-081] Vault Agent vs. Static Encryption (SOPS)
*   **Status:** In Evaluation (V6.x).
*   **Kontext:** sops-nix ist hervorragend für statische Keys (WLAN, SSH), stößt aber bei dynamischen Geheimnissen (Datenbank-Passwörter, Cloud-Tokens) an Grenzen.
*   **Entscheidung:** Einführung des  für alle Schicht-20 und Schicht-30 Backend-Dienste.
*   **Vorteil:** Erhöhte Sicherheit durch kurzlebige Tokens und lückenlose Audit-Logs in Vault.

---
**Community-Abgleich:** Das Modul von Determinate Systems gilt als die Referenz-Implementierung für native Vault-Integration in NixOS.
