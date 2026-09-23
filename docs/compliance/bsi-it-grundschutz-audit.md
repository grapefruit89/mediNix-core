---
id: "bsi-it-grundschutz-audit"
title: "BSI IT-Grundschutz Compliance Audit (SYS.1.3, NET.1.1, NET.3.2)"
domain: 52
folder: docs/compliance
status: active
complexity: 3
last_reviewed: 2026-09-18
tags:
  - compliance
  - bsi-grundschutz
  - audit
  - hardening
  - architecture
links:
  adr: ADR-0000, ADR-5050, ADR-5210, ADR-526
---

# BSI IT-Grundschutz Compliance Audit

**Referenz-Ausgabe:** BSI IT-Grundschutz-Kompendium Edition 2023  
**Geltungsbereich:** mediNix Host (`q958`) & mediNix Modul-Architektur  
**Primärquellen-Archiv:** `/home/moritz/Obsidian/standards/` (lokal auf Nobara archiviert)

---

## 1. Übersicht & Architektur-Zusammenhang

Dieses Audit belegt schwarz auf weiß, wie die deklarative NixOS-Architektur und der **Dezimalrahmen (ADR-0000)** die Sicherheitsanforderungen des Bundesamtes für Sicherheit in der Informationstechnik (BSI) nicht durch nachträgliche Skripte („Pflaster“), sondern **konstruktiv per Design (Security by Design)** erfüllen.

Drei Kern-Bausteine des BSI-Kompendiums werden direkt adressiert:
1. **SYS.1.3 — Server unter Linux und Unix (Edition 2023)**
2. **NET.1.1 — Netzarchitektur und -design (Edition 2023)**
3. **NET.3.2 — Firewall (Edition 2023)**

---

## 2. BSI SYS.1.3 — Server unter Linux und Unix

| Anforderung | Schutzstufe | Technische Umsetzung in mediNix / NixOS | Verifikation / Beleg |
|---|---|---|---|
| **SYS.1.3.A2** Sorgfältige Vergabe von IDs | **Basis (MUSS)** | **Dezimalrahmen (ADR-0000):** Mathematisch kollisionsfreie Ableitung $\text{UID} = \text{Port} = N \times 10$. Projektweite GID $5000$ (`media`). Keine doppelten UIDs/GIDs im Systemverbund möglich. DynamicUser ist strikt verboten. | `lib/registry.nix`, `configuration.nix` |
| **SYS.1.3.A4** Schutz vor Schwachstellen-Ausnutzung | **Basis (MUSS)** | ASLR, DEP/NX und Kernel-Härtung sind nativ im Linux-Kernel aktiv. `hardware.graphics` nutzt isolierte Render-Nodes (`/dev/dri/renderD128`). Standard-libc Heap-/Stack-Protector aktiv. | `hardware-configuration.nix`, `lib/hardening-profiles.nix` |
| **SYS.1.3.A5** Sichere Installation von Software-Paketen | **Basis (MUSS)** | **Nix Flakes:** Quellcode-Builds erfolgen ausnahmslos in unprivilegierter Sandbox. Das Wurzeldateisystem ist unbeschreibbar (`/nix/store` ist read-only). Builds sind kryptografisch reproduzierbar gehasht. | `flake.nix`, `flake.lock` |
| **SYS.1.3.A6** Verwaltung von Benutzenden und Gruppen | **Standard (SOLL)** | Reine deklarative Verwaltung via NixOS (`users.users`, `users.groups`). Kein fehleranfälliges manuelles Editieren von `/etc/passwd`, `/etc/shadow` oder `/etc/sudoers`. | `configuration.nix`, `520-core-security.nix` |
| **SYS.1.3.A8** Verschlüsselter Zugriff über Secure Shell (SSH) | **Standard (SOLL)** | Key-Only SSH via Ed25519-Schlüssel. `PasswordAuthentication = false`. Root-Login ist strikt verboten (`PermitRootLogin = "no"`). | `configuration.nix` |
| **SYS.1.3.A10** Verhinderung der Ausbreitung bei Schwachstellen | **Standard (SOLL)** | Native systemd-Sandbox pro Service: `ProtectSystem = "strict"`, `ProtectHome = true`, `PrivateTmp = true`, `NoNewPrivileges = true`, `RestrictNamespaces = true`. | `lib/hardening-profiles.nix`, `lib/service-factory.nix` |
| **SYS.1.3.A14** Verhinderung des Ausspähens von Informationen | **Erhöhter Bedarf (H)** | `ProtectProc = "invisible"`, `ProcSubset = "pid"`, `InaccessiblePaths = [ "/root" "/home" "/boot" "/etc/shadow" "/etc/ssh" "/run/secrets" ]`. Keine sensiblen Parameter in CLI-Befehlen (systemd-creds). | `lib/hardening-profiles.nix`, `521-creds.nix` |
| **SYS.1.3.A16** Zusätzliche Ausbreitungsverhinderung (Syscalls) | **Erhöhter Bedarf (H)** | Seccomp System Call Filtering: `SystemCallFilter = [ "@system-service" "~@privileged" ]`, `SystemCallErrorNumber = "EPERM"`, `SystemCallArchitectures = [ "native" ]`. | `lib/hardening-profiles.nix` |
| **SYS.1.3.A17** Zusätzlicher Schutz des Kernels | **Erhöhter Bedarf (H)** | `recommended.sysctl`: `kernel.kexec_load_disabled = 1`, `kernel.kptr_restrict = 2`, `kernel.dmesg_restrict = 1`, `kernel.yama.ptrace_scope = 1`, `fs.protected_hardlinks = 1`, `fs.protected_symlinks = 1`. | `520-core-security.nix`, `modules/hardening-host.nix` |

