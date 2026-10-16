---
id: "GUIDE-52-hardening-secrets"
title: "GUIDE 52 — Sealed Secrets: systemd-creds statt sops/age"
domain: 52
status: active
complexity: 2
last_reviewed: 2026-10-17
tags:
  - hardening
  - secrets
  - security
links:
  adr: ""
  repo-harvest: ""
---
# 🛡️ Sealed Secrets: systemd-creds statt sops/age

Keine Geheimnisse im Klartext — und **kein** `sops-nix`, **kein** `agenix`
(`lib/creds.nix`: „No sops-nix, no agenix.").

Transport: **`LoadCredentialEncrypted`** (nicht das unverschlüsselte
`LoadCredential`).

## 📜 Der Contract (`lib/creds.nix`, durchgesetzt von `52-security/521-creds.nix`)
- Erwartet einen **systemd-creds-Blob**: `*.encrypted`, `*.cred`,
  `/etc/credstore.encrypted/…`.
- Default-Ablage: `/var/lib/medinix/secrets`.
- Klartext-Pfade werden zur **Eval-Zeit** abgewiesen: `dns.ddns.tokenFile`,
  `maintenance.backup.passwordFile`, `secrets.autoGenerate`.
- Blobs dürfen **nicht** unter `storage.mediaRoot` liegen (GID 5000 schreibbar).

## 🔁 Fluss
```
versiegelter Blob → LoadCredentialEncrypted → /run/credentials/<unit>/ → Dienst liest
```

## 🔑 Versiegeln
```bash
echo -n SECRET | sudo systemd-creds encrypt --name=<unit> - \
  /var/lib/medinix/secrets/<name>.encrypted
# oder: scripts/medinix-seal-secret.sh <name>
```

## 📌 Grenzen
TPM2 (`--with-key=tpm2+host`) ist eine **Host-Fähigkeit**, keine mediNix-Garantie.
`LoadCredentialEncrypted` ist ein **Transport**, kein vollständiges
Secrets-Management (Erzeugung/Rotation bleiben Host-Sache).

Quellen: `lib/creds.nix`, `52-security/521-creds.nix`, `52-security/README.md`,
`docs/concepts/secrets-systemd.md`.
