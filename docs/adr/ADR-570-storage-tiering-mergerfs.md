---
id: "ADR-570"
title: "Storage-Tiering: tmpfiles-Struktur + optionale MergerFS-Pools"
status: active
complexity: 3
last_reviewed: 2026-10-16
links:
  adr: ADR-0000 (Dezimalrahmen/UPG), ADR-543 (Cold-Archive-Mover)
---

# ADR-570: Storage-Tiering - tmpfiles-Struktur + MergerFS-Pools

## Kontext
Zwei Ebenen: **physisch** (der Host mountet die Platten, `fileSystems."/mnt/ssd"` …) und
**logisch** (die Medienablage, die alle Dienste gemeinsam nutzen: `/data/media`,
`/data/metadata`).

## Entscheidung
- Der **Host** besitzt die Mounts; das **Flake** erzeugt die logische Struktur ueber
  `systemd.tmpfiles` - Deklaration statt Skript (ADR-0002).
- Zwei Betriebsmodi:
  - **Simple** (`storage.backends = {}`): flache Struktur unter `storage.mediaRoot`, kein Pool.
  - **Tiered** (`backends.hot`/`backends.cold` gesetzt): **MergerFS**-Mounts je Medientyp -
    ein Pfad, mehrere Platten.
- Verzeichnisse: Modus **2775** (`SetGID`) mit Gruppe `media` (GID 5000, SSoT aus
  `lib/registry.nix`) - neue Dateien **und** neue Unterordner erben die Gruppe.

## Begruendung
- Seit der UPG-Umstellung (ADR-0000 §4) ist die **Primaergruppe** der Dienste ihr eigener Name.
  Mit 0775 allein entstuenden Dateien als `<dienst>:<dienst>`, die Nachbardienste (Mitglied von
  `media`) nicht mehr aendern koennten - das SetGID-Bit loest das an der Wurzel.
- Nachtraegliche `d`-Regeln in tmpfiles korrigieren Modus und SetGID-Bit auch auf bereits
  existierenden Verzeichnissen (lokal mit systemd 259 verifiziert).
- MergerFS bleibt **optional**: ein einzelner Backend braucht keinen Pool (KISS).

## Konsequenzen
- Plattenwechsel oder Ausbau ist eine Host-Aenderung, kein Flake-Umbau.
- Im Tiered-Modus entscheidet `backends`, welche Platte "hot" (schnell) und welche "cold"
  (Archiv) ist - der Mover (543) kennt nur die Pfade, nicht die Platten.
