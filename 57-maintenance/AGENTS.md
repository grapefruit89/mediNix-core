# 🧠 LLM Wiki: `57-maintenance`

> **Zweck:** Automatisch generierte Dokumentation für KI-Agenten. Bitte lies diese Datei, um den Scope und die Architektur dieses Ordners zu verstehen.

## 📦 Module Map

| ID | Modul-Datei | Status | Komplexität | Ports |
|---|---|---|---|---|
| `570-storage` | `570-storage.nix` | active | 4/5 | - |
| `571-sqlite-wal` | `571-sqlite-wal.nix` | active | 3/5 | - |
| `572-recyclarr` | `572-recyclarr.nix` | active | 3/5 | - |
| `573-exportarr` | `573-exportarr.nix` | active | 4/5 | - |
| `574-provisioning` | `574-provisioning.nix` | active | 4/5 | - |
| `575-update-notifier` | `575-update-notifier.nix` | active | 3/5 | - |
| `576-backup` | `576-backup.nix` | active | 3/5 | - |
| `577-drift-detection` | `577-drift-detection.nix` | active | 3/5 | - |
| `578-orphan-cleanup` | `578-orphan-cleanup.nix` | active | 3/5 | - |
| `579-backup-ssh` | `579-backup-ssh.nix` | active | 2/5 | - |

## 🔗 Interne Abhängigkeiten (Requires)

Die Module in diesem Ordner benötigen folgende Bibliotheken/Dateien:

- `lib/hardening-profiles`
- `lib/registry`

---
*Generiert durch `medinix-meta.py generate-docs`*
