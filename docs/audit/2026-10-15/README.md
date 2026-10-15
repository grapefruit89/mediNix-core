# Archiv 2026-10-15 — Momentaufnahmen der Doku-Konsolidierung

Hier liegen die Dokumente, die bis zum 2026-10-15 als **konkurrierende Quellen** existierten.
Sie sind **nicht gelöscht**, sondern eingefroren: Der Inhalt bleibt als Beweis und Vorgeschichte
erhalten, ist aber nicht mehr handlungsleitend. Die kanonische Roadmap ist `ROADMAP.md` im Root.

| Datei | Was sie war | Warum archiviert |
|---|---|---|
| `ROADMAP.md` | „Architektur-Leitfaden & Zukunfts-Roadmap" (vierte Roadmap) | offene Punkte und die „bewusst abgelehnt"-Liste sind in die Root-`ROADMAP.md` übernommen |
| `ROADMAP-DEZIMALRAHMEN-MIGRATION.md` | Migrationsplan Altstand → ADR-0000 | Migration am 2026-10-15 abgeschlossen (Weg B: ein Eigentümer für `users.users`, UPG, SetGID, Guardrail 591) |
| `PHASE4-SPEC.md` | Implementierungs-Spec Phase 4 (577 Zeilen) | der Kernbefund betraf `52-security/524-systemd-credentials.nix` — dieses Modul existiert im aktuellen Stand nicht mehr; offene Items (2–7) sind als Backlog-Einträge übernommen |
| `AGENTS-docs-veraltet.md` | Agenten-Anleitung unter `docs/` | nannte `mediahost` / `192.168.0.10` / `/opt/data/50-mediNix`; ersetzt durch einen Zeiger auf das Root-`AGENTS.md` |

## Lehren dieser Runde (für den nächsten Agenten)

1. **Vier Roadmaps sind vier Wahrheiten.** Zwei davon beschrieben Arbeit, die längst erledigt war
   (Gatus als „nächster Schritt", `lib.fakeHash` in `511-caddy.nix`, der Zwei-Engine-Konflikt).
   Wer der falschen folgt, macht Arbeit doppelt oder repariert etwas, das es nicht mehr gibt.
2. **Ein veraltetes Dokument ist gefährlicher als ein fehlendes.** `docs/AGENTS.md` hätte jeden
   Agenten auf einen Host geschickt, den es nicht mehr gibt.
3. **Archivieren heißt einfrieren, nicht löschen.** Im Zweifel `git mv` nach `docs/audit/<datum>/` —
   die Historie bleibt, der Irrtum verschwindet aus dem Weg.
4. **Vor dem Verschieben prüfen, wer verlinkt** (mkdocs-Navigation, ADRs, Index-Dateien) — sonst
   bricht der `docs`-Build in der CI, so wie es die `order-lint.yml` am 2026-10-15 fast getan hätte.
