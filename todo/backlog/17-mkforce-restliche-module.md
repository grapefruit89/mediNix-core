# Restliche `lib.mkForce`-Stellen im Modulcode

Stand: 2026-11-04 (Commit `ffea59e`)

> **Quellenlage:** Der Claude-Audit behauptet, `mkForce` stehe „nur in 541".
> Das ist **falsch**. Gemessen mit `grep -rn "mkForce" --include='*.nix' 5*-*/`
> stehen sechs weitere Stellen im Modulcode.
>
> M3 (`ffea59e`) hat nur die 541-Stellen entfernt — dort war es eine
> **Listen-Leerung** (`IPAddressDeny/Allow = mkForce [ ]`), weil
> `serviceConfig`-Listen konkateniert werden und ein plain `[ ]` nichts löscht.
> Die hier verbliebenen sechs sind eine **andere Klasse**: Wert-Überschreibung.

**Verbot:** `50-core/BANNED_TECHNOLOGIES.md:127` — „`lib.mkForce` ist verboten —
mit einer Ausnahme: in Prüfkonfigurationen (`tests/`, `flake.nix`-Checks)."
`scripts/check_banned_technologies.py` prüft das **nicht** mechanisch (exit 0
trotz dieser sechs Treffer) — die Regel ist bis heute unerzwungen.

---

## Befunde

| Datei:Zeile | Option | Wert | Kollidiert mit |
|---|---|---|---|
| `51-ingress/512-pocket-id.nix:235` | `UMask` | `"0007"` | `base.UMask = lib.mkDefault "0002"` — `mkDefault` verliert gegen plain, `mkForce` wäre hier **vermutlich unnötig** (ungeprüft) |
| `51-ingress/512-pocket-id.nix:236` | `StateDirectoryMode` | `"0700"` | `service-factory.nix:88` setzt `StateDirectoryMode = "0750"` **plain** → Override braucht `mkForce` |
| `51-ingress/515-blocky.nix:107` | `DynamicUser` | `false` | nicht die Fabrik; vermutlich das nixpkgs-`blocky`-Modul (ungeprüft) |
| `51-ingress/516-crowdsec.nix:186` | `ProtectControlGroups` | `"strict"` | `base.ProtectControlGroups = true` **plain** |
| `51-ingress/516-crowdsec.nix:187` | `ProtectHostname` | `"true:${name}"` | `base.ProtectHostname = true` **plain** |
| `51-ingress/516-crowdsec.nix:188` | `ProtectKernelLogs` | `false` | `base.ProtectKernelLogs = true` **plain** |

## Ursache — zwei verschiedene Wurzeln

**(a) Die Fabrik legt das Profil als *plain* Definition auf.**
`50-core/service-factory.nix:84` und `:132`:

```nix
(profiles.${profile} or profiles.base)     # plain, nicht mkDefault
```

Damit gewinnt das Profil gegen jede Modul-Definition, und das Modul muss
`mkForce` benutzen. Das betrifft `516` (3×) und `512:236`.

**(b) Ein Upstream-Modul setzt den Wert plain.** Dann hilft auch `mkDefault`
in der Fabrik nicht — der Override muss gegen nixpkgs gewinnen. Betrifft
vermutlich `515` (ungeprüft).

## Mögliche Fixes (Reihenfolge = Aufwand)

1. **Fabrik auf `mkDefault` pro Attribut umstellen** — `lib.mapAttrs (k: v: lib.mkDefault v) profiles.${profile}`.
   Damit gewinnt jede plain Modul-Definition ohne `mkForce`; die Fabrik bleibt
   der Default. **Achtung:** Für Listen-Attribute (`ReadWritePaths`,
   `InaccessiblePaths`, `SystemCallFilter`) ändert `mkDefault` das
   Merge-Verhalten nicht — dort bleibt Konkatenation. Muss gegen die 15
   Fabrik-Nutzer getestet werden.
2. **`512:235` prüfen und ggf. auf plain `UMask` umstellen** — `base.UMask` ist
   schon `mkDefault`, `mkForce` wäre dann nur Altlast. Ein Testlauf entscheidet.
3. **`515` gegen das nixpkgs-Modul prüfen** — wenn nixpkgs `DynamicUser = true`
   plain setzt, ist `mkForce` hier **nicht** vermeidbar; dann braucht es eine
   dokumentierte Ausnahme in `BANNED_TECHNOLOGIES.md` statt eines Fixes.

## Nicht Teil dieses Eintrags

- `mkForce` in `flake.nix` (Negativtest-Fixtures) — durch die BANNED-Ausnahme
  gedeckt, kein Befund.
- M3 / `541` — erledigt in `ffea59e`.

## Welle

Welle 4. Nicht in Batch 2b (dort: M4 591-Options-Pfad, L1 `hardeningProfile`,
M7/M8 Doku).
