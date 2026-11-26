---
id: "ARCH-51-cloudflare-zero-trust"
title: "ARCH 5100 cloudflare zero trust"
domain: 51
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - cloudflare
  - ingress
links:
  adr: ""
  repo-harvest: ""
---
# Architecture: Cloudflare Zero Trust Ingress

## 1. User Layer (KISS)
Dieses Dokument beschreibt, wie wir den Zugriff auf deinen Server von außen absichern. Anstatt einfach nur Ports zu öffnen (was gefährlich ist), nutzen wir Cloudflare als "Sicherheitsschleuse". Für Dienste wie dein Dashboard oder Nextcloud musst du dich erst bei Cloudflare (z.B. mit Google oder einem Code per E-Mail) anmelden, bevor du überhaupt zum Server durchgelassen wirst. Medien-Dienste (Jellyfin) laufen zur Performance-Steigerung direkt über deine IP, aber streng kontrolliert.

## 2. Technical Layer (Aviation-Grade)

### Dual-Path Ingress Strategie
Wir unterteilen den eingehenden Traffic in zwei Kategorien:

1.  **Proxied Path (High Security - Orange Cloud):**
    *   **Services:** Dashboard, Vaultwarden, n8n, Paperless.
    *   **Mechanismus:** Cloudflare Proxy -> Cloudflare Access (Zero Trust) -> Reverse Proxy (Caddy/Traefik).
    *   **Vorteil:** Deine echte IP bleibt versteckt. Cloudflare blockiert Bots und Angriffe, bevor sie deinen Server erreichen.
2.  **DNS-Only Path (High Performance - Grey Cloud):**
    *   **Services:** Jellyfin, Audiobookshelf.
    *   **Mechanismus:** Direkter DNS-Eintrag auf deine IP -> Reverse Proxy.
    *   **Absicherung:** IP-Allowlist (Heimnetz) oder VPN (WireGuard/Tailscale).

### Cloudflare Access (Zero Trust) Konfiguration
*   **Identity Provider (IdP):** Google OAuth (einfach) oder Pocket ID (OIDC - souverän).
*   **Policies:**
    *   **Admin-Dienste:** Zugriff nur für deine spezifische E-Mail-Adresse + mTLS Zertifikat.
    *   **Familien-Dienste:** Zugriff für definierte E-Mail-Adressen via One-Time PIN (OTP).

### Implementierung: Reverse Proxy (Caddy Snippet)
```caddy
# Beispiel für einen Dienst hinter Cloudflare Access
paperless.deinedomain.de {
    reverse_proxy localhost:20981
}
```

## 3. Reasoning Layer (History)

### [ADR-014] Cloudflare Access vs. Selbstgehostetes SSO (Authelia)
*   **Status:** Entschieden (März 2026).
*   **Kontext:** Ein selbstgehostetes SSO-System (wie Authelia oder Kanidm) ist komplex zu warten und stellt einen Single Point of Failure dar (wenn SSO tot, dann kein Zugriff auf Admin-Tools).
*   **Entscheidung:** Nutzung von Cloudflare Access für die äußere Sicherheitshülle.
*   **Vorteile:** Kostenlos für bis zu 50 Nutzer, hochverfügbar, unterstützt moderne Passkeys und mTLS ohne manuelles Zertifikats-Management auf dem Host.
*   **Konsequenzen:** Abhängigkeit von Cloudflare als Edge-Provider.

---
**Sources:**
*   `/home/Knowledge-Pipeline/raw/_duplikate/Claude-02 Homeserver mit Cloudflare sicher einrichten.md`
*   `/home/Knowledge-Pipeline/raw/_duplikate/Claude-Homeserver mit Cloudflare sicher einrichten (1).md`
