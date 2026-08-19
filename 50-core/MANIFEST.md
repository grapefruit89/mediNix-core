# mediNix-core: Architecture Manifesto (v1 - audited)

This document defines the 5 auditable core principles of \mediNix-core\. Every future module and every agent output must be evaluated against this manifesto.

## 1. Dendritic Modularity ("Drop & Forget")
Every service lives in its own dedicated file (\NNN-service.nix\). It carries its complete systemd unit, hardening, environment, and peer isolation internally. The central \default.nix\ imports these files based solely on their numerical prefix. If a file is deleted, the service vanishes completely and cleanly from the system – leaving no dead configuration in Caddy, the firewall, or assertions.

## 2. Nix-Native & Zero-Container
Strictly native \
ixpkgs\ packages + systemd. Docker, Podman, Compose, and OCI runtimes are strictly forbidden. Isolation is achieved via systemd hardening, \RestrictNetworkInterfaces\, nftables, and (if needed) policy routing – never via container networks.

## 3. Single Source of Truth (SSoT) + Decimal Framework
Ports, UIDs, GIDs, caddyClass, and hardening profiles are derived **exclusively** from \lib/registry.nix\.
**Isomorphism:** \Port = UID = Service-Number × 10\.
No hardcoded IDs in domain modules. The registry is the absolute and only truth.

## 4. Fail-Closed Security & Guardrails
Security is the default. The VPN killswitch (blackhole + pre-flight + BPF verification + no ExecStop) and the numbered assertions (\INV-*\ / \CODE-*\) intentionally fail the build before unsafe states can occur. Secrets exist only as TPM-sealed credentials (\LoadCredentialEncrypted\), never in the Nix store.

## 5. Additive Host-Integration + Credential-First
The module takes over neither the host firewall nor physical storage mounts. It only supplements them (additive nftables, tmpfiles, optional MergerFS).
All secrets and sensitive keys are loaded exclusively via systemd credentials. The host remains the absolute master of the physical layer.

---

### Audit Rules for Agents & Developers:
- Does it violate the registry? → **Principle 3**
- Does it introduce containers or hardcodes? → **Principle 2 + 3**
- Is it fail-open? → **Principle 4**
- Does it take over host resources? → **Principle 5**
- Is it NOT dendritically removable? → **Principle 1**
