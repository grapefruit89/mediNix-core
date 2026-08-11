# ADR-5115: Split-DNS für stream-Dienste (Hairpin-NAT-Vermeidung)

## Status: note (keine Architekturentscheidung, nur Dokumentation)
## Date: 2026-08-11
## Source: User-Input (Speedport Custom-DNS, Blocky/AdGuard Alternative)

## Context
Stream-Dienste (Jellyfin/ABS/Navidrome/Feishin, caddyClass=stream) sind WAN-exposed.
Greift ein Client im LAN auf `https://jellyfin.m7c5.de` zu, muss die Auflösung auf die
**LAN-IP des Servers** zeigen — nicht auf die WAN-IP (sonst Hairpin-NAT: Paket geht raus
über Router, zurück rein, Performance-Verlust + ggf. Blockierung).

## Decision
**mediNix-core macht KEINEN Split-DNS selbst.** Das ist Host-Infrastruktur.
Mögliche Lösungen (Host-seitig):
- Router mit Custom-DNS (z.B. Speedport): `jellyfin.m7c5.de → 192.168.2.x` (LAN)
- Blocky / AdGuard Home: Local-zone Override für `*.m7c5.de` → LAN-IP
- Pi-hole: Local DNS Record

## Consequences
- ✅ Kein Modul-Code für DNS in mediNix-core (portabel bleibt portabel)
- ✅ Host entscheidet selbst über DNS-Strategie
- ⚠️ Wenn Host keinen Split-DNS hat: LAN-Clients nutzen Hairpin-NAT (funktioniert,
  ist nur langsamer). Kein Hard-Fail.

## Related
- ADR-5110 (caddyClass stream/internal/public/none)
- ADR-5120 (Pocket-ID OIDC)
