# Batches/ — ein Thema, ein Ordner, eine Datei zum Hochladen

Methode aus dem DIN-BriefNEO-Handoff, angepasst auf mediNix: **ein Thema isoliert
prüfen**, statt einen Fat Review über das ganze Repo zu schicken.

## Aufbau eines Batches

```
Batches/B01 - Dezimalrahmen/
    prompt.md      der Prompt (was geprüft werden soll)
    merged.md      Build-Output: alle Quellen in EINER Datei (nicht versioniert)
    registry.nix ->         Symlink in das Repo
    501-decimal-engine.nix ->
    service-factory.nix ->
    532-sonarr.nix ->
```

Hochgeladen werden **zwei Dinge**: `prompt.md` als Text und `merged.md` als Anhang.
Sonst nichts. Der Prüfer sieht genau diese Scheibe.

## Warum Symlinks und keine Kopien

Eine Kopie veraltet still. Ein Symlink zeigt immer auf die Quelle, und `batch-merge.py`
bricht ab, wenn ein Link ins Leere oder aus dem Repo heraus zeigt (kein Zugriff auf
`$HOME`, `/etc`, …).

**Relative Ziele** (`../../50-core/registry.nix`), nicht absolute — sonst funktioniert der
Ordner nur auf diesem Rechner.

## Scheibe schneiden

- **Eine Frage, die in einen Satz passt.** Passt sie nicht, sind es zwei Batches.
- **2–6 Dateien.** Mehr heißt: Schnitt zu grob (der Bauer warnt ab 7).
- **Messen, bevor der Prompt geschrieben wird** — am Objekt, mit Datum, Methode und
  Zählweise. Die Zahlen stehen im Prompt, nicht in einer Datei, die drei Commits später
  veraltet ist.

## Bauen

```bash
cd /home/moritz/repos/mediNix-core
mkdir -p "Batches/B02 - Credential-Fluss"
cd "Batches/B02 - Credential-Fluss"
ln -sfn ../../52-security/creds.nix creds.nix
ln -sfn ../../52-security/521-creds.nix 521-creds.nix
ln -sfn ../../53-acquisition/arr-key-sync.nix arr-key-sync.nix

python3 /home/moritz/repos/mediNix-core/scripts/batch-merge.py \
  "/home/moritz/repos/mediNix-core/Batches/B02 - Credential-Fluss"
```

## Prompt-Pflichtbausteine (in dieser Reihenfolge)

1. **Rolle:** „du änderst nichts, du prüfst".
2. **Harte Regeln:** ADR-0000, Baseline, Verbote (`mkForce`-Bann, Zero-Container, …).
3. **Was bereits erledigt ist** — als Tabelle. Ohne diesen Block meldet der Prüfer
   erledigte Befunde erneut.
4. **Auftrag mit Gegenprobe:** „nenne Nummern, keine Meinung".
5. **Messwerte** mit Datum und Methode.
6. **Antwortform:** kurz, Beleg pro Behauptung, ohne Beleg `ungeprüft` + Gegenprobe,
   am Ende A/B/C mit Kosten.
7. **Verbote:** keine Wiederholung erledigter Befunde; entschiedene Themen nur mit
   **neuem** Messwert; keine Screenshots als Beweis.

## Auswerten, nicht übernehmen

Jeden Befund selbst nachrechnen. Drei Sorten:

| Sorte | Umgang |
|---|---|
| belegt und heute noch wahr | umsetzen, Messung vorher/nachher |
| belegt, aber inzwischen erledigt | verwerfen, im Ledger vermerken |
| plausibel, aber „ungeprüft" | nachmessen, dann entscheiden — nie auf Verdacht bauen |

Danach: `docs/AUDIT-LEDGER.md` (L-NNN) und `todo/tasks.json` pflegen, Leiter fahren
(`bash scripts/verify.sh`).

## Fallen

- **`merged.md` ist der Arbeitsbaum, nicht der Commit.** Verbindlich ist die
  SHA256-Tabelle am Ende.
- **Der Anhang veraltet im nächsten Commit.** Nach einem Umbau: neu bauen, nicht den
  alten Prompt nachschieben.
- **Zahlen sind Versprechen.** Wer eine Zahl in den Prompt schreibt, liefert die Zählweise.
- **Ein Prüfer, der nicht rechnet, ist nutzlos.** Die brauchbarsten Korrekturen kommen
  aus Gegenproben.
