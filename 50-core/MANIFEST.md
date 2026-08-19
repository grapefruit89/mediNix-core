# mediNix-core: Architektur-Manifest (v1 – auditiert)

Dieses Dokument definiert die 5 auditierbaren Kernprinzipien von mediNix-core. Jedes zukünftige Modul und jeder Agent-Output muss gegen dieses Manifest geprüft werden.

## 1. Dendritische Modularität („Drop & Forget“)
Jeder Dienst lebt in einer eigenen Datei (\NNN-dienst.nix\). Er trägt seine komplette systemd-Unit, Hardening, Environment und Peer-Isolation selbst. Die zentrale \default.nix\ importiert nur über Zahlen-Präfixe. Löscht man die Datei, verschwindet der Dienst vollständig und fehlerfrei aus dem System – ohne Dateileichen in Caddy, Firewall oder Assertions.

## 2. Nix-Native & Zero-Container
Ausschließlich native \
ixpkgs\-Pakete + systemd. Docker, Podman, Compose und OCI-Runtime sind strikt verboten. Isolation erfolgt über systemd-Härtung, \RestrictNetworkInterfaces\, nftables und (bei Bedarf) Policy-Routing – nicht über Container-Netzwerke.

## 3. Single Source of Truth (SSoT) + Dezimalrahmen
Ports, UIDs, GIDs, caddyClass und Hardening-Profile kommen **ausschließlich** aus \lib/registry.nix\.
**Isomorphie:** \Port = UID = Service-Nummer × 10\.
Keine Hardcodes in Domain-Modulen. Die Registry ist die einzige Wahrheit.

## 4. Fail-Closed Security & Guardrails
Sicherheit ist der Default. Der VPN-Killswitch (Blackhole + Pre-Flight + BPF-Verifikation + kein ExecStop) und die nummerierten Assertions (\INV-*\ / \CODE-*\) lassen den Build bewusst scheitern, bevor unsichere Zustände entstehen. Secrets existieren nur als TPM-versiegelte Credentials (\LoadCredentialEncrypted\), niemals im Nix-Store.

## 5. Additive Host-Integration + Credential-First
Das Modul übernimmt weder die Host-Firewall noch physische Storage-Mounts. Es ergänzt nur (additive nftables, tmpfiles, optional MergerFS).
Alle Secrets und sensiblen Schlüssel werden ausschließlich über systemd-Credentials geladen. Der Host bleibt Herr der physischen Schicht.

---

### Audit-Regeln für Agenten & Entwickler:
- Verletzt es die Registry? → **Prinzip 3**
- Führt es Container oder Hardcodes ein? → **Prinzip 2 + 3**
- Ist es fail-open? → **Prinzip 4**
- Übernimmt es Host-Ressourcen? → **Prinzip 5**
- Ist es nicht dendritisch löschbar? → **Prinzip 1**
