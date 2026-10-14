# Knowledge-Base Layout (/opt/data/knowledge/)

Read-only Mount, täglich 06:00 synchronisiert vom Windows-PC.

## Top-Level

```
/opt/data/knowledge/
├── INDEX.md                      # Verzeichnisübersicht (erste Anlaufstelle)
├── nixos_local/                  # Echte NixOS-Konfig-Dateien
└── obsidian/
    ├── nixos/                    # NixOS Obsidian-Vault
    └── websites_software/        # Websites & Software Obsidian-Vault
```

## nixos_local/ (echte Configs)

```
nixos_local/
├── 0000-dezimalrahmen-verfassung.md
├── ADR-5000-mediNix-Architecture.md
├── Guide-mediNix-Reference.md
├── README.md
└── modules/
    └── 50-mediNix/               # Kernarchitektur (510-590)
        ├── 510-ingress/
        ├── 520-security/
        ├── 530-acquisition/
        ├── 540-transfer/
        ├── 550-playback/
        ├── 560-requests/
        └── 570-maintenance/
```

## obsidian/nixos/ (Notiz-Vault, NICHT für Deployments)

```
obsidian/nixos/
├── AGENTS.md                     # NO-WORK-ZONE Warnung
├── GEMINI.md                     # Projektverfassung
├── ADR/                          # Architecture Decision Records
├── Guides/
├── 01_Quellen/
│   ├── Eigenes_Repository/       # mynixos-main (00-core bis 90-policy)
│   ├── Fremd_Repositorys/
│   └── einzeldateien/
├── Nix Files/                    # Lokale Nix-Notizen, keine produktiven Configs
├── __Müllhalde/                  # Ablage, unsortiert
├── nixos_docs.db                 # Master-DB (FTS5, 74 docs)
├── memdb.db                      # Memory-DB
├── bundles.yaml
├── tools/
├── neue llm findings/
└── einstellungen von unraid/
```

## obsidian/websites_software/

```
obsidian/websites_software/
├── caddy-on-steroids/            # Caddy-Reverse-Proxy-Projekt
│   ├── docs/                     # GEMINI.md, Specs, Unraid-SSH-Reference
│   ├── nixos/                    # caddy-package.nix, nixos-vars.nix
│   └── _archive/                 # Claude-Archiv
├── Context Bundler/              # Knowledge-Extraction-Pipeline
│   ├── bundler boilerplate/      # Specs, Templates, Constitution
│   ├── shredder_tmp/             # Bündel-Ausgaben
│   └── docs/superpowers/plans/
├── DIN-Brief Neo/                # DIN-Brief-Template
│   ├── .agents/                  # Agent-Briefings, Audits
│   └── _Template_Obsidian.md
└── ...
```

## Wichtige Ankerpunkte

| Was | Pfad |
|-----|------|
| Projektverfassung | `nixos_local/GEMINI.md` oder `obsidian/nixos/GEMINI.md` |
| Master-DB | `obsidian/nixos/nixos_docs.db` |
| Kernarchitektur | `nixos_local/modules/50-mediNix/` |
| ADRs | `nixos_local/modules/defaultNix/docs/adr/` oder `obsidian/nixos/ADR/` |
| Index | `/opt/data/knowledge/INDEX.md` |

## Sicherheitsregeln

1. **Vault `.nix`-Dateien sind Notizen, keine Configs.** Nie deployen.
2. **AGENTS.md im Vault** markiert den gesamten Vault als NO-WORK-ZONE für direkte Modifikationen.
3. **nixos_docs.db ist SSoT.** Wenn Datei und DB widersprüchlich sind, gewinnt die DB.
4. **Read-only Mount.** Schreibzugriffe gehen in den Agent-eigenen Bereich (`/opt/data/`), nie in den Mount.
