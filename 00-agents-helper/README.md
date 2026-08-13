# 00-agents-helper

Hermes-Agent Skills für das mediNIX-core Projekt. Diese Skills sind das "Agent-Handwerkszeug"
für NixOS/mediNIX-Entwicklung, Reviews, Audits und Homelab-Operationen.

## Struktur

Alle Skills sind eigenständig (kein built-in Hermes-Bundle). Jeder Ordner hat eine `SKILL.md`.

### mediNIX-core / NixOS
- `medinix-*` — mediNIX-spezifische Workflows (Implementierung, Dezimalrahmen, Guardrails, Audits)
- `nixos-*` — generische NixOS-Tools (Context7-Gate, Decimal-Audit, Flake-CI, Repo-Harvest, Safe-Deployment)
- `karpathy-coding-principles` — Grundprinzipien für KI-Coding (lesen → surgical → verify)
- `medianix-integrator` — Gold-Standard Integration aus Vektor-Wissensbasis
- `unraid-ssh-access` — Tower/Unraid SSH aus Hermes-Container
- `ram-aware-vector-index`, `vector-db-enrichment`, `json-to-vector-db` — Vektor-Wissenbasis-Tools
- `kanban-orchestrator`, `kanban-worker` — Task-Decomposition
- `hermes-session-checkpoint`, `webhook-subscriptions` — Agent-Operationen

## Nutzung

In Hermes: `skill_view(name="medinix-implement-discipline")` etc.
Bei mediNIX-Code-Tasks ist `medinix-implement-discipline` PFLICHT (Pipeline + Report-Format).

## Hinweis

Diese Skills sind bewusst NICHT Teil des portablen mediNIX-core Flake — sie sind
Entwicklungs-Werkzeug, kein Runtime-Code.
