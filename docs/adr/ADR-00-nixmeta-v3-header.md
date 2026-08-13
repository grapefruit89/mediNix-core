---
id: "ADR-00-nixmeta-v3"
title: "NIXMETA V3.0 Header Standard"
domain: 00
status: active
complexity: 1
last_reviewed: 2026-08-13
tags:
  - core
  - conventions
links:
  adr: ADR-0000
---

# ADR-00: Der NIXMETA V3.0 YAML Header Standard

## Kontext
Um die maschinelle Lesbarkeit für LLM-Agenten (wie Context7, Kanbans, Code-Audits) zu gewährleisten und die manuelle Navigation für den Menschen zu optimieren, muss JEDE `.nix` Datei im `mediNix-core` Repository zwingend einen standardisierten YAML-Header am Dateianfang besitzen.

Es wurde sehr viel Zeit und Gehirnschmalz in die Ausarbeitung dieses Formats investiert. Dieses Dokument sichert dieses Wissen und dient als zentrale "Single Source of Truth" mit Tip-Top-Paradebeispielen für One-Shot / Few-Shot Prompts.

## Spezifikation (V3.0)
- Der Header MUSS in der ersten Zeile der Datei beginnen.
- Er MUSS in Nix-Kommentare (`# `) eingefasst sein.
- Er MUSS mit `# ---` beginnen und enden (YAML Frontmatter Syntax).
- Er MUSS valides YAML sein (nach Entfernung der `# ` Präfixe).

---

## Tip-Top-Paradebeispiel 1: Standard Service-Modul (Minimal)
Dieses Beispiel zeigt die Pflichtfelder, die jedes normale Modul (z. B. ein Guardrail oder Service) zwingend haben muss.

```nix
# ---
# id: "590-registry"
# title: "Zentrale Fehler-Registry (Invarianten + Assertion-Errors)"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-0000 (Dezimalrahmen-Verfassung)
# ---
{ config, lib, pkgs, ... }:
# ... nix code ...
```

## Tip-Top-Paradebeispiel 2: Komplexe Core-Module & Libraries
Dieses Beispiel zeigt das Maximalformat. Es wird für Libraries (wie die Registry selbst) oder hochkomplexe Core-Module verwendet, die Abhängigkeiten exportieren (`provides`) oder externe Dinge benötigen (`requires`).

```nix
# ---
# id: "registry"
# title: "mediNix SSoT Registry (ports/uid/gid, isomorph)"
# domain: 50
# folder: 50-media
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5043
# provides: ["ports", "uids", "services"]
# requires: []
# upstream_docs: ["https://nixos.wiki/wiki/Module_System"]
# forum_links: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
{ lib, ... }:
# ... nix code ...
```

## Erklärung der Felder

### 🔴 Pflichtfelder (Müssen immer existieren)
- `id:` Die exakte Dateikennung ohne `.nix` (z.B. `590-registry`).
- `title:` Ein kurzer, prägnanter, für Menschen lesbarer Titel.
- `domain:` Die 2-stellige Domain-Nummer (z.B. `59` für Guardrails).
- `folder:` Der exakte Ordnername, in dem die Datei liegt (z.B. `59-guardrails`).
- `status:` Lebenszyklus-Status (Erlaubt: `active`, `deprecated`, `draft`).
- `complexity:` 1 (sehr simpel) bis 5 (hochkomplexe Systemarchitektur).
- `last_reviewed:` ISO-Datum (YYYY-MM-DD) des letzten Red-Team Audits.
- `links.adr:` Referenz auf die primäre Design-Entscheidung (z.B. `ADR-0000`).

### 🟡 Erweiterte Felder (Für komplexe Module)
- `provides:` Liste von Features/Kontexten, die dieses Modul anderen zur Verfügung stellt.
- `requires:` Liste von Abhängigkeiten, die zwingend extern erfüllt sein müssen.
- `upstream_*`: Metadaten für Upstream-Dienste, GitHub-Repos und Foren-Beiträge zur Nachvollziehbarkeit.
- `state_dir:` Der primäre persistente Ordner (für Backups relevant).
