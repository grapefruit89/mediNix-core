<!-- LEDGER-TOP -->
<!-- LAST-HASH: e16e3b4 -->
# mediNix-core — Changelog (Aktive Phase)

Struktur-konformer, portabler NixOS-Mediastack (10-Domain-Architektur, systemd-native, kein Docker).

> **Historisches Archiv:** Vollständige Changelog-Einträge vor November 2026 (Phase 1 bis 15,
> Ingress-Reviews) sind archiviert in `historie/2026-Q4-changelog-alt.md`.

---

## 2026-11 — Cockpit-Kapselung & LLM-Ordnerstruktur (Baustein B)
- **Cockpit-Budget & Kapselung:** `AGENTS.md` (≤ 70 Z. / ≤ 500 W. / ≤ 4000 B.) und `map.md` (≤ 100 Z. / ≤ 700 W. / ≤ 5500 B.) als kanonischer Einstieg etabliert.
- **Multi-AI Pointer:** `CLAUDE.md` und `GEMINI.md` als schlanke 1-Schritt-Zeiger verankert.
- **Mechanisches Budget-Gate:** `scripts/check_ai_cockpit.py` prüft Zeilen, Wörter und Byte-Grenzen; verankert in `order-lint` CI.
- **Layer 3 Ledger:** Althistorie nach `historie/` ausgelagert (`2026-Q4-changelog-alt.md`, `2026-Q4-roadmap-alt.md`). `ROADMAP.md` auf aktive Zukunfts-Meilensteine gestrafft.
- **Agent-Readiness:** `AGENT-READINESS.md` nach `docs/AGENT-READINESS.md` verschoben.
- **Folder-Lint:** `.claude`-Tooling-Ordner in `docs/agents/shared/scripts/folder_lint.sh` freigegeben.

## 2026-11 — SSoT-Konsolidierung & Todo-Ratsche
- **Aufgaben-Zentralisierung:** Offene Arbeit vollständig in `todo/tasks.json` konsolidiert; Sichten `docs/TODO.md` und `docs/PLAN.md` werden rein maschinell abgeleitet.
- **Ratsche & Gates:** `scripts/check_tasks.py` erzwingt valide `source.ref`-Zeiger; `gen_todo.py --check` und `gen_plan.py --check` sichern Drift-Freiheit in CI.
- **Doku-Konsolidierung:** ARCH-50 und Altdokumente nach `docs/audit/2026-11-07/` archiviert.

## 2026-11 — Modul- & Service-Härtung
- **Arr-API-Key-Handling:** Übergabe per `ExecStartPre` statt unsicherer Umgebungsvariablen (T-29-02).
- **Credential-Mapping:** `seal-secret` mappt `-apikey` konsistent auf den Credential-Namen `-api-key` (T-29-01).
- **UPG- und Test-Struktur:** Tests von `tests/` nach `50-core/` verlagert, direkt neben die zu prüfenden Verträge.
- **Host-Integration:** Korrekturen an Logrotate-Guard und Host-Build-Funden für `q958`.
