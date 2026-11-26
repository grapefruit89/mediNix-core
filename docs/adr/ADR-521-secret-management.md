---
id: "ADR-521"
title: "ADR 5000 secret management"
domain: 52
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - secrets
  - security
links:
  adr: ""
  repo-harvest: ""
---
# ADR-521: mediNix Secret Management — sops-nix → systemd-credentials Migration (50-core)

## Status: active
## Date: 2026-08-11
## Source: Claude-Index (gold_final.json, 520-security), Grok "sops --> systemd creds"

## Context
User runs a single-server homelab (Unraid + NixOS). All credentials are rotatable
(API keys, DB passwords). sops-nix was evaluated but rejected: the encryption
overhead and key-management complexity do not fit a single-node setup where
secrets are already rotatable and the threat model is "family uses it, no prod
data".

## Decision
Use native **systemd credentials** (`LoadCredential=`, `SetCredential=`) instead
of sops-nix. Secrets live in `/etc/nixos/credentials/` (mode 600, owned by root),
passed to services via `systemd.services.<name>.serviceConfig.LoadCredential`.
No external KMS, no GPG/age keyring.

> [!CAUTION]
> **ANWEISUNG FÜR HERMES / AGENTEN:**
> `sops-nix` ist in diesem Projekt **STRIKT VERBOTEN**. Versuche niemals, `sops-nix` Module oder Pakete in die Konfiguration einzubauen. 
> Das finale Zielbild für Secrets in `mediNix-core` ist die Nutzung von **Systemd Credentials, die kryptografisch durch ein physisches TPM (Trusted Platform Module) gesichert sind**. Sämtliche Implementierungen müssen auf `LoadCredential` basieren.

## Consequences
- ✅ No sops binary, no age/GPG key management
- ✅ systemd-native, fits ADR-5000 (no docker/legacy tech)
- ✅ Credentials isolated per-service, not world-readable
- ✅ TPM-Hardware-Absicherung (Zukünftiges Ausbauziel)

## Gold-Standard (from chat)
> "Mo's constraints mean sops-nix doesn't really fit his use case—since all
> credentials are rotatable and he's working with a single node."
> → systemd-credentials is the idiomatic NixOS-native choice.

## HNDL-Risiko und systemd-creds
`.cred`-Dateien sind hardwaregebunden (TPM2 + Host-Key), aber nicht Post-Quantum-kryptografisch abgesichert (PQC). Ein Angreifer, der `.cred`-Dateien heute im Rahmen eines Harvest-Now-Decrypt-Later (HNDL)-Angriffs kopiert, kann sie in 10–20 Jahren entschlüsseln, sobald TPM2-Schlüssel oder asymmetrische Verfahren durch Quantencomputer gebrochen werden.

**Gegenmaßnahmen und Härtung:**
1. **Keine Veröffentlichung:** `.cred`-Dateien dürfen NIEMALS in öffentliche Repositories gelangen (abgesichert via `.gitignore`, private Repos oder lokale Offsite-Backups).
2. **Regelmäßige Rotation:** Alle Secrets und API-Keys mindestens alle 12 Monate rotieren.
3. **Lebensdauer-Begrenzung:** Nutzung von `--not-after=` bei `systemd-creds encrypt` zur automatischen Entwertung veralteter Ciphertexte.

*Quellen:* Chat-1-Block 04 (Entscheidung `D-04-03`) und `blocks/04-credentials-systemd-creds.json`.

## Nachtrag (2026-11): Secret-Contract & Sealed Credentials Härtung

Gemäß der Konsolidierung aus `docs/concepts/secrets-systemd.md`:
1. **Übergabe-Contract (`LoadCredentialEncrypted`):**
   - mediNix-Dienste laden versiegelte Secrets ausschließlich via `LoadCredentialEncrypted = [ "<key-name>:${cfg.secrets.<name>}" ];`.
   - Der Pfad im Dateisystem ist deterministisch `/run/credentials/<unit-name>/<key-name>` (`0400`, owned by service UID).
   - Kein Klartext-Speichern im Nix-Store (`/nix/store` ist world-readable!).
2. **Trennung von Verantwortung:**
   - mediNix-core definiert, *welche* Credentials ein Dienst benötigt und wie systemd sie isoliert.
   - Der Host (bzw. Bereitstellungs-Mechanismus) ist dafür verantwortlich, versiegelte `.cred`-Dateien (mittels TPM2 oder Host-Key) abzulegen.

---
