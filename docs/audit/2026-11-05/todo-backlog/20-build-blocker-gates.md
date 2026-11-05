# Gruppe 1 — Build-Blocker & Gates

Stand: 2026-11-04 · zusammengeführt aus `ROADMAP.md`, `docs/TODO.md`, `todo/backlog/16-claude-review-delta.md`

> **Was hier steht:** Punkte, bei denen etwas bricht oder eine Lücke offen bleibt,
> wenn deployt oder erweitert wird. Keine Feature-Wünsche.
> `ROADMAP.md` bleibt Quelle — die Zeilenverweise gelten dort.

| ID | Punkt | Aufwand | Charakter | Belege |
|---|---|---|---|---|
| **R47** | **L-047: echte Credential-Quelle für root/wheel.** `users.mutableUsers = lib.mkDefault false` braucht einen realen Login-Pfad; heute existiert nur der `testHostAccess`-Stub in Prüfkonfigurationen. Ohne ihn blockiert die nixpkgs-Assertion jedes Host-Build. | offen (messen) | **Build-Blocker (P0)** | `ROADMAP.md:47` · `docs/TODO.md:22` · ADR-0002 Punkt 1 |
| **R66** | **Datei-basierte Ports härter prüfen.** Für Jellyfin den *gerenderten* XML-Inhalt greppen — heute nur Seed-Platzhalter + Substitution im Quelltext. | MITTEL | Gate | `ROADMAP.md:66` · `docs/TODO.md:25` |
| **R73** | **`vpn-killswitch-test.sh`** — echter Egress-Leak-Test (nicht nur Konfigurations-Assertion). | MITTEL | Sicherheit | `ROADMAP.md:73` · `docs/TODO.md:27` |
| **B-M4** | **591 Options-Pfad-Assertion.** Prüfen: jeder Registry-Dienst mit Port löst auf einen existierenden Options-Pfad auf. Plus Negativtest. Letzte offene `○` der Claude-Review-Delta-Tabelle. | MITTEL (~30 min) | Gate | `todo/backlog/16-claude-review-delta.md` (M4) |

## Reihenfolge

1. **R47** zuerst — es ist der einzige Punkt, der einen Deploy verhindert.
2. **B-M4** — schließt die Delta-Tabelle ab.
3. R66, R73 — Verteidigung, wirkt erst bei künftigen Änderungen.

## Nicht Teil dieser Gruppe

- Hardening-/Krypto-Features → Gruppe 4.
- Observability-Lücken → Gruppe 3.