*Hinweis zu entfallenen Anforderungen:* Gemäß BSI Edition 2023 sind die Anforderungen A1, A7, A9, A11, A12, A13 und A15 offiziell **entfallen**.

---

## 3. BSI NET.1.1 — Netzarchitektur und -design

| Anforderung | Schutzstufe | Technische Umsetzung in mediNix / NixOS | Verifikation / Beleg |
|---|---|---|---|
| **NET.1.1.A1** Sicherheitsrichtlinie für das Netz | **Basis (MUSS)** | Formale Dokumentation aller Netzbeziehungen und Interfaces in ADR-0000, ADR-526 und `network-topology.md`. | `docs/adr/ADR-0000-dezimalrahmen-verfassung.md` |
| **NET.1.1.A21** Zonierung & Trennung des Managementbereichs | **Standard (SOLL)** | **Strikte Drei-Zonen-Teilung:**<br>1. *WAN-Zone:* Nur Caddy Reverse-Proxy (`511`) hört auf Port 80/443.<br>2. *Backend-Zone:* Alle Mediendienste binden ausschließlich auf `127.0.0.1:<Port>` oder UNIX-Sockets.<br>3. *Management-Zone:* SSH nur für Admin `medinix` via LAN. | `lib/hardening-profiles.nix`, `51-ingress/` |
| **NET.1.1.A22 & A23** Segmentierungskonzept & Schutzbedarfs-Trennung | **Standard (SOLL)** | **Die 3 Netzwerkklassen:**<br>• `loopbackOnly`: `{ RestrictNetworkInterfaces = ["lo"]; IPAddressDeny = ["any"]; IPAddressAllow = ["127.0.0.1/32"]; }`<br>• `vpnConfined`: SABnzbd (`541`) isoliert auf `lo` + WireGuard.<br>• `wanClient`: Gesteuerte WAN-Verbindungen für Indexer/Metadata. | `lib/hardening-profiles.nix` |
| **NET.1.1.A33** Mikrosegmentierung des Netzes | **Erhöhter Bedarf (H)** | systemd-native Mikrosegmentierung auf Prozess-Ebene (`SocketBindDeny = "any"`, `SocketBindAllow = "ipv4:tcp:127.0.0.1:<Port>"`). Kein Dienst kann fremde Ports öffnen. | `lib/service-factory.nix` |
| **NET.1.1.A34** Kryptografische Verfahren auf Netzebene | **Erhöhter Bedarf (H)** | WireGuard Kernel-Tunnel (`525-vpn-interface.nix`, ChaCha20-Poly1305) für sämtlichen Downloader-Verkehr. | `525-vpn-interface.nix`, `526-vpn-killswitch.nix` |

