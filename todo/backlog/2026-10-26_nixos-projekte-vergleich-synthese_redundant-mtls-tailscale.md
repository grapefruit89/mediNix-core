# Backlog: NixOS Projekte Vergleich und Synthese (Redundant zu Chat 1 & Block 19)

- **Datum:** 2026-10-26
- **Quelle:** `todo/_input/DeepSeek_NixOS-Projekte-Vergleich-und-Synthese_20261025-2330.json` (42 Nachrichten)
- **Status:** redundant
- **Thema:** Synthese von mynixos-knowledge-base und mynixos-v5; mTLS-, Tailscale- und Secure-Boot-Diskussion

## Kernaussage
Diskussion über die Trennung von Wissensbasis und Implementierungs-Repo, das Zonenmodell (Loopback, Admin, Family/Public), die Abneigung gegen Tailscale sowie eine ausführliche Evaluation von mTLS (Client-Zertifikate im Browser/TPM) vs. Passkeys. Am Ende wird mTLS wegen enormer praktischer Hürden (CA-Handling auf Mobilgeräten) zugunsten von Pocket ID (Passkeys/WebAuthn) und BasicAuth für Admin verworfen; Secure Boot wird als zu riskant für Homelab abgelehnt.

## Bewertung & Grund für Backlog
Vollständig redundant zu Chat 1 (Blöcke 01, 04, 19), den ADRs (`ADR-0000`, `ADR-5000`, `ADR-512`, `ADR-517`) sowie dem Anti-Pattern-Register (`todo/antipatterns.md`: A-01 mTLS, A-02 Tailscale, A-03 Secure Boot). Kein neuer Erkenntnisgewinn oder Handlungsbedarf für mediNix-core.
