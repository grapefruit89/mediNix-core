---
id: "mcp-setup"
title: "MCP-Server und die Kante Skills -> MCP"
status: active
complexity: 2
last_reviewed: 2026-10-16
links:
  adr: ADR-0002 (Grundfunktionen)
---

# MCP-Server (Stand 2026-10-16)

Die **maschinenlesbare SSoT fuer die CI** ist `scripts/mcp-servers.txt` (versioniert) — die
Live-Konfiguration liegt maschinenlokal in
`/home/moritz/.config/opencode/opencode.jsonc` (Block `"mcp"`) und ist fuer die CI unsichtbar.
Driftet beides, meldet `scripts/check_skills.py` lokal einen Hinweis.

## Konvention

Ein Skill, der einen MCP-Server **aufruft** (`tools["<server>"]`, `tools.<server>.`,
`mcp__<server>` — auch in `references/`), deklariert ihn im Front-Matter:

```yaml
---
name: mein-skill
description: "…wann laden…"
mcp: [nixos]
---
```

Mehrere Server als Liste (`mcp: [nixos, context7]`). Kein MCP-Bedarf -> Feld weglassen.
Der Check verlangt die Deklaration **automatisch** (Aufruf erkannt, aber nicht deklariert -> rot)
und lehnt unbekannte Server ab (nicht in `scripts/mcp-servers.txt` -> rot).

## Die acht Server

| Server | Zweck | Wird gebraucht von |
|---|---|---|
| `nixos` | nixpkgs-Pakete, NixOS-/home-manager-Optionen, Flake-Inputs, Cache-Status | `nixos-service-discovery`, `medinix-build-gate`, `medinix-knowledge-pipeline` |
| `context7` | kuratierte Doku-Snippets — **nur Sparformat-Index**, nie Wahrheit | `medinix-build-gate` (Fallback-Routing: `references/context7-routing.md`) |
| `arr` | Sonarr/Radarr/Readarr/Lidarr/Prowlarr-API (Provisioning, Queues) | (bislang kein Skill deklariert es) |
| `chrome-devtools` | isolierter Chromium per CDP (Recherche, Seiten prüfen) — **nie** der laufende User-Browser | `mydealz-recherche`, `browser-automation` (globale Skills) |
| `ha-mcp` | Home Assistant: Entitäten, Helper, Automatisierungen, Dashboards | (bislang kein Skill) |
| `homeassistant` | Home Assistant Intent-API: Geräte schalten, Zustände lesen, Datum/Zeit | (bislang kein Skill) |
| `kde-mcp` | KDE Plasma 6 / Wayland: Clipboard, Fenster, Eingaben | (bislang kein Skill) |
| `unraid` | Unraid-Homelab (192.168.2.250): Container, Shares, Dashboard | `unraid-homelab` (globaler Skill) |

**Hinweis zur Rangfolge (AGENTS.md):** Live-Quelle > Wiki/Upstream-Doku > Context7. Ein Skill, der
Context7 als Pflicht-Gate verkauft, verletzt die Regel — Context7 bleibt Sparformat-Index.

## Grenze der Ueberwachung

CI-geprueft sind die **Repo-Skills** (`docs/agents/**/SKILL.md` + ihre `references/`).
Globale Skills (`/home/moritz/.agents/skills/`, `~/.config/opencode/skills/`) liegen ausserhalb
dieses Repos: ihr `mcp:`-Feld ist maschinenlokal und wird **nicht** von der CI geprueft
(bewusste Entscheidung 2026-10-16 - Spiegeln in das Repo waere doppelte Pflege).
