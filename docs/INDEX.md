# mediNix Boilerplate — Documentation Index

Canonical, long-lived project decisions live here as ADRs (Architecture Decision
Records). Module-local patterns stay in the `.nix` files themselves.

## ADRs (Dezimalrahmen-konform: ADR-Nummer = Dienstnummer × 10)

### Verfassung & Querschnitt
| ADR | Dienst | Port | Title | Status |
|-----|--------|------|-------|--------|
| [ADR-0000](ADR-0000-dezimalrahmen-verfassung.md) | — | — | VERFASSUNG: Dezimalrahmen Nummernschema | accepted |
| [ADR-21](ADR-21-ssh-port-policy.md) | — | 22 | SSH canonical port 22 (high ports deprecated) | active |
| [ADR-5000](ADR-5000-secret-management.md) | 500 | 5000 | sops-nix → systemd-credentials migration | active |
| [ADR-5010](ADR-5010-nixgrok-architecture-review.md) | 501 | 5010 | Nix-Grok arch review, isomorphism validated | active |
| [ADR-5020](ADR-5020-knowledge-extraction-pipeline.md) | 502 | 5020 | Extraction pipeline (GitHub+chat→vector) | active |
| [ADR-5030](ADR-5030-flake-module-patterns.md) | 503 | 5030 | Flake & module patterns | active |
| [ADR-5040](ADR-5040-dezimalrahmen-port-ableitung.md) | 504 | 5040 | VERFASSUNGSKONFORME Port-Ableitung | active |
| [ADR-5043](ADR-5043-assertion-quality.md) | — | — | Assertion Quality Standard | active |
| [ADR-5050](ADR-5050-systemd-hardening-baseline.md) | 505 | 5050 | systemd hardening baseline (mkService) | active |

### Ingress (51)
| [ADR-5110](ADR-5110-caddy-reverse-proxy.md) | 511 | 5110 | Caddy reverse proxy | active |
| [ADR-5120](ADR-5120-pocket-id-oidc-module.md) | 512 | 5120 | Pocket ID OIDC module | active |
| [ADR-5130](ADR-5130-cloudflare-dns-no-proxy.md) | 513 | 5130 | Cloudflare DNS-only, no proxy | active |
| [ADR-5140](ADR-5140-oidc-auth-pocketid-authelia.md) | 514 | 5140 | OIDC SSO (Pocket ID + Authelia) | active |

### Security (52)
| [ADR-5200](ADR-5200-privesc-audit-hardening.md) | 520 | 5200 | PrivEsc audit & hardening | active |
| [ADR-5210](ADR-5210-nftables-firewall-baseline.md) | 521 | 5210 | nftables baseline, no iptables | active |

### Acquisition (53) / Transfer (54)
| [ADR-5320](ADR-5320-sonarr-series-management.md) | 532 | 5320 | Sonarr series management | active |
| [ADR-5410](ADR-5410-sabnzbd-vpn-confinement.md) | 541 | 5410 | SABnzbd VPN confinement | active |

### Playback (55) / Requests (56)
| [ADR-5510](ADR-5510-jellyfin-media-playback.md) | 551 | 5510 | Jellyfin media playback | active |
| [ADR-5520](ADR-5520-audiobookshelf-port-framework.md) | 552 | 5520 | Audiobookshelf port (decimal framework) | active |
| [ADR-5530](ADR-5530-navidrome-music-streaming.md) | 553 | 5530 | Navidrome music streaming | active |
| [ADR-5610](ADR-5610-jellyseerr-request-management.md) | 561 | 5610 | Jellyseerr request management | active |

### Maintenance (57)
| [ADR-5700](ADR-5700-sqlite-wal-tuning.md) | 570 | 5700 | SQLite WAL pragmas for *arr Tier B | active |
| [ADR-5710](ADR-5710-sqlite-mcp-server.md) | 571 | 5710 | SQLite MCP Server (FTS5+vector) | active |
| [ADR-5720](ADR-5720-backup-strategy.md) | 572 | 5720 | Backup Strategy (Borg/Restic) | active |

## Conventions
- ADRs use Schema V6 YAML frontmatter (`id`, `title`, `domain`, `status`,
  `last_reviewed`, `links`).
- **ADR-Nummer = Dienstnummer × 10** (Dezimalrahmen ADR-0000 §4).
  Schicht-Basis nutzt Ordner00 (z.B. 5000, 5700). Keine Laufnummern.
- UID = Port = ADR-Nummer. GID = 5000 (Projekt × 1000).
- `status`: proposed | active | deprecated | superseded.
- When an ADR is superseded, keep it (struck-through) and link the successor;
  never delete — history matters for a homelab you revisit months later.

## Open Items (nicht blockierend)
- ⚠️ Boilerplate `55-playback/` hat doppelte Struktur:
  flach (`551-jellyfin.nix`) + verschachtelt (`55-wiedergabe/551-jellyfin.nix`).
  ADR-0000 §9 lehnt Verschachtelung ab. Bereinigung nötig (nicht destruktiv).
- ⏳ v2-Vektorindex (Grok mit Textfeld) läuft nightly 4:00 — für vec-mcp Volltext.
