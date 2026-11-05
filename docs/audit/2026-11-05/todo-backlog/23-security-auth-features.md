# Gruppe 4 — Security & Auth-Features

Stand: 2026-11-04 · zusammengeführt aus `ROADMAP.md`, `docs/TODO.md`

> **Was hier steht:** Feature-Wünsche im Sicherheits-/Auth-Bereich. Kein akuter Bedarf —
> die bestehende Auth-Kette (Pocket-ID + Caddy + oauth2-proxy) funktioniert.
> `ROADMAP.md` bleibt Quelle.

| ID | Punkt | Aufwand | Charakter | Belege |
|---|---|---|---|---|
| **R24** | **FIDO2 / Passkey-only Authentifizierung.** Passkey-only-Flow für Pocket ID und hardwaregestütztes WebAuthn via Caddy / oauth2-proxy als zweiter Faktor. Status: `proposed`. | GROSS | Security-Feature | `ROADMAP.md:24` · `docs/TODO.md:20` · ADR-512, ADR-517 |
| **R74** | **Pocket-ID Auto-Enrollment + Multi-User/RBAC** über versiegelte Credentials. | GROSS | Security-Feature | `ROADMAP.md:74` · `docs/TODO.md:28` |

## Abhängigkeit

**R24 setzt R74 teilweise voraus:** Passkey-only ergibt erst Sinn, wenn mehr als ein
Benutzer existiert und die Enrollment-Prozedur steht. Reihenfolge also **R74 → R24**.

## Nicht Teil dieser Gruppe

- Der `vpn-killswitch-test.sh` ist **kein Feature, sondern eine fehlende Prüfung** →
  Gruppe 1 (`20-build-blocker-gates.md`, R73).
- Secrets-/Hardening-Basis ist mit ADR-5050, ADR-521 und `hardening-profiles.nix` erledigt.
