---
id: "ONBOARDING"
title: "mediNix-core — Architektur & Onboarding Guide"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-10-12
tags:
  - architecture
  - onboarding
  - invariants
  - security
links:
  adr: ADR-0000
---

# mediNix-core — Architektur & Onboarding Guide

Willkommen bei `mediNix-core`. Dieses Repository ist kein herkömmliches "Docker-Compose-Ersatzlager", sondern eine **containerfreie, deklarative, dendritisch organisierte Linux-Plattform**.

Bevor du Änderungen vornimmst oder neue Dienste anlegst, musst du die folgenden Grundgesetze verstehen. Verletzungen dieser Gesetze führen zu Compile-Time-Abbrüchen durch NixOS-Assertions.

---

## 1. Die Goldenen Gesetze (Invariante Architektur)

1. **Zero Containers:** 
   Wir nutzen weder Docker, Podman noch Container-Bridges. Dienste laufen als native systemd-Services mit strikten Härtungsprofilen (`ProtectSystem=strict`, `DynamicUser` oder dezimale UIDs, systemd-Sandboxing).
2. **Dezimalrahmen (Single Source of Truth):**
   Jeder Dienst besitzt eine deterministische Modul-ID `5xx` aus `lib/registry.nix`:
   - `Port = UID = Modul-ID × 10` (z. B. Sonarr: ID 532 -> UID 5320 -> Port 5320).
   - Manuelle, willkürliche Portvergaben sind strikt verboten.
3. **Drop-a-File (Pub/Sub via Manifest):**
   Ein Dienst registriert sich über `config.medinix.manifest.<svc>`.
   Konsumenten (Caddy für Ingress, Gatus für Monitoring, VictoriaMetrics-Exporter, Landingpage) lesen **ausschließlich** das Manifest (`schemaVersion = 1`). Ein Dienst wird gelöscht, indem seine Datei entfernt wird – es bleiben keine Restkonfigurationen zurück.
4. **Keine Network Namespaces (`netns`):**
   Network Namespaces (`PrivateNetwork=true`, veth-Pairs) sind verboten (ADR-0011). VPN-Confinement erfolgt ausschließlich über UID-basiertes nftables-Routing (`meta skuid`).
5. **ADR-0010 (Boot-Seeds vs. REST-API):**
   - **Dateisystem / Seeds:** Nur für Boot-Infrastruktur (Ports, DB-Pragmas, Wizard-Bypässe wie `system.xml`).
   - **REST-API:** Für die Fachlogik (Bibliotheken, User, Root-Folders). Niemals direkte SQL-Eingriffe in laufende Datenbanken!

---

## 2. Der Host-Vertrag (`medinix.host.*`)

`mediNix-core` ist ein Service-Modul. Es schreibt dem Host weder Zeitzone, Tastaturlayout noch MOTD vor. 
Für die Außenanbindung verlangt es lediglich:

```nix
medinix.host = {
  domain = "deine-domain.tld";      # Pflicht: Valide Unicast-Domain
  adminEmail = "admin@domain.tld";   # Pflicht: Valide E-Mail für ACME/Let's Encrypt
};
```

---

## 3. Das VPN-Confinement (SABnzbd & Usenet)

* **SABnzbd (UID 5410)** ist der **einzige** Dienst, der durch das WireGuard-VPN geroutet wird.
* Es gibt kein Torrenting und keine anderen VPN-Dienste im System.
* **Localhost-Bypass:** SABnzbd lauscht auf `127.0.0.1:5410`. Lokaler Traffic (`lo`) ist vom VPN ausgenommen, damit Sonarr/Radarr die API ungehindert steuern können.
* **Kernel-Routing:** `networking.firewall.checkReversePath` muss auf `"loose"` stehen, um asymmetrische Drops im WireGuard-Rückpfad zu verhindern.
* **DNS-Leak-Schutz:** SABnzbd erhält eine isolierte `resolv.conf`, die ausschließlich die VPN-DNS-Server nutzt.

---

## 4. Secrets einrichten (TPM2-Workflow)

Alle Secrets werden mit **TPM2 verschlüsselt** und als `.cred`-Dateien gespeichert.
Die `.cred`-Dateien können ins Git-Repo — sie sind ohne dieses spezifische TPM wertlos.

### Workflow
```bash
# 1. Secret als Plaintext vorbereiten (nur kurz, dann shredden)
echo "mein-secret-wert" > /tmp/secret.txt

# 2. Mit TPM verschlüsseln
systemd-creds encrypt --with-key=tpm2+host \
  /tmp/secret.txt \
  /var/lib/systemd/credential.d/mediNix-secret.cred

# 3. Plaintext sicher löschen
shred -u /tmp/secret.txt

# 4. In der Konfiguration referenzieren (nie den Klartext!)
```

### INV-SECRET (Build-Zeit-Garantie)
Kein Secret-Pfad darf im Nix-Store liegen (`/nix/store/...`). `591-cross-domain.nix` prüft das via `INV-SECRET`-Invariante. Ein Verstoß bricht den Build sofort ab.
