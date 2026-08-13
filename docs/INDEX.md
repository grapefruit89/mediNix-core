# mediNix-core Knowledge Base

Diese Dokumentation dient als Single Source of Truth (SSoT) für das mediNix-core Projekt. Sie ist als "OKF-light" Wiki für Agenten und Menschen aufgebaut.

## 🧭 Agent Routing (START HERE)

Bist du ein KI-Agent und sollst ein Modul bauen oder ändern? **Lies die entsprechenden Konzept-Seiten, bevor du Code schreibst:**

- **Storage & Laufwerke**: Lies [Storage & Mover](concepts/storage-mover.md)
- **Netzwerk & VPN (z.B. SABnzbd)**: Lies [VPN & Killswitch](concepts/vpn-killswitch.md)
- **Passwörter & API-Keys**: Lies [Secrets Management](concepts/secrets-systemd.md)

## 📚 Kategorien

Alle detaillierten Dokumente sind thematisch sortiert:

- **[Concepts (`concepts/`)](concepts/)**: Die wichtigsten Architektur-Synthesen (Agenten-Fokus).
- **[Architecture Decision Records (`adr/`)](adr/)**: Historische und verbindliche Design-Entscheidungen.
- **[Guides (`guides/`)](guides/)**: Anleitungen und Best-Practices.
- **[Patterns (`patterns/`)](patterns/)**: Wiederkehrende Code-Lösungen und Nix-Idiome.
- **[Architecture (`arch/`)](arch/)**: Tiefe Architekturdokumentation des Systems.
- **[Learnings (`learn/`)](learn/)**: Extrahierte Lektionen aus vergangenen Chat-Sessions.

*Tipp für Agenten: Die `ADR-5020` (Knowledge Extraction Pipeline) beschreibt, wie dieses Wiki aus Chats extrahiert wird.*