---

## 4. BSI NET.3.2 — Firewall & Paketfilter

| Anforderung | Schutzstufe | Technische Umsetzung in mediNix / NixOS | Verifikation / Beleg |
|---|---|---|---|
| **NET.3.2.A12** Minimales Regelwerk & Default-Deny | **Standard (SOLL)** | **Fail-Closed Killswitch:** nftables Policy-Routing markiert Pakete nach UID (`meta skuid 5410 mark set 51820`). Routing-Tabelle 51820 ist standardmäßig `unreachable`. Bricht der Tunnel ab, droppt der Linux-Kernel Pakete sofort. | `526-vpn-killswitch.nix` |
| **NET.3.2.A16** Sicherheitsproxy auf Anwendungsschicht | **Standard (SOLL)** | Caddy Reverse-Proxy (`511`) fungiert als zentraler Application Proxy mit automatischer TLS-Terminierung (ACME), HTTP/2 und HTTP/3. Backend-Dienste sind von außen unadressierbar. | `51-ingress/511-caddy.nix` |
| **NET.3.2.A19** Schutz vor TCP SYN Flooding & Attacken | **Standard (SOLL)** | Sysctl-Härtung: SYN-Cookies aktiv, IP-Forwarding deaktiviert, Quell-Routing verboten (`net.ipv4.conf.all.accept_source_route = 0`), Reverse Path Filtering aktiv (`rp_filter = 2`). | `520-core-security.nix`, `modules/hardening-host.nix` |
| **NET.3.2.A20** Absicherung von DNS & Internetprotokollen | **Standard (SOLL)** | Blocky DNS-Sinkhole auf `127.0.0.1:53`: Alle DNS-Anfragen laufen verschlüsselt via DNS-over-HTTPS (DoH, Quad9) und filtern Tracker/Malware auf Kernel-Ebene. | `modules/blocky.nix` |
| **NET.3.2.A22** Sichere Zeitsynchronisation | **Standard (SOLL)** | Chrony NTS (`modules/chrony-nts.nix`): Network Time Security synchronisiert die Systemzeit kryptografisch gesichert mit TLS-Zertifikaten (Cloudflare / PTB) – immun gegen NTP-Spoofing. | `modules/chrony-nts.nix` |
| **NET.3.2.A25** Integritätsschutz der Konfigurationsdateien | **Erhöhter Bedarf (H)** | Sämtliche Firewall- und Routing-Regeln sind als Nix-Store-Pfade deklariert. Ein Neustart oder Absturz lädt immer exakt die unveränderliche, kryptografisch geprüfte Konfiguration. Konfigurations-Drift ist unmöglich. | `flake.nix` |

---

## 5. Fazit & Revisions-Sicherheit

Der **Dezimalrahmen (ADR-0000)** dient in diesem Gefüge als formale Verfassung:
* Er garantiert strukturell die Einhaltung von **SYS.1.3.A2** (kollisionsfreie UIDs).
* Er verhindert privilegierte Ports (**NET.3.2.A12**) durch die mathematische Schranke $H110 \ge 1110 > 1023$.
* Er erzwingt durch die vier Anker (`_0` Fundament, `_1` Ingress, `_2` Security, `_9` Guardrails) die Einhaltung der Zonentrennung (**NET.1.1.A21**).
