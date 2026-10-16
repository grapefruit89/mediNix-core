---
id: "ADR-514"
title: "TLS-Zertifikate: Lego + Cloudflare DNS-01 mit eigenem Token"
status: active
complexity: 2
last_reviewed: 2026-10-16
links:
  adr: ADR-513 (Cloudflare-DDNS), ADR-521 (sealed Credentials), ADR-511 (Ingress)
---

# ADR-514: TLS-Zertifikate - Lego + Cloudflare DNS-01 mit eigenem Token

## Kontext
Der Ingress (511) braucht Zertifikate, auch fuer Wildcards (`*.{domain}`). Die Zone liegt bei
Cloudflare; Port 80 ist im LAN-only-Aufbau nicht offen.

## Entscheidung
- Ausstellung ueber **Lego** (nixpkgs-ACME) mit **Cloudflare DNS-01** - DNS-01 ist der einzige
  Weg, der ohne offenen Port 80 auch Wildcards abdeckt.
- Ein **eigener** Cloudflare-Token fuer ACME, **nie** der DDNS-Token (513). Scope: `Zone:DNS:Edit`
  nur auf diese Zone (TXT `_acme-challenge`). Ein DDNS-Kompromiss darf die TLS-Ausstellung nicht
  brechen.
- **Kein `tokenFile`**: der Token kommt als **sealed Credential** (`LoadCredentialEncrypted`,
  ADR-521) ueber eine eigene EnvironmentFile; die Option heisst `ingress.tls.acmeCredential`.
- Lego-/Cloudflare-Tuning (DNS-Resolver etc.) liegt in einer eigenen, **secret-freien** Env-Datei.
- Auslieferung als Unit-Template `acme-<host>`, gehaertet ueber das `network`-Profil.

## Begruendung (aus der Historie)
- `security.acme.certs.<name>.environment` (Map) existiert in nixpkgs **nicht** - es ist
  `environmentFile` (Pfad). Der fruehere `environment = { CLOUDFLARE_* }`-Block brach die
  `acmeHost`-Auswertung (F6-Fund) und wurde ersetzt.
- HTTP-01 scheidet im LAN-only-Aufbau aus; DNS-01 passt zur bestehenden Cloudflare-Anbindung.

## Konsequenzen
- Zwei getrennt rotierbare Tokens (ACME, DDNS): etwas mehr Pflege, deutlich kleinerer Blast-Radius.
- Ein Zonen-Token reicht fuer alle Hosts der Zone; neue vhosts brauchen kein neues Secret.
