# 51-ingress — map.md (Navigation)

> Verhalten & Invarianten: [`AGENTS.md`](AGENTS.md).
> Architektur & Betriebsanleitung: [`README.md`](README.md).
> Service-Attachment How-To: [`510-ingress-SERVICE.md`](510-ingress-SERVICE.md).
> Budget: ≤ 100 Zeilen / ≤ 700 Wörter / ≤ 5.500 Bytes (`LLM-ordnerstruktur` Baustein B).

## 1. Modul-Inventar

| Datei | Slot / Port | Rolle | Kurzbeschreibung |
|---|---|---|---|
| [`511-caddy.nix`](511-caddy.nix) | 511 / 80, 443 | Reverse Proxy | Wildcard-Proxy (`*.m7c5.de`), TLS-Offload, Forward-Auth Routing |
| [`512-pocket-id.nix`](512-pocket-id.nix) | 512 / 5120 | OIDC IdP | Native Pocket-ID Instanz, Passkeys, SQLite |
| [`513-ddns.nix`](513-ddns.nix) | 513 / — | DDNS Engine | Cloudflare DNS Update & Router-Integration |
| [`513-router-adapter-speedport.nix`](513-router-adapter-speedport.nix) | 513 / — | Hardware-Adapter | Speedport Smart 4 WAN-IP Extractor |
| [`514-acme.nix`](514-acme.nix) | 514 / — | Zertifikate | NixOS ACME/Lego DNS-01 Challenge via Cloudflare |
| [`515-blocky.nix`](515-blocky.nix) | 515 / 53 | Split-DNS | Blocky DNS Resolver (ersetzt mDNS/Avahi), LAN-Split-Horizon |
| [`516-crowdsec.nix`](516-crowdsec.nix) | 516 / — | Edge Bouncer | CrowdSec Firewall-Bouncer & LAPI Integration |
| [`517-oauth2-proxy.nix`](517-oauth2-proxy.nix) | 517 / 5170 | Auth Gateway | Forward-Auth Brücke zwischen Caddy (511) und Pocket-ID (512) |
| [`518-landingpage.nix`](518-landingpage.nix) | 518 / — | Dashboard | Homepage Service Tiles & Icons Rendering |
| [`519-ingress-guardrails.nix`](519-ingress-guardrails.nix) | 519 / — | Guardrails | Ingress-spezifische Assertions & Anti-Kollisions-Riegel |
| [`ingress-access.nix`](ingress-access.nix) | — | Helper (SSoT) | Single-Source-of-Truth für `accessGroupOf`, `isWan`, `caddyUnitOf` |
| [`510-ingress-SERVICE.md`](510-ingress-SERVICE.md) | 510 | How-To | Anleitung: Dienst an Caddy & Auth anbinden |

## 2. Task-to-File Matrix (Aufgabe → Datei zuerst)

| Aufgabe | Zuerst lesen | Dann / Kontext |
|---|---|---|
| Dienst an Caddy/Proxy anbinden | [`510-ingress-SERVICE.md`](510-ingress-SERVICE.md) | [`ingress-access.nix`](ingress-access.nix) |
| Caddy Reverse-Proxy / Routen anpassen | [`511-caddy.nix`](511-caddy.nix) | [`519-ingress-guardrails.nix`](519-ingress-guardrails.nix) |
| OIDC / Passkeys / SSO konfigurieren | [`512-pocket-id.nix`](512-pocket-id.nix) | [`517-oauth2-proxy.nix`](517-oauth2-proxy.nix) |
| Forward-Auth / Header-Strip prüfen | [`517-oauth2-proxy.nix`](517-oauth2-proxy.nix) | [`511-caddy.nix`](511-caddy.nix) |
| LAN-DNS / Split-Horizon / Adblock | [`515-blocky.nix`](515-blocky.nix) | [`511-caddy.nix`](511-caddy.nix) |
| WAN-IP / Cloudflare DDNS anpassen | [`513-ddns.nix`](513-ddns.nix) | [`513-router-adapter-speedport.nix`](513-router-adapter-speedport.nix) |
| Let's Encrypt / Wildcard-Zertifikate | [`514-acme.nix`](514-acme.nix) | [`511-caddy.nix`](511-caddy.nix) |
| Brute-Force / CrowdSec-Bouncer prüfen | [`516-crowdsec.nix`](516-crowdsec.nix) | [`519-ingress-guardrails.nix`](519-ingress-guardrails.nix) |
| Dashboard-Kacheln / Landingpage | [`518-landingpage.nix`](518-landingpage.nix) | [`510-ingress-SERVICE.md`](510-ingress-SERVICE.md) |
