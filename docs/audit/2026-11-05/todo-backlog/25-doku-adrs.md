# Gruppe 6 — Doku & ADRs

Stand: 2026-11-04 · zusammengeführt aus `ROADMAP.md`, `docs/TODO.md`, `docs/AUDIT-LEDGER.md`

> **Was hier steht:** Dokumentation, ADR-Vollständigkeit und Meta-Pflege.
> `ROADMAP.md` bleibt Quelle.

| ID | Punkt | Aufwand | Charakter | Belege |
|---|---|---|---|---|
| **R161** | **ADR-Verweis-Rest (Kette Code → ADR).** 7 Allowlist-Einträge in `scripts/adr-refs-allowlist.txt` abarbeiten — für 514 (ACME), 554, 582 (Gatus), 543 (Mover), 570 (Storage), 587 (Disk-Health), 525 (VPN-Interface) fehlen ADRs. Entscheiden: anlegen oder auf ADR-0000/zuständigen Beschluss verweisen. Dazu die Sonderfälle `ADR-571-*` (3 Dateien, **eine** Nummer) und `ADR-52-ssh-port-policy` (Überschrift sagt „ADR-21"). | MITTEL | Doku / ADRs | `ROADMAP.md:161` · `docs/TODO.md:44` |
| **R163** | **Skill-Trigger nachschärfen.** 18 von 30 Projekt-Skills haben eine `description` unter 80 Zeichen — und die Beschreibung ist das Einzige, was eine Session ohne Laden sieht. Dazu `nixos-llm-audit` / `medinix-nix-idioms` / `nixos-flake-patterns` als Merge-Kandidaten prüfen. | MITTEL | Doku / Skills | `ROADMAP.md:163` · `docs/TODO.md:45` |
| **R94** | **`docs/AUDIT-NIXOS-IDIOMS.md`:** Methodik (drei Schichten, „**Signal ≠ Fund**"), Signal-Tabelle P0/P1/P2, datierter Lauf von `scripts/nixos_idiom_audit.py`, plus der harte Beweis = Schicht 3 (`nix flake check` **ohne** `--impure`). | MITTEL | Doku | `ROADMAP.md:94` · `docs/TODO.md:37` |
| **R95** | **CONVENTIONS §Audit:** drei Schichten + Prüf-Leiter **Stufe 0a** (`idiom_audit --p0-only`) und **Stufe 1a** (`nix flake check` ohne `--impure`); Korridor-Blacklist `AB-0xx` für die harten Reflexe (`--impure` im Code, `nix-env -i`/`nix-channel`, Schreibzugriff `/nix/store/`, `/usr/`-Pfade). | MITTEL | Doku | `ROADMAP.md:95` · `docs/TODO.md:38` |
| **R97** | **`docs/HOST-INTERFACE.md`:** **eine** Seite „Host-Schnittstelle" — `medinix.host.*`, `hostIntegration.*` (`managed`/`external`/`off`), `secrets.*`, `recommended.*`, `storage.*` — plus „was gehört **nicht** in den Flake". | MITTEL | Doku | `ROADMAP.md:97` · `docs/TODO.md:40` |
| **L15** | **`complexity:` fehlt bei 15 von 44 Modulen** → Index zeigt `-/5`. Braucht je Modul ein Urteil (1–5), deshalb nicht automatisiert. | MITTEL | Doku | `docs/AUDIT-LEDGER.md:25` · `docs/TODO.md:49` |

## Empfehlung

**R161 zuerst** — es ist der einzige Punkt, bei dem ein Gate (die Allowlist) aktiv Schuld
verwaltet. Jeder Eintrag ist eine Ausnahme, die niemand mehr begründet.

**R163 danach** — 18 Skills mit zu kurzer Beschreibung heißt: 18 Skills, die eine Session
nicht findet. Das ist kein Doku-Detail, das ist verlorene Fähigkeit.

## Nicht Teil dieser Gruppe

- `docs/AUDIT-LEDGER.md` wird **nicht** geändert (Befund-Gedächtnis).
- Die §11/§4/§10-Kürzungen in ADR-0000 sind Kosmetik → Gruppe 7.
