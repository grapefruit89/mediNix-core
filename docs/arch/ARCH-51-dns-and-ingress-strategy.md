# Architecture Decision Record: DNS and Ingress Strategy (Domain 51)

## 1. Context and Problem Statement
The mediNix-core architecture exposes several services (media streaming, identity provider, administrative interfaces) to the internet and the local network. 
Choosing the correct DNS strategy, ACME challenge mechanism, and DNS provider is critical for maintaining security, preventing Man-in-the-Middle (MITM) attacks, ensuring high availability, and remaining compliant with Provider Terms of Service (ToS).

## 2. Decision: The "Grey Cloud" Principle
**Decision:** All mediNix-core services will operate strictly in "Grey Cloud" mode (DNS-only) when using providers like Cloudflare.

**Rationale:**
- **ToS Compliance:** Cloudflare's Terms of Service strictly prohibit proxying high-bandwidth streaming media (like Jellyfin) on their free tiers. Violating this risks arbitrary account suspension.
- **End-to-End Encryption:** By bypassing the proxy, TLS is terminated locally by our Caddy ingress using ACME DNS-01 challenges. This prevents the CDN from performing MITM on our traffic.
- **Decentralization & Jurisdiction:** Bypassing US-based corporate proxies ensures data sovereignty and prevents third-party data collection on streaming habits.

## 3. Decision: Anchor-DNS Architecture
**Decision:** We abandon per-service A-records in favor of an "Anchor-DNS" model.

**Rationale:**
- We manage exactly two A-records: `wan.domain` (Public IP) and `lan.domain` (Local IP).
- All services (e.g., `jellyfin.domain`, `sonarr.domain`) are provisioned as `CNAME` records pointing to the appropriate anchor based on their exposure tier (`stream`/`public`/`idp` -> `wan`; `internal` -> `lan`).
- This allows instantaneous failover and topology changes (e.g., changing ISPs or subnets) by updating only one or two A-records, immediately propagating to all 15+ subdomains.

## 4. DNS Provider Criteria
While Cloudflare is pragmatically used for its excellent API, the architecture strictly decouples the **Registrar** from the **DNS Provider**. 

If migration from Cloudflare is required, the target DNS provider MUST meet these criteria:
1. **API Quality:** Must be natively supported by `go-acme/lego` (used by NixOS `security.acme`).
2. **Fast Propagation:** Slow propagation causes ACME DNS-01 timeouts.
3. **Scoped Tokens:** Must support creating API tokens limited strictly to `Zone:Read` and `DNS:Edit` for least-privilege security.
4. **Viable Alternatives:** Providers like **deSEC.io** (Privacy/DSGVO, DNSSEC default), **INWX**, and **Hetzner DNS** are pre-approved architectural alternatives.

## 5. Host DNS Philosophy
**Decision:** The NixOS host itself will use Encrypted DNS (DoT) with a clear separation of concerns.

**Rationale:**
- Threat-Intel DNS (Malware/Phishing via Quad9/Cloudflare-Security) is handled upstream (e.g., via `services.resolved` with `DNSOverTLS=yes`).
- Local ad-blocking or content-blocking is left to the client browser (e.g., uBlock) rather than enforcing network-wide DNS sinkholes that break LAN resolution.
- Fallback resolvers are strictly defined to prevent bricking the host if the primary DoT provider fails.
