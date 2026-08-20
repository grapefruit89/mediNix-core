Du bist ein technischer Archivar und Redakteur.

Analysiere den gesamten Chat und extrahiere **nur die Quintessenz**.

### Ziel
Erstelle eine kompakte, optisch klar strukturierte Zusammenfassung, die ich später noch verstehen kann, ohne den Originalchat lesen zu müssen.

### Regeln
- Weglassen: Smalltalk, Wiederholungen, verworfene Ideen, reine Zwischenfragen, Höflichkeitsfloskeln
- Behalten: endgültige Entscheidungen, Architektur-Prinzipien, konkrete technische Lösungen, wichtige Warnungen, offene Punkte
- Keine Erfindung neuer Inhalte
- Maximal präzise und knackig formulieren

### Ausgabeformat (Markdown)

# Titel des Themas

## Kernentscheidungen
- ...

## Wichtige technische Erkenntnisse
- ...

## Konkrete Lösungen / Patterns
- ...

## Offene Punkte / Risiken
- ...

## Verworfene Ansätze (kurz)
- ...

## Ein-Satz-Fazit
...
---

# Konsolidierung: Architektur-Entscheidungen & Best Practices

## Kernentscheidungen
- **Flache Schichtenarchitektur (Separation of Concerns):** Caddy fungiert strikt nur als Reverse-Proxy/TLS-Terminator. Rate-Limiting passiert im Kernel (`nftables` via CrowdSec), Auth über Pocket-ID.
- **Keine All-in-One Gateways:** Lösungen wie Pangolin, Zoraxy, NetBird oder Authentik werden bewusst abgelehnt, um RAM-Overhead und Vendor-Lock-ins ("goldener Käfig") zu vermeiden. Caddy-Security-Plugins widersprechen der flachen Architektur.

## Wichtige technische Erkenntnisse
- **Jellybridge Plugin (Jellyseerr Integration):** Erlaubt direkte Requests (Herz-Icon) aus der Jellyfin-UI. **Achtung:** Sehr versionsanfällig. Sollte nur genutzt werden, wenn die Jellyfin-Version bewusst gepinnt und das Plugin aktiv gewartet wird.
- **Blocky vs. AdGuard (DNS):** Blocky passt als schlankes, UI-freies Go-Tool (YAML-konfiguriert) besser zum deklarativen NixOS-Ansatz als AdGuard. (Vorerst aber sekundär).

## Verworfene Ansätze (kurz)
- Pangolin, Zoraxy (verstoßen gegen Schichtentrennung)
- Authentik (zu schwergewichtig)
- caddy-ratelimit / caddy-security Plugins (Caddy soll flach bleiben)
- Vollständiger Umbau auf ein Zero-Trust-Gateway (bricht die etablierte Domain/Decimal-Logik)

## Ein-Satz-Fazit
Die Trennung in dedizierte, flache Dienste (Caddy, Pocket-ID, nftables) ist langfristig robuster, schlanker und wartbarer als verlockende, aber monolithische All-in-One-Lösungen.

## Netzwerkhygiene & Routertausch-Robustheit (LAN)
- **Keine hartcodierten LAN-IPs:** Um bei einem Routertausch oder Subnetz-Wechsel (z. B. von `192.168.178.x` auf `10.0.0.x`) nicht das ganze System debuggen zu müssen, sind statische LAN-IPs in den Configs tabu.
- **Caddy als einziger LAN-Einstieg:** Auch im Heimnetz binden alle Container/Dienste ausschließlich an Loopback (`127.0.0.1`). Der Zugriff erfolgt immer namensbasiert über Caddy (z. B. über Split-Horizon DNS oder Tailscale MagicDNS).
- **Subnetz-agnostisches Trust-Model:** Wenn Caddy LAN-Zugriffe authentifiziert oder freigibt, werden pauschal RFC1918-Ranges (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) sowie Tailscale (`100.64.0.0/10`) als "trusted" betrachtet, anstatt sich auf ein spezifisches Subnetz zu verlassen.
