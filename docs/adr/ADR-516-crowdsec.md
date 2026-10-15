---
id: "ADR-516-crowdsec"
title: "CrowdSec als einziger Edge-Bouncer (Engine + Firewall-Bouncer)"
domain: 51
status: active
complexity: 3
last_reviewed: 2026-10-15
tags:
  - ingress
  - security
  - bouncer
links:
  adr: ADR-0000 (Dezimalrahmen/Verfassung), ADR-511-caddy (Logs), ADR-513-cloudflare-dns (INGRESS-Muster)
  skill: medinix-module-author
---

# ADR-516: CrowdSec als einziger Edge-Bouncer

## Kontext

Der Ingress-Domäne fehlte ein Bouncer: `519` liess `fail2ban` bewusst unangetastet
(RT-3), weil `516` nicht existierte — der Rand hatte damit **keinen** aktiven
Bann-Mechanismus. Die Caddy-Access-Logs (511) existieren bereits als JSON im
journald.

## Entscheidung

1. **Genau ein Edge-Bouncer:** CrowdSec (**516**) ersetzt fail2ban. fail2ban gilt
   ab jetzt als Legacy (519, Legacy-Liste).
2. **Logquelle ist journald** — kein zweites Datei-Log, keine Rotation, keine
   doppelte Quelle. Acquisition: `_SYSTEMD_UNIT=caddy-media.service`,
   `labels.type = caddy`; Hub-Collection `crowdsecurity/caddy`
   (= Caddy-Parser + `base-http-scenarios`).
3. **Profile sind Pflicht.** Ohne Profil reagiert CrowdSec auf keine Entscheidung;
   `516` definiert deshalb ein Minimal-Profil (Ban, 4h) fuer `Alert.GetScope() == "Ip"`.
4. **Der Bouncer schreibt nftables nur bei Host-Verwaltung.** Er ist nur aktiv,
   wenn `medinix.hostIntegration.nftables = "managed"`; sonst bricht eine
   Assertion ab (fail-closed, „Publish-Don't-Apply"). Die Host-Pflicht steht in
   `docs/ADMIN-HANDOFF.md`.
5. **Regel-Teilung:** `503`/`520` liefern ausschliesslich die **Basis**-Firewall;
   Ban-Regeln kommen ausschliesslich aus `createRulesets` des Bouncers — eine
   Verantwortlichkeit pro Regelart.
6. **UPG:** Der Account `crowdsec` (UID = GID = **5160**) gehört der Engine;
   `systemd-journal` kommt ausschliesslich als `extraGroups` dazu
   (ADR-0000 §4: `media` nie als Primärgruppe, hier nicht einmal nötig).

## Konsequenzen

- Der Rand hat erstmals einen wirksamen Bann-Mechanismus (Engine + Bouncer).
- Ein zweiter Bann-Mechanismus (fail2ban) ist per Guardrail verboten.
- Ohne Hub-Netz beim ersten Start installiert `cscli` die Collection nicht —
  Logs werden dann nicht ausgewertet (beobachtbar ueber `cscli collections list`).
- Bei `hostIntegration.nftables != "managed"` muss der Host die Durchsetzung
  uebernehmen; die Entscheidung ist im Build erzwungen.
