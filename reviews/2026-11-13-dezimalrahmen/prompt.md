# Review-Scheibe 1 — Kette Registry → Engine → Factory → Modul

**Anhang:** `merge.txt` aus diesem Ordner (4 Dateien, SHA256-Tabelle am Ende).
**Frage in einem Satz:** Wo kann die Kette `registry.nix → 501-decimal-engine.nix → service-factory.nix → Dienstmodul` brechen, und welcher Nachweis fehlt dafür heute?

---

## 1. Rolle

Du änderst **nichts**. Du prüfst und belegst. Jede Behauptung braucht eine Fundstelle
(`datei:zeile`) oder einen Messwert. Ohne Beleg schreibst du `ungeprüft` und nennst die
Gegenprobe, mit der man es in einem Satz klären könnte.

## 2. Harte Regeln des Repos (nicht verhandelbar)

- **Dezimalrahmen (ADR-0000 §4):** `Port = UID = Primär-GID = num × 10`. Die geteilte
  Gruppe `media` (GID 5000) ist ausschließlich `extraGroups`, nie Primärgruppe.
- **SSoT:** Die Formel steht **einmal** in `50-core/derive.nix`. Kein Modul darf Port/UID
  selbst herleiten.
- **`mkForce` ist verboten** (Ausnahme: dokumentierte Upstream-Konflikte, ADR-0003 §2).
- **Zero Container**, systemd-native.
- **Fail-closed:** Assertions brechen den Build, nicht den Betrieb.
- **Tri-State statt Übernahme:** Der Host entscheidet `managed | external | off`.

## 3. Was bereits erledigt ist (nicht erneut melden)

| Befund | Stand | Beleg |
|---|---|---|
| Rekursion `585-exporters` ↔ `manifest` | behoben | `AUDIT-LEDGER.md` L-046 |
| Fehlendes Login-Credential beim Build | behoben (`medinix.security.loginKeys`) | L-047 |
| Frameband-Prüfung als Assertion → jetzt Check | behoben | L-048 |
| logrotate-Assertion (Versions-Skew) | behoben | L-049 |
| Blocky-Kollision, ntfy-Template, exportarr-Bind | behoben | L-050 |
| Arr-API-Key (Env ignoriert → ExecStartPre) | behoben | L-051 |

Entschieden und **nicht** wieder aufzumachen: kein `netns`, kein sops/agenix, keine
Container, kein `mkForce` als Abkürzung.

## 4. Auftrag — vier Prüfungen, jede mit Gegenprobe

1. **Abdeckung:** Nenne die Zahl der Module im Muster `5X-domain/NNN-*.nix`, die Zahl der
   Registry-Einträge und die Menge der Module, die **weder** Registry-Eintrag **noch**
   Fabrik-Nutzung haben. Ist jeder Dienst mit Daemon in der Registry? Nenne die Lücke als
   `datei` (nicht als Meinung).
2. **Herleitung:** Finde jede Stelle, an der ein Modul `port`, `uid` oder `stateDir` selbst
   bildet, statt sie aus der Registry zu lesen. Zähle sie. Nenne `datei:zeile`.
3. **Fallbacks:** In `58-observability/586-vpn-selftest.nix` stehen `or 5810` und
   `or 5260`. Belege, ob das echte Fallbacks auf Magic Numbers sind, und ob sie driften
   können, wenn die Registry sich ändert.
4. **Engine:** Die Engine hat 9 Assertions. Nenne für **jede** in einem Satz, welche
   Invariante sie prüft und ob die Fabrik sie tatsächlich erzwingt — oder ob ein Modul sie
   umgehen kann, indem es die Fabrik nicht benutzt.

## 5. Messwerte (erhoben 2026-11-13, Arbeitsbaum auf `HEAD 49da942`)

| Messung | Wert | Methode |
|---|---:|---|
| Module im Muster `5X-domain/NNN-*.nix` | 46 | `ls 5[0-9]-*/[0-9][0-9][0-9]-*.nix \| wc -l` |
| Registry-Einträge | 18 | `grep -cE '= mk(Service \|NoPort\|UdsService)' 50-core/registry.nix` (11 + 3 + 4) |
| Module mit `service-factory.nix` | 13 | `grep -l service-factory.nix 5[0-9]-*/NNN-*.nix \| wc -l` |
| Module mit eigenem `medinix.manifest.*` | 17 | `grep -l 'medinix.manifest\.' … \| wc -l` |
| Assertions in `501-decimal-engine.nix` | 9 | `grep -c assertion` |
| Treffer `\b5[0-9]{3}\b` in Modulen (ohne Kommentare/`num =`) | 7 | `grep -rnE`; davon 2 Fallbacks in `586` |

Die Formel selbst (`50-core/derive.nix:39-45`): `port = num * 10`, `uid = num * 10`,
`primaryGid = num * 10`, `stateDir = "/var/lib/<name>"`.

**Zählweise-Hinweis:** Die 46 Module enthalten auch `510-ingress-SERVICE.md`-Nachbarn und
reine `README`-Träger? Nein — das Muster verlangt `.nix`. Prüfe die 46 gegen die
Registry-Abdeckung, nicht gegen die Zahl der Dienste.

## 6. Antwortform

- Pro Befund **eine** Zeile: `datei:zeile` · was · warum es bricht.
- Am Ende drei Optionen **A/B/C** mit Aufwand (S/M/L) und dem Risiko, das jede einkauft.
- Keine Zusammenfassung des Gelesenen. Keine Empfehlung ohne Gegenprobe.
- Maximal 400 Wörter.

## 7. Verbote

- Keine Wiederholung der Befunde aus Abschnitt 3.
- Keine Aussage über Verhalten, das du nicht im Anhang siehst (kein „vermutlich ruft X Y auf").
- Keine Screenshots, keine Vermutungen über den Host.
- Keine Zahlen ohne Zählweise.
