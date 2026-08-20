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

## Ingress, Auth & App-Routing
- **Strikte Trennung Admin vs. Gäste:** Admin-Dienste (Radarr, Sonarr, Prowlarr) dürfen nicht ins WAN exponiert werden (`caddyClass = "internal"`). Gäste-Dienste (Jellyfin, Audiobookshelf) sind WAN-fähig, aber durch OIDC (Pocket-ID) und CrowdSec geschützt.
- **Root-Proxy statt Unterpfad-Hacks:** Bei Apps mit WebSockets (z. B. Audiobookshelf) wird konsequent auf Subdomains (`app.domain`) plus Root-Proxy gesetzt. Path-basiertes Routing (`handle_path`) verursacht oft den "drehenden Kreis" und ist zu meiden.
- **mTLS und Geoblock abgelehnt:** mTLS im Caddy ist für das Homelab im Betrieb (Client-Zertifikate verteilen) zu aufwendig und wird zugunsten von Pocket-ID verworfen. Geoblocking direkt in Caddy (Plugins) wird abgelehnt; falls nötig, erfolgt dies sauber auf L3/L4 (nftables/CrowdSec).

## Frontend & Landingpage (WAN-Einstieg)
- **Minimales statisches Dashboard:** Eine extrem leichtgewichtige HTML/SVG-Seite dient als zentraler Einstieg für Gäste. Keine "All-in-One"-Dashboards wie Homepage im WAN.
- **href-freies Routing:** Navigation erfolgt über `/go/1`, `/go/2` Caddy-Routes und `data-go`-Attribute mit minimalem JavaScript, um plumpe Crawler ins Leere laufen zu lassen. Keine sichtbaren URLs im Quelltext.
- **Honeypot via CrowdSec:** Die Seite enthält unsichtbare Honeypot-Elemente (z. B. auf `/.env` oder `/wp-admin`). Caddy leitet diese Aufrufe ab oder loggt sie schlicht als 404. CrowdSec liest das Log und vollstreckt einen harten L3/L4 Ban (z.B. für 12 Stunden) in `nftables`.
- **Anti-Overengineering:** Spielereien wie Klick-Erkennung durch den Webserver, 3-Pixel Bot-Fallen, Proof-of-Work oder Headless-Browser-Detection werden bewusst weggelassen. Der Webserver (Caddy) bleibt flach und dumm (nur `file_server`), der Schutz erfolgt auf Log-Ebene.

## Paketierung & Abhängigkeiten (Nix)
- **Verbot externer Flake-Inputs:** Externe Flake-Inputs (z.B. `github:user/repo`) bergen ein hohes Link-Rot-Risiko und den Verlust der Kontrolle (Upstream Changes). Wenn überhaupt eine Flake genutzt wird, muss sie als eigener Fork unter 100% eigener Kontrolle stehen. Klassische NixOS-Module bleiben der bevorzugte Hauptweg.

## App-Konfiguration & User-Management (am Beispiel Jellyfin)
- **OIDC/SSO statt lokaler Nutzer:** Nutzerverwaltung sollte zentral über den Identity Provider (Pocket-ID) laufen. Lokale App-Nutzer bergen das Risiko von "Configuration Drift" durch GUI-Änderungen (`mutable = true`).
- **Keine API-Hacks (`curl`) nach dem Start:** Imperative Post-Start-Skripte (`ExecStartPost = "curl ..."`) sind extrem anfällig für Race Conditions und State-Wars. API-Automatisierung ist nur als absolute, strikt idempotente Ausnahme erlaubt, falls es keine native deklarative Option oder SQLite-Lösung gibt.
- **Secrets & Remote-Access:** Secrets werden per `LoadCredential` in den Service-Kontext injiziert; Dateibasierte Secrets müssen saubere Ownership des Service-Users haben. Nativer Remote-Access innerhalb der Apps (z.B. Jellyfin WAN-Freigaben) bleibt deaktiviert, die Absicherung erfolgt zentral am Ingress (Caddy).

## Code-Struktur & Modularität (Das "Drop & Forget" Prinzip)
- **Eine Datei = Ein Dienst:** Module sind dendritisch aufgebaut. Löscht man `532-sonarr.nix`, ist der Dienst inklusive Firewall, User, und Ingress rückstandsfrei entfernt. 
- **Trennung von Code und Hardware:** Hardware-spezifische Dinge (Platten-UUIDs, Mounts, Netzwerkkarten) gehören isoliert nach `hosts/<name>/` und dürfen nicht in den generischen `mediNix-core` Modulen fest verdrahtet sein.
- **Pragmatismus vor Isomorphie-Dogma:** Factories (`mkService`) werden genutzt, wo sie Boilerplate sparen. Eine extreme, mathematische 1:1:1-Isomorphie (jedes Modul erzwingt zwingend eine eigene ADR und einen Guide) wird als Over-Engineering abgelehnt. Dokumentiert (ADRs) wird nur dort, wo echte Architekturentscheidungen getroffen werden.

## Secrets, DNS & Abwehr von "Agenten-Theater"
- **Single Source of Truth für Secrets:** API-Keys und Passwörter gehören zentral in den Secret-Store (`LoadCredential`) und werden niemals verstreut in Klartext-Configdateien geschrieben. 
- **DNS Local-First:** Lokale Dienste sprechen sich primär über `127.0.0.1` oder interne DNS-Zonen an, bevor sie externe Wege (Cloudflare-Tunnel etc.) nehmen.
- **Anti-Buzzword-Policy:** Architekturkonzepte wie "Sovereign Loops", "Aviation-Grade XML-Repairs" oder überkomplexe "Network-Namespace-Blasen" (wie in alten nixflix-Iterationen) werden als unpraktikables Agenten-Theater verworfen. Stattdessen zählt robuste, idempontente Python-Automatisierung, die ohne wildes `sed`/`xmlstarlet` oder wackelige MCP-Tricks auskommt.

## Wissensmanagement, Flakes & Guardrails
- **Host-spezifische Defaults vermeiden:** Globale Optionen dürfen keine host-spezifischen Defaults (wie bestimmte Hardware-Pfade) enthalten, um "Silent Inheritance" (stille Vererbung) zu verhindern.
- **Secrets-Guardrail (INV-SECRET):** Secrets dürfen niemals im Nix-Store landen. Die Nutzung von `LoadCredential` ist Pflicht. (Hinweis: Path-basierte Flake-Evaluation umgeht `.gitignore` und birgt ein hohes Leak-Risiko!).
- **Originalwissen erhalten:** Originale Chat-Exporte oder Wissensdokumente werden nie überschrieben. Es wird immer konsolidiert, zusammengefasst (wie in diesem Dokument) und historisch archiviert. Verworfene Ansätze (Graveyard) bewusst dokumentieren, um alte Fehler nicht zu wiederholen.
