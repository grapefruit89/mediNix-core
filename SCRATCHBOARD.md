---
status: active
type: log
tags: [scratchboard, staging, befund, governance]
summary: "Scratchboard: Eingang für Befunde, Bugs und Änderungswünsche. Erst Zeile erfassen, verifizieren, dann in Batches abarbeiten und verteilen."
---

# SCRATCHBOARD — Eingang für Befunde & Änderungswünsche

> **Regel R0:** Befunde immer zuerst ins Scratchboard — kein ungefragtes Direkt-Patching.
> Jede Beobachtung wird eine Zeile mit Typ, Bereich, Beleg und Status. Erst nach Review/Planung
> wird die Behebung chirurgisch umgesetzt und verifiziert.

---

## 1. Zeilen-Register

| ID | Typ | Bereich | Befund (1 Satz) | Beleg | Lösung / Ziel | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| K-01 | BUG | Ingress | Speedport-Credential überschreibt Cloudflare-Token per Attrset-Merge (`//`). | `513-ddns.nix:335-416` | Zusammenführung in eine einzige Liste `LoadCredentialEncrypted`; Ratsche `mediNix-ddns-speedport-multi-cred` | behoben |
| K-02 | BUG | Ingress/UPG | `517-oauth2-proxy.nix` fehlte Primärgruppe GID 5170 und Manifest-Eintrag. | `517-oauth2-proxy.nix` | `medinix.manifest.oauth2-proxy` registriert (Slot 517), UPG auto-abgeleitet; Ratsche `mediNix-oauth2-proxy-upg` | behoben |
| M-01 | RISK | Ingress | Globale `unauthenticatedPaths` umgehen Ack-Assertion auf Public-Vhosts. | `511-caddy.nix:294-297` | `publicBypassPaths` prüft nur vhost-spezifische `unauthenticatedPathsOf` | behoben |
| M-02 | GAP | Ingress | Port 53 (TCP/UDP) für LAN-Clients blockiert bei `firewall = "managed"`. | `515-blocky.nix` | Port 53 TCP/UDP automatisch in `allowedTCPPorts`/`allowedUDPPorts` geöffnet | behoben |
| M-03 | GAP | Ingress | Guardrail bricht Hosts mit legitimer `nftables`-Nutzung (`firewall = false`). | `519-ingress-guardrails.nix:31` | `keepOn.firewall` akzeptiert auch `networking.nftables.enable` | behoben |
| M-04 | RISK | Ingress | Cloudflare-Apex-Update könnte fremde Records ohne mediNix-Kommentar antasten. | `513-ddns.nix:151-163` | `update_record` filtert strikt auf `.comment == "managed-by=mediNix-core/513"` | behoben |
| B-01 | RISK | Core/Tooling | Nicht-kanonische Nix-Formatter (alejandra, nixpkgs-fmt) bergen Risiko für Format-Kriege und Ablenkung. | Resteküche & BANNED_TECHNOLOGIES.md | In `50-core/BANNED_TECHNOLOGIES.md` und `scripts/check_banned_technologies.py` sperren (SSoT: `nixfmt` / `nixfmt-rfc-style`) | behoben |
