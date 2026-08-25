# ADR 5180: Minimal Static Landingpage & Honeypot

## Context
A central entry point (apex domain) is needed for guests to access exposed services (Jellyfin, Jellyseerr, Audiobookshelf). We need to prevent automated crawlers from discovering the subdomains and services, while simultaneously penalizing malicious bots.

## Decision
- **Minimal Static HTML:** The landing page is a single, static HTML file baked into the Nix store (`518-landingpage.nix`) and served by Caddy as a simple `file_server`.
- **No `href` links:** Navigation is handled via `data-go` attributes and a small JavaScript snippet that redirects the browser (`location.href = "/go/X"`). This prevents simple HTML parsers from extracting target URLs.
- **HTTP 302 Redirects over Path-Proxying:** Caddy intercepts `/go/X` routes and issues an HTTP 302 redirect to the respective subdomain (e.g., `jellyfin.domain.com`). We explicitly avoid `reverse_proxy` with `handle_path` here because path-routing frequently breaks WebSockets (e.g., in Audiobookshelf).
- **Log-based Honeypots:** The HTML contains hidden elements pointing to typical crawler targets (`/.env`, `/wp-admin`). Caddy naturally logs these as 404s. CrowdSec's `http-sensitive-files` scenario parses these logs and bans the offending IPs in `nftables` at Layer 3/4. We avoid building complex honeypot logic directly into Caddy.

## Consequences
- The web server configuration remains completely flat and declarative.
- Malicious scanners are automatically banned without exposing any actual backend infrastructure.
- Zero maintenance required for the landing page since it has no runtime dependencies.
- **Drop & Forget Compliance:** The entire landing page logic is firmly wrapped in a `config = lib.mkIf (config.medinix.enable)` check, ensuring that it cleanly vanishes if the media stack is disabled.
