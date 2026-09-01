# Dezimalrahmen-Benennung — geprüfte Fakten (ADR-0000 Verfassung)

## Ableitung (einzig wahre Quelle)
- Nur die **dreistellige Dienstnummer** leitet ab.
- Port = Nummer × 10 · UID = Nummer × 10 (= Port) · GID = Projekt × 1000 (mediNix=5000)
- Ergebnis IMMER auf 0 endend. 4-stellige Zahlen ohne 0-Endung sind INVALID.

## mediNix Service-Map (unverrückbar, User bestätigt 2026-08-11)
| Service | Dienst | Port | UID | GID | ADR |
|---------|--------|------|-----|-----|-----|
| Caddy | 511 | 5110 | 5110 | 5000 | ADR-5110 |
| Pocket ID | 512 | 5120 | 5120 | 5000 | ADR-5120 |
| SABnzbd | 541 | 5410 | 5410 | 5000 | ADR-5260 |
| Sonarr | 532 | 5320 | 5320 | 5000 | ADR-5320 |
| Jellyfin | 551 | 5510 | 5510 | 5000 | ADR-5510 |
| Audiobookshelf | 552 | 5520 | 5520 | 5000 | ADR-5520 |
| Navidrome | 553 | 5530 | 5530 | 5000 | ADR-5530 |
| Seerr | 561 | 5610 | 5610 | 5000 | ADR-5610 |

## Anker (gelten auf Container-Stellen, NICHT auf Blatt-Stelle)
- `_0` Fundament · `_1` Zugang · `_2` Sicherheit · `_9` Leitplanken
- 511 ist Caddy (Zugang/Reverse-Proxy). Pocket ID = 512 (zweiter Dienst im Zugang).
- Letzte Ziffer einer Dienstnummer = Dienst-Rolle (N1-N9), nie freie 0.

## Fehler, die dieser Session passiert sind (User korrigierte 5×)
1. "5055" / "5008" / "5009" als Ports erfunden → 4-stellig, nicht auf 0 → INVALID.
2. 511 = Pocket ID zugewiesen → 511 ist Caddy (Anker _1). USER: "511 ist caddy dann kann das nicht pocket id sein!"
3. ADR-Laufnummern (ADR-5001, ADR-5101) → müssen Dienstnummer×10 sein (ADR-5400, ADR-5120).

## Grok-Rohdaten direkt extrahieren (ohne v2 zu warten)
Grok pivots liegen als rohe JSON auf Tower:
`/mnt/user/data/hermes_knowledge/nixos_vectors/grok_extracted/prod-grok-backend.json`
Python mit ijson streamen, nach Conversation-Titel matchen, `text` extrahieren.
Kein FAISS/v2-Rebuild nötig für ADR-Inhalte. Befehl-Muster: investigate_pivots.py
unter `/opt/data/scripts/`.
