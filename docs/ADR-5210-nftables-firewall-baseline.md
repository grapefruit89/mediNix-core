# ADR-5210: nftables Firewall Baseline — Native, No iptables (52-security)

## Status: active
## Date: 2026-08-11
## Source: Claude gold_final.json (520-security/firewall, 30 chunks) + ADR-5043

## Context
User historically used `iptables -A INPUT ...` for quick port opens. This is
deprecated (ADR-5000 anti-deprecated). NixOS uses nftables natively.

## Decision
- Firewall via `networking.firewall` (nftables backend), NO `iptables` commands
- `allowedTCPPorts` declarative in mediNix modules
- Default DROP on WAN, allow LAN + VPN subnets
- SSH (22) + Backup-SSH (2222) only, key-only (ADR-21/595)

## Consequences
- ✅ Declarative, reproducible firewall
- ✅ No legacy iptables drift
- ✅ Fits ADR-5043 (systemd-native, no bash/iptables)

## Gold-Standard (from chat)
> "Firewall auf NixOS blockiert Port 4000. Kurz öffnen: iptables -A INPUT ..."
> → Anti-pattern: this is deprecated. Use `networking.firewall.allowedTCPPorts`.
