# Backlog: NixOS Security Audit Report (Redundant SSO & Lockdown)

- **Datum:** 2026-10-26
- **Quelle:** `todo/_input/DeepSeek_NixOS-Security-Audit-Report_20261025-2331.json` (12 Nachrichten)
- **Status:** redundant
- **Thema:** Audit und Diskussion zu mynixos-v5 (SSO, Kernel Lockdown, CG-NAT, S3-Disaster-Recovery)

## Kernaussage
Diskussion der Sicherheitsarchitektur von `mynixos-v5`: Kernel Lockdown als informative Assertion (permissive), Passkey-only SSO mit Pocket ID und Caddy `forward_auth` (unter Verwerfung von Pangolin/Zoraxy), Erklärung von CG-NAT und Trennung von zustandslosem Rebuild und S3-Backup für Disaster Recovery.

## Bewertung & Grund für Backlog
Alle diskutierten Punkte sind in `mediNix-core` bereits verbindlich geregelt:
- Pocket ID + Caddy forward_auth via oauth2-proxy (`ADR-512`, `ADR-517`)
- Pangolin / Zoraxy / Nginx als Banned Technologies (`50-core/BANNED_TECHNOLOGIES.md`)
- Kernel Lockdown Handhabung (`ADR-5200`, Block 09)
- Restic/S3-Backup-Klassifizierung (`ADR-576`)
Kein neuer Handlungsbedarf.
