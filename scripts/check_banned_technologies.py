#!/usr/bin/env python3
"""Verbotene Technologien als Check (Quelle: 50-core/BANNED_TECHNOLOGIES.md §1).

Geprueft werden **nur aktivierende Muster** - also Code, der die verbotene Technologie
tatsaechlich einschaltet, nicht jede Erwaehnung:

* `services.<x>.enable = true` / `virtualisation.<y>.enable = true` (auch `lib.mkForce true`)
* Definitionen: `virtualisation.oci-containers.containers = …`
* Pakete: `pkgs.<verboten>`
* Befehle in Kommandoposition (`.sh`, Skript-Bloecke): `iptables -A …`, `crontab …`
* Import/Paket der Vector-DBs: `import chromadb`, `pkgs.faiss`

Bewusst NICHT geprueft werden:
* **verbietende** Konstrukte (`!(config.services.logrotate.enable or false)`,
  `services.logrotate.enable = lib.mkDefault false`) - das ist die Durchsetzung,
* Namen in Guards (`nginx = { enabled = config.services.nginx.enable or false; }`),
* Erwaehnungen in Kommentaren, Meldungen und Doku (BANNED_TECHNOLOGIES.md listet sie).

Blinding: Zeilenkommentare, doppelt gequotete Strings und die Text-Strings
(`message`/`description`/`help`/`warning` = '' … '') werden vor dem Abgleich entfernt.
Andere `''`-Bloecke bleiben stehen - dort steht echter Shell-Code, und genau dort waere
`iptables`/`cron` ein echter Verstoss.

Bedingte Regeln aus der Doku (Postgres/MySQL nur "als Default", Auto-Updater,
unbeschraenktes `sudo`) sind **nicht** mechanisch entscheidbar und bleiben manuelle Pruefung.

Exit 1 = Verstoss.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUFFIXES = (".nix", ".sh", ".py", ".yml", ".yaml", ".bash", ".service")
TEXT_ASSIGN = re.compile(r"\b(?:message|description|help|warning|example)\s*=\s*''.*?''", re.S)
# Python-Docstrings: sie zitieren die verbotenen Muster (z. B. in
# check_grundfunktionen.py) und sind keine Aktivierung.
PY_DOC = re.compile(r'"""(?:.|\n)*?"""|\'\'\'(?:.|\n)*?\'\'\'')
QUOTED = re.compile(r'"(?:[^"\\]|\\.)*"')
COMMENT = re.compile(r"(?m)^\s*#.*$")
ACTIVATE = r"\.enable\s*=\s*(?:lib\.mkForce\s+)?true"

BANS = [
    (
        "sops-nix / agenix (Fremd-Secretmanager)",
        re.compile(
            r"\b(?:security|secrets|services)\.sops\b|\bsops\.(?:secrets|defaultSopsFile|age)\b"
            r"|\bsops-nix\b|\bagenix\b|\bage\.secrets\b|\bsopsFile\b"
        ),
        "systemd-creds: LoadCredentialEncrypted (ADR-521)",
    ),
    (
        "iptables / ip6tables / ufw / firewalld (imperative Firewall)",
        re.compile(
            r"(?:^|[|&;(]\s*)(?:sudo\s+)?(?:iptables|ip6tables|ufw|firewalld)\s+(?!=\s)"
            r"|pkgs\.(?:iptables|ip6tables|ufw|firewalld)\b"
            r"|services\.(?:ufw|firewalld)" + ACTIVATE
            + r"|networking\.firewall\.extraCommands\s*="
        ),
        "networking.nftables / deklarative Regeln (ADR-5210)",
    ),
    (
        "cron / crond / anacron / crontab",
        re.compile(
            r"services\.(?:cron|cronie|anacron)" + ACTIVATE
            + r"|pkgs\.(?:cron|cronie|anacron)\b"
            + r"|(?:^|[|&;(]\s*)(?:sudo\s+)?crontab\s+(?!=\s)"
        ),
        "systemd.timer (ADR-5000)",
    ),
    (
        "Docker / Podman / LXC / OCI-Container",
        re.compile(
            r"virtualisation\.(?:docker|podman|lxc)" + ACTIVATE
            + r"|virtualisation\.oci-containers(?:\.containers)?\s*="
            + r"|pkgs\.(?:docker|podman|lxc)\b"
        ),
        "native systemd.services + Sandboxing (ADR-5000 / 0002)",
    ),
    (
        "nginx / Traefik (zweiter Ingress)",
        re.compile(
            r"services\.(?:nginx|traefik)" + ACTIVATE
            + r"|pkgs\.(?:nginx|traefik)\b"
            + r"|(?:^|[|&;(]\s*)(?:sudo\s+)?(?:traefik)\s+(?!=\s)"
        ),
        "genau EIN Reverse-Proxy: Caddy (ADR-511)",
    ),
    (
        "logrotate (eigener Log-Rotator)",
        re.compile(
            r"services\.logrotate" + ACTIVATE
            + r"|pkgs\.logrotate\b"
            + r"|(?:^|[|&;(]\s*)(?:sudo\s+)?logrotate\s+(?!=\s)"
        ),
        "systemd-journald (SystemMaxUse, ADR-500 / ADR-0002)",
    ),
    (
        "qmd / ChromaDB / FAISS (LLM-Vektor-DBs)",
        re.compile(
            r"\bqmd\b|\bchromadb\b|\bchroma\b|\bfaiss\b"
            r"|pkgs\.(?:chromadb|faiss|qmd)\b"
            + r"|(?:pip3?|python3?\s+-m\s+pip)\s+install[^\n]*\b(?:chromadb|faiss|qmd)\b"
        ),
        "AGENTS.md-Index + grep/fd (dokumentierte Karten)",
    ),
    (
        "supervisord / PM2 (Prozessmanager im Dienst)",
        re.compile(r"\bsupervisord\b|\bsupervisor\.\w|\bpm2\b"),
        "systemd.service-Lifecycle",
    ),
    (
        "Plex Media Server",
        re.compile(r"services\.plex" + ACTIVATE + r"|pkgs\.plex\b"),
        "Jellyfin (ADR-551)",
    ),
]


def code_only(text: str) -> str:
    """Kommentare, gequotete Strings und Text-Attribute ausblenden (Zeilenzahl bleibt)."""
    def blank(match: re.Match) -> str:
        return "\n" * match.group(0).count("\n")

    text = TEXT_ASSIGN.sub(blank, text)
    text = PY_DOC.sub(blank, text)
    text = QUOTED.sub('""', text)
    return COMMENT.sub("", text)


# Zweiter Pass fuer Muster, bei denen der Inhalt eines STRINGS der Verstoss ist
# (imperative Aktivierung). Hier werden Strings absichtlich NICHT ausgeblendet,
# sonst waere z. B. `system.activationScripts.x = "iptables -A ..."` unsichtbar.
RAW_BANS = [
    (
        "imperative Aktivierung (ADR-0002 §1, ADR-0003 §1)",
        re.compile(
            r'''system\.activationScripts\.[A-Za-z0-9_-]+\s*=\s*(?:''|")[\s\S]{0,300}?\b(?:iptables|ip6tables|nft|chmod|chown|useradd|userdel|systemctl|rm\s+-|mv\s+/|curl\s+http|wget\s+http|nix-channel|nix-env\s+-i)\b'''
        ),
        "systemd.tmpfiles / Units + Optionen statt Aktivierungs-Skripte",
    ),
    (
        "imperativer Paket-/Kanal-Zustand",
        re.compile(r"\bnix-channel\s+--(?:add|update)\b|\bnix-env\s+-i\b"),
        "flake.nix + nixpkgs-Pin",
    ),
]


def raw_code(text: str) -> str:
    """Nur Zeilenkommentare entfernen - Strings bleiben (ihr Inhalt ist der Verstoss)."""
    return COMMENT.sub("", text)


def main() -> int:
    hits: list[str] = []
    checked = 0
    for path in sorted(ROOT.glob("**/*")):
        if ".git" in path.parts or not path.is_file() or path.suffix not in SUFFIXES:
            continue
        if path.resolve() == Path(__file__).resolve():
            continue
        checked += 1
        code = code_only(path.read_text(encoding="utf-8", errors="replace"))
        raw = raw_code(path.read_text(encoding="utf-8", errors="replace"))
        for name, pattern, alternative in BANS + RAW_BANS:
            source = raw if (name, pattern, alternative) in RAW_BANS else code
            for match in pattern.finditer(source):
                line = source[: match.start()].count("\n") + 1
                hits.append(
                    f"{path.relative_to(ROOT)}:{line}: {name} -> '{match.group(0).strip()[:60]}'"
                    f" | Nativ statt dessen: {alternative}"
                )

    for hit in hits:
        print(f"FEHLER: {hit}")
    if hits:
        print(f"\n{len(hits)} Verstoss/Verstoesse gegen 50-core/BANNED_TECHNOLOGIES.md "
              f"({checked} Code-Dateien geprueft).")
        return 1
    print(f"OK: keine aktivierte verbotene Technologie in {checked} Code-Dateien "
          "(50-core/BANNED_TECHNOLOGIES.md §1).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
