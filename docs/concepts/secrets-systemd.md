---
title: Secrets Management
type: Concept
---
# Secrets Management

**SSoT (Single Source of Truth) für Secrets in mediNix-core**

- **LoadCredential**: Das primäre und empfohlene Pattern für Secrets ist Systemd's `LoadCredential`.
- **Stufe TPM**: Hardware-gestützte Sicherheit via TPM2 wird angestrebt/verwendet, wo möglich.
- **Kein sops-Zwang**: Wir zwingen Modulen kein `sops-nix` auf, wenn einfache Systemd-Credentials ausreichen. SOPS ist oft Overkill für einfache Passwörter, die via Host-Provisionierung bereitgestellt werden können.
