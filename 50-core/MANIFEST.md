# mediNix-core: Architecture Manifesto

This document defines the 10 core architectural principles of the \mediNix-core\ NixOS configuration. It serves as the ultimate source of truth and contract for all developers and AI agents working on this codebase.

## 1. Dendritische Modularität ("Drop & Forget")
Das System ist in strikt abgegrenzte, flache Domänen (51 bis 59) unterteilt. Jedes Service-Modul (z.B. \532-sonarr.nix\) ist eine in sich geschlossene Einheit (Dendrit). Es trägt seine systemd-Unit, Härtung, sein Environment und seine Caddy-Klasse in sich. 
**Regel:** Wird eine Dienst-Datei gelöscht, verschwindet der Dienst spurlos aus dem System – ohne Fehler, ohne zurückbleibende Firewall-Regeln oder Proxy-Routen.

## 2. Dezimalrahmen & Isomorphe Identität
Die Architektur folgt strenger mathematischer Vorhersehbarkeit (siehe ADR-5043):
**\Port = UID = Service-Nummer × 10\**
Ein Dienst in der Datei \532-sonarr.nix\ hat zwingend die UID 5320 und den Port 5320. Das schafft eine sofortige mentale Zuordnung und verhindert Kollisionen by Design.

## 3. Nix-Native & Zero-Container Policy
Docker, Podman oder Compose-Files sind **strikt verboten**. Alle Dienste werden als native \
ixpkgs\-Pakete bezogen und via \systemd\ orchestriert. Dies eliminiert Container-Netzwerk-Overhead und ermöglicht tiefe Härtung auf Kernel-Ebene.

## 4. Single Source of Truth (SSoT)
Dienste agieren zwar dezentral, beziehen ihre "Wahrheit" (Port, UID, GID, caddyClass, stateDir) aber **ausschließlich** aus der zentralen Registry (\lib/registry.nix\). In den Modulen gibt es keine hardcodierten IDs oder Ports.

## 5. Credential-First / Store-Free Secrets
Es dürfen **niemals** Secrets (Passwörter, API-Keys, Private Keys) im Nix-Store landen. Alle sensiblen Daten werden kryptografisch sicher über systemd \LoadCredentialEncrypted\ (TPM-sealed) in die Dienste injiziert.

## 6. Fail-Closed Security & Guardrails
Die Architektur ist durch ein massives Netz an statischen Flake-Assertions (Guardrails in \59-guardrails\) geschützt. Ein Build bricht sofort ab, wenn Invarianten (z.B. falsche GID, Port-Kollision) verletzt werden.
Netzwerk-Sicherheit (z.B. der VPN-Killswitch) ist strikt **fail-closed** konzipiert (Blackhole-Routing statt IP-Leaks).

## 7. Peer-Isolation by Default
Durch die \service-factory\ und systemd-Direktiven wie \InaccessiblePaths\ laufen Dienste im **Least Privilege**-Modus. Sie sehen fremde State-Directories nicht, es sei denn, ein Peer (z.B. SABnzbd für Sonarr) wird explizit in \llowedPeers\ freigegeben.

## 8. Abstracted Storage & Tiering
Media-Dienste referenzieren niemals physische Festplatten (\/mnt/hdd\), sondern abstrakte logische Pfade (\cfg.storage.mediaRoot\). Die Komplexität des Storage-Tierings (heiße SSDs, kalte HDDs via MergerFS) wird zentral in der Maintenance-Domäne gekapselt.

## 9. Additive Host-Integration (No Takeover)
\mediNix-core\ respektiert den Host. Firewall-Regeln, sysctls und Mounts werden **additiv** konfiguriert, ohne die bestehende Host-Konfiguration gewaltsam zu überschreiben oder physische Platten-Mounts zu erzwingen.

## 10. Unix Socket First (Aspirational Goal)
Langfristiges Ziel: Wo immer Upstream-Software es unterstützt, wird Inter-Process-Communication über UDS statt lokaler TCP-Ports abgewickelt, um den Netzwerk-Stack zu umgehen und Berechtigungen über UMask zu steuern. (Aktuell dominiert noch TCP-Loopback).
