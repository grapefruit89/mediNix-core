---
id: 51-ingress
title: Ingress & Edge Domain
description: Manages reverse proxies, DNS, certificates, and authentication.
aliases: [Ingress, Edge, Caddy]
tags: [architecture, medinix, ingress, caddy, dns, acme, oidc]
---

# 51-ingress: Ingress & Edge Domain

The **Ingress Domain** (Domain 51) serves as the front door to mediNix-core. It handles routing, secure TLS termination, dynamic DNS updates, and centralized authentication (OIDC) for all underlying services. 

This domain uses a "Chameleon" architecture for the Caddy reverse proxy, seamlessly adapting to whether it runs as a standalone instance or injects its configuration into a global system-wide Caddy proxy.

## 🎯 Core Responsibilities

1. **Reverse Proxy & Routing:** Directing traffic to the correct internal services based on subdomains or local domains (`.local`).
2. **Access Control:** Enforcing strict network boundaries using `caddyClass` (e.g., isolating internal services to LAN-only).
3. **Authentication (OIDC):** Providing a centralized Identity Provider (IdP) for services that don't have built-in authentication or require a forward-auth wall.
4. **Certificate Management (TLS):** Automatically provisioning wildcard certificates via ACME DNS-01 challenges, ensuring services are secure without exposing ports 80/443 to the public internet.
5. **Dynamic DNS (DDNS):** Keeping public DNS records synced with the dynamic WAN IP, utilizing Split-Horizon logic so LAN clients route directly to local IPs.

## 🧩 Services in the Dezimalrahmen

| ID  | Service | Port/UID | Responsibility |
| :--- | :--- | :--- | :--- |
| **511** | [caddy](511-caddy.nix) <br> [[ADR-5110]] | `5110` | The "Chameleon" Caddy reverse proxy. Depending on the configuration, it either spins up a standalone `caddy-media` instance or injects its `virtualHosts` into the global NixOS Caddy service. |
| **512** | [pocket-id](512-pocket-id.nix) <br> [[ADR-5120]] | `5120` | **Pocket ID** — A self-hosted OIDC provider. Used by Caddy to perform `forward_auth` for services that require strict access control. |
| **513** | [cloudflare-dns](513-cloudflare-dns.nix) <br> [[ADR-5130]] | `5130` | **Split-Horizon DDNS**. It dynamically updates Cloudflare A-records. WAN services get the public IP, while LAN-only services get the internal LAN IP. Proxying (Orange Cloud) is strictly disabled to allow local TLS termination. |
| **514** | [acme](514-acme.nix) <br> [[ADR-5140]] | N/A | **Native NixOS ACME (Lego)**. Manages wildcard certificates (`*.domain.com`) using the Cloudflare API (DNS-01 challenge). Certificates are exclusively read by Caddy. |
| **515** | [mdns](515-mdns.nix) <br> [[ADR-5150]] | N/A | **mDNS Reflector**. Re-broadcasts mDNS packets across VLAN boundaries via Avahi, crucial for local discovery of casting devices across subnets. |
| **518** | [landingpage](518-landingpage.nix) <br> [[ADR-5180]] | N/A | **Static Landing Page**. A completely flat, statically compiled HTML dashboard (without Javascript hrefs) serving as a central hub and automated honeypot for CrowdSec bans. |

## 🛡️ Key Architecture Decisions

- **The Chameleon Pattern:** `511-caddy.nix` is designed not to fight with existing system configurations. If `services.caddy.enable` is true globally, mediNix-core peacefully injects its `virtualHosts`. If not, it provisions a highly hardened, standalone `caddy-media` service.
- **`caddyClass` Templating:** Service exposure is determined declaratively via `caddyClass` in the registry:
  - `stream`: No buffering (`flush_interval -1`), large timeouts, for Jellyfin/Plex.
  - `public`: Exposed to WAN + LAN with compression and optional forward authentication.
  - `internal`: Explicitly restricted to trusted LAN CIDRs (`192.168.x.x`, `10.x.x.x`). Traffic from outside the LAN is instantly aborted.
- **DNS-01 Challenges Over HTTP-01:** By utilizing the `security.acme` module with Cloudflare API tokens, certificates are obtained entirely via DNS manipulation. This means mediNix-core does **not** need to open port 80 to the internet, creating a zero-trust inbound firewall profile for LAN-only setups.
- **Blast Radius Reduction:** Secrets (like Cloudflare tokens) are injected securely via `LoadCredentialEncrypted` binding them to the TPM. Wildcard TLS keys belong exclusively to the Caddy process group, not the shared `media` group.
