# ADR-5040: Dezimalrahmen-konforme Port-Ableitung (50-core)

## Status: active
## Date: 2026-08-11
## Source: ADR-0000 (Dezimalrahmen-Verfassung), Abschnitt 4 + 8
## Related: ADR-0000, ADR-5043

## Context
During pivot extraction, raw chat text contained 4-digit numbers (e.g. "5055",
"5003", "5020") that looked like ports. These VIOLATE the Verfassung: only the
3-digit service number derives Port/UID (×10). 4-digit numbers never derive
anything (ADR-0000 §4, rejected: "Ableitungen aus 2- oder 4-stelligen
Nummern").

## Decision — CORRECT derivation (Verfassung §4)
| Service | Dienstnummer (3-digit) | Port = ×10 | UID = ×10 | GID = 5000 |
|---------|----------------------|-----------|-----------|------------|
| Caddy | **511** (51-ingress, _1 Zugang) | **5110** | 5110 | 5000 |
| Pocket ID | **512** (51-ingress, OIDC/Auth) | **5120** | 5120 | 5000 |
| SABnzbd | **541** (54-transfer) | **5410** | 5410 | 5000 |
| Sonarr | **532** (53-acq) | 5320 | 5320 | 5000 |
| Jellyfin | **551** (55-playback) | 5510 | 5510 | 5000 |
| Audiobookshelf | **552** (55-playback) | 5520 | 5520 | 5000 |
| Navidrome | **553** (55-playback) | 5530 | 5530 | 5000 |
| Jellyseerr | **561** (56-anfragen) | 5610 | 5610 | 5000 |

**NO 4-digit ports exist.** "5055" from chat was an error — correct is 5120 (Pocket ID = 512). "511" is Caddy (the _1 Zugang), not Pocket ID.

## Consequences
- ✅ Verfassungskonform (ADR-0000 §4)
- ✅ UID == Port (isomorphism, ADR-5043)
- ⚠️ Chat text with "5055" etc. is INVALID — do not use

## Gold-Standard (from ADR-0000)
> "Ableitungsquelle ist ausschließlich die dreistellige Dienstnummer. Port =
> Nummer × 10." → 4-digit numbers never derive. Last digit of a service number
> is the service role (N1–N9), never a free zero.
