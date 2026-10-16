# Archiv 2026-10-16 — repo-cleanup (`lib/`)

**Warum (Entscheidung):** 4 **nie verdrahtete** `lib`-Module aus dem *operativen* Code
entfernt — aber **nicht gelöscht**: hier eingelagert, damit das Wissen nicht verloren geht
(gelöschter Code = verlorenes Wissen).

| Modul (Kopie unter `lib/<name>.nix`) | Zweck | Heute ersetzt durch |
|---|---|---|
| `abc-tiering.nix` | Storage-Tier A/B/C als *lib-Funktionen* | `medinix.storage.backends.hot/cold` (Optionen) |
| `wait-for-api.nix` | Shell-Readiness-Gate | `wait_for_url` in `lib/arr-provision/arr_provision/common.py` |
| `mk-secure-curl.nix` | curl ohne Secret in `argv` (generisch) | `513` nativ (`--variable` + `--expand-header`) |
| `_helpers.nix` | `recursiveMergeAttrs` | `lib.mkMerge` |

**Beleg/Entscheidung:** `docs/AUDIT-LEDGER.md` **L-045**; `CHANGELOG.md` (2026-10-16).

**Wiederbeleben:** Datei aus diesem Ordner zurück nach `lib/` kopieren, Header-`status`
prüfen, Importeur eintragen — fertig. `git log -- lib/<name>.nix` zeigt die volle Historie.

**Hinweis:** `nixmeta_check.py` und `medinix-meta.py` **überspringen** `docs/audit/` +
`docs/archive/` — Eingelagertes wird nicht als aktiver Code gegated.
