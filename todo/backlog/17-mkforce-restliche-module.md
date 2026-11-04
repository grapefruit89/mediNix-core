# Restliche `lib.mkForce`-Stellen im Modulcode

Stand: 2026-11-04 (Commit `392eb07`)

> **Von 6 Stellen sind 4 erledigt.** Die 2 verbleibenden sind
> **Upstream-Konflikte** (nixpkgs-Module setzen den Wert plain), keine
> Fabrik- oder Modul-Schlamperei. Sie sind bewusste Ausnahmen und brauchen
> einen Kommentar an der Stelle, keinen Fix.

**Verbot:** `50-core/BANNED_TECHNOLOGIES.md:127` — „`lib.mkForce` ist verboten —
mit einer Ausnahme: in Prüfkonfigurationen (`tests/`, `flake.nix`-Checks)."
`scripts/check_banned_technologies.py` prüft das **nicht** mechanisch (exit 0
trotz der verbleibenden Treffer) — die Regel ist bis heute unerzwungen.

---

## Erledigt in `392eb07` (L1c)

`50-core/service-factory.nix` liefert das Profil jetzt per `lib.mkDefault` aus
(`asDefault`-Helper, der bereits gewrappte Werte unangetastet lässt), und
`StateDirectoryMode` ist ebenfalls `mkDefault`. Damit gewinnt eine plain
Modul-Definition, ohne `mkForce`:

| Stelle | Option | vorher | jetzt |
|---|---|---|---|
| `51-ingress/512-pocket-id.nix` | `StateDirectoryMode = "0700"` | `mkForce` gegen `service-factory.nix:88` (`"0750"` plain) | plain ✅ |
| `51-ingress/516-crowdsec.nix:186` | `ProtectControlGroups = "strict"` | `mkForce` gegen `base` plain `true` | plain ✅ |
| `51-ingress/516-crowdsec.nix:187` | `ProtectHostname = "true:…"` | `mkForce` gegen `base` plain `true` | plain ✅ |
| `51-ingress/516-crowdsec.nix:188` | `ProtectKernelLogs = false` | `mkForce` gegen `base` plain `true` | plain ✅ |

**Grenze der Umstellung:** für **Listen** ändert `mkDefault` nichts — sie werden
weiterhin konkateniert. Wer eine Liste ersetzen will, braucht ein eigenes Profil
(Vorbild: `python-confined` in `541`, Commit `ffea59e`).

---

## Verbleibend — 2 Stellen, beide Upstream

### 1. `51-ingress/512-pocket-id.nix` — `UMask = lib.mkForce "0007"`

**Fakt (gemessen, nicht vermutet):** `nixos/modules/services/security/pocket-id.nix`
setzt `UMask = "0077"` als **plain** Definition. Mit plain `"0007"` bricht der
Build:

```
error: The option `systemd.services.pocket-id.serviceConfig.UMask'
has conflicting definition values:
  - nixpkgs pocket-id.nix:  "0077"
  - 512-pocket-id.nix:      "0007"
```

**Semantischer Unterschied:**

| UMask | Dateien | Verzeichnisse |
|---|---|---|
| `"0077"` (Upstream) | `0600` — nur Owner rw | `0700` |
| `"0007"` (mediNix) | `0660` — Owner rw, **Gruppe rw** | `0770` |

**Offene Frage:** pocket-id läuft als `pocket-id:pocket-id` (UPG — Gruppe ==
eigene Gruppe). Gruppen-Schreibzugriff ist damit rechnerisch derselbe wie
Owner-Schreibzugriff, also **kein Funktionsgewinn**, nur weniger strikt.
`"0077"` wäre die strengere Wahl.

**Warum nicht sofort geändert:** ein Wechsel auf `"0077"` ist eine
Verhaltensänderung an einem laufenden Sicherheitsdienst (Dateirechte der
SQLite-DB). Er braucht einen Start-Test, nicht nur `nix flake check`. Offen.

### 2. `51-ingress/515-blocky.nix:107` — `DynamicUser = lib.mkForce false`

**Fakt:** das nixpkgs-Modul für blocky setzt `DynamicUser = true` (plain).

**Warum mediNix abweicht:** mediNix braucht die **feste UID 5150** — ADR-0000 §4
leitet UID = Port = Primär-GID aus der Dienstnummer ab, und die Peer-Isolation
(`InaccessiblePaths`) sowie die UPG-Grenze hängen daran. `DynamicUser = true`
nimmt eine zufällige UID und würde beides aushebeln.

**Das ist keine Schuld, sondern eine Architektur-Aussage.** Der Kommentar an der
Stelle trägt die Begründung (Phase 4 dieses Auftrags).

---

## Nicht Teil dieses Eintrags

- `mkForce` in `flake.nix` (Negativtest-Fixtures) — durch die BANNED-Ausnahme
  gedeckt, kein Befund.
- `541` — erledigt in `ffea59e` (Listen-Leerung durch eigenes Profil ersetzt).
