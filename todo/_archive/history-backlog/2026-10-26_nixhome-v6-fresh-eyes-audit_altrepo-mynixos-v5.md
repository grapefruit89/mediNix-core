# Backlog: NixHome v6.0 Fresh Eyes Audit (Altrepo mynixos-v5)

- **Datum:** 2026-10-26
- **Quelle:** `todo/_input/DeepSeek_NixHome-v6.0-Fresh-Eyes-Audit-Report_20261025-2331.json` (4 Nachrichten)
- **Status:** redundant / off-topic
- **Thema:** Audit des Vorgänger-Repositories mynixos-v5

## Kernaussage
Unabhängiges Review des Altrepos `mynixos-v5` vor dem ersten Dry-Build. Bemängelte einen Platzhalter-WireGuard-Key, einen Caddy-Admin-API-TCP-Konflikt, Reste alter Dienste (OliveTin) und eine fehlende Zero-Trust-Outbound-Firewall.

## Bewertung & Grund für Backlog
Betrifft das Vorgänger-Repository `mynixos-v5`. In `mediNix-core` sind diese Punkte längst überholt bzw. architektonisch sauber gelöst: Caddy nutzt UDS (`511-caddy.nix`), OliveTin existiert nicht mehr, und Outbound-Filterung ist über nftables/UID-Policy-Routing (`520-core-security.nix`, `526-vpn-killswitch.nix`) umgesetzt.
