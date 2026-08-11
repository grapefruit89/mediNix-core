# ADR-5000: mediNix Secret Management — sops-nix → systemd-credentials Migration (50-core)

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

## Consequences
- ✅ No sops binary, no age/GPG key management
- ✅ systemd-native, fits ADR-5000 (no docker/legacy tech)
- ✅ Credentials isolated per-service, not world-readable
- ⚠️ No secret rotation automation (acceptable: rotatable manually)

## Gold-Standard (from chat)
> "Mo's constraints mean sops-nix doesn't really fit his use case—since all
> credentials are rotatable and he's working with a single node."
> → systemd-credentials is the idiomatic NixOS-native choice.

---
