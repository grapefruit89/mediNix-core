# ADR-0000 Dezimalrahmen — condensed rules (Verfassung, NEVER delete)

Source of truth for ALL numbering in mediNix + sibling projects. If a port/UID/GID or
ADR prefix looks wrong, this is the arbiter.

## Fraktal / Ebenen
- Ebene 1 `/modules/` 2-stellig (00·10·…·90)
- Ebene 2 `/50-media/` 3-stellig (500–590)
- Ebene 3 (bei Bedarf) 4-stellig (5510·5520·…)
- A level stays flat (files) until too big, then GRADUIERT (adds a digit).

## Container-Stelle vs Blatt-Stelle
- CONTAINER (Dekade/Domäne/Ordner): carries the 4 anchors.
  - `_0` Fundament (Wissen/Struktur, NIEMALS Dienste)
  - `_1` Zugang (Reverse-Proxy, mDNS, Routing, Auth-Eingang)
  - `_2` Sicherheit (Firewall, TLS, VPN, Auth-Mechanik)
  - `_9` Leitplanken (Assertions, Verbote, Invarianten)
- BLATT (Dienst): only N0 (Block-ID, never a program) + N1–N9 (Dienste).
  Anchors do NOT apply on leaf levels. Last digit of a service number = role (1–9).

## Ableitung (§4) — THE rule that was violated
- Ableitungsquelle = AUSSCHLIESSLICH die 3-stellige Dienstnummer.
- Port = Nummer × 10, UID = Nummer × 10, GID = Projekt × 1000.
- **2- and 4-digit numbers derive NOTHING** (collide with ephemeral-port band).
- ⇒ A 4-digit "port" like 5055 / 5003 / 5020 is INVALID. Treat chat text with these
  as an error, NOT a fact.
- mediNix = 50: GID 5000, UID/Port 5xx0 (all end in 0).

## Confirmed map (mediNix)
511=Caddy (5110), 512=Pocket ID (5120), 541=SABnzbd (5410), 532=Sonarr (5320),
551=Jellyfin (5510), 552=Audiobookshelf (5520), 553=Navidrome (5530), 561=Jellyseerr (5610).
**511 is Caddy — never Pocket ID.**

## ADR filename prefixes
- Schicht-basis: Ordner00 (ADR-5000, ADR-5700).
- Service ADR: service PORT (ADR-5410 SABnzbd, ADR-5101 Pocket ID, ADR-5501 Audiobookshelf).
- Never invent 4-digit running numbers like ADR-0050/ADR-5001 for a basis doc.

## Structure proofs (§5) — why it's safe
- GID H000 never collides with a UID (H00 is Block-ID, holds no service).
- Smallest service port = H110 ≥ 1110 > 1023 → never privileged. H=0 never derives.
- Max port 9990 < 65535, below ephemeral band (32768+).

## Rejected (§9) — anti-patterns
- UID=1000+Nummer (breaks "Projektziffer vorne")
- GID per service (breaks shared-library access → Permission denied)
- 4-digit derivations, nested folders 510/511-x.nix (breaks flat auto-import)
- Anchors on leaf level ("531 = Zugang der Beschaffung" is nonsense)
- Verfassung as 8000 (devNIX's own _0 slot) → now 0000.
