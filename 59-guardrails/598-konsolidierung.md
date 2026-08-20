# ---
# id: "598-konsolidierung"
# title: "SRE Findings & Architecture Registry (Konsolidierung)"
# domain: 59
# folder: 59-guardrails
# ---

# mediNix-core: Architecture Findings & Konsolidierung

Dieses Dokument fungiert als institutionelles Gedächtnis des mediNix-core Projekts. 
Es dokumentiert **verworfenen Architekturen**, **bewusste Design-Entscheidungen** und **verhinderte Anti-Patterns**, damit sie bei künftigen Refactorings nicht versehentlich wiederholt werden.

---

## 1. Storage: Warum kein `mergerfs`?
**Entscheidung:** Strikte Ablehnung von `mergerfs` für Medien-HDDs.
**Rationale:** `mergerfs` weckt bei Suchanfragen und Metadaten-Scans grundsätzlich *alle* verknüpften Festplatten auf. Dies zerstört das Ziel eines energieeffizienten Spindowns (Festplatten-Standby). 
**Lösung:** Direkte, separate Mountpoints für HDDs. Das Tiering-Skript (Mover) verschiebt Daten physisch auf die korrekte Disk.

## 2. Storage: Atomic Moves & Staging
**Entscheidung:** Medien werden beim Verschieben von SSD (Staging) auf HDD (Archiv) niemals direkt ins Zielverzeichnis kopiert.
**Rationale:** Ein Kopierprozess über Dateisystemgrenzen hinweg (`mv` von SSD auf HDD) ist nicht atomar. Ein Media-Scanner (Jellyfin/Plex) könnte die Datei scannen, während sie erst zu 40% geschrieben ist. Dies führt zu korrupten Metadaten und Abspielfehlern.
**Lösung:** Der Mover (`543-mover.nix`) kopiert die Datei zuerst in ein `.staging_mover/`-Verzeichnis **auf derselben Ziel-HDD**. Der finale Schritt in den Media-Ordner ist ein atomares Rename (`mv`), das in Millisekunden geschieht.

## 3. Network: VPN-Killswitch vs. Network Namespace
**Entscheidung:** Nutzung eines hybriden Killswitches (eBPF + fwmark + policy routing) anstelle von voll-isolierten Network Namespaces.
**Rationale:** Voll-isolierte Netns sind sicherer, machen aber lokales Management, DNS-Auflösung und Caddy-Reverse-Proxy-Integration extrem komplex.
**Lösung:** Die aktuelle Lösung in `526-vpn-killswitch.nix` markiert Traffic basierend auf der UID. Wichtig: Die zugehörigen Hardening-Profile (`python` etc.) **müssen** `networkPolicy.internet` erlauben, da sonst eBPF den Traffic blockiert, bevor die nftables-Killswitch-Regeln greifen können.

## 4. Security: Tiered Authentication
**Entscheidung:** Strikte Trennung der Authentifizierungs-Ebenen.
**Rationale:** Nicht jeder Dienst benötigt einen öffentlichen IdP.
**Lösung:** 
- **Tier 0/1 (Interne Admin-Tools):** Authentifizierung primär über Tailscale (`tsidp`). Wer im Tailnet ist, ist authentifiziert.
- **Tier 2 (Externe Nutzer):** Zugriff über Caddy mit Forward-Auth (Pocket-ID / Passkeys).
- **Tier 3 (Vaultwarden etc.):** Absichtlich **nicht** an den zentralen IdP angebunden, um bei einer Kompromittierung des IdPs nicht die Passwörter zu gefährden.

## 5. Security: Ntfy & Watchdogs
**Entscheidung:** Interne Alarme dürfen nicht von Auth-Mechanismen blockiert werden.
**Rationale:** Wenn ntfy auf `deny-all` ohne Tokens steht, können Watchdogs und Runtime-Guards keine Alarme senden, wenn das System kompromittiert ist.
**Lösung:** Ntfy läuft intern (via Caddy `accessGroup = "internal"` geschützt) und erlaubt lokalen `read-write` Zugriff für System-Dienste, um Fail-Closed-Zustände im Alerting zu vermeiden.

## 6. SSoT: Die Registry & Guardrails
**Entscheidung:** Ports, UIDs und StateDirs dürfen niemals hartcodiert werden.
**Rationale:** Hartcodierte Werte führen unweigerlich zu State-Wars (z.B. wenn das Provisioning-Skript und das CLI unterschiedliche Pfade erwarten).
**Lösung:** Alles wird zentral aus `lib/registry.nix` bezogen. Die Guardrails in Domain 59 überprüfen mathematisch (`lib.unique`), ob es zu Port- oder UID-Kollisionen kommt.
