# Aufgabe 15 — ADR-0000 §9-Fehlverweise bereinigen

> [!CAUTION]
> **STATUS: GEPLANT — NICHT AUTOMATISCH AUSFÜHREN!**
> Gehört zu **Welle 4**, nicht in den §14-Commit (Welle 3, Teil 1). Der §14-Commit
> bleibt atomar: eine Datei, eine Aussage.

---

## Problem

Vier Code-Stellen verweisen auf `ADR-0000 §9` für die Regel „`stateDir` ohne
Port-Suffix". §9 der Verfassung heißt heute aber **„Exclusion Log (Rejected
Alternatives)"** und regelt verworfene Alternativen — nicht `stateDir`.

Der Verweis geht damit ins Leere: strukturell (falsche Sektion) und semantisch
(die Sektion behandelt ein anderes Thema). Ein Agent, der dem Verweis folgt,
findet keine Begründung und muss raten.

## Fundstellen

| Datei | Zeile | Zitat |
|---|---|---|
| `50-core/derive.nix` | 43 | `stateDir = "/var/lib/${name}"; # ADR-0000 §9: ohne Port-Suffix` |
| `50-core/service-factory.nix` | 54 | `stateDir ? null, # z. B. "/var/lib/jellyfin" (ADR-0000 §9: ohne Port-Suffix)` |
| `50-core/service-contract.nix` | 373 | `# ADR-0000 §9: kein Port-Suffix. Die Engine (50-core/501-decimal-engine.nix)` |
| `default.nix` | 27 | `# (flat structure, ADR-0000 §9). No hardcoded import list.` |

## Ursache

Die Verfassung wurde umnummeriert (§14 „Datei-Klassifikation" eingefügt, altes §12
„Appendix" → §15), und davor bereits inhaltlich umgebaut. Die Code-Kommentare sind
auf einem älteren Sektionsstand stehen geblieben.

## Aktion

1. **Zuerst messen, nicht raten:** prüfen, welche Sektion `stateDir` ohne Port-Suffix
   tatsächlich regelt. Kandidat ist **§4** („Derivations & User Private Groups (UPG)"),
   weil dort `stateDir` aus `num` abgeleitet wird — aber das ist zu verifizieren, nicht
   anzunehmen.
2. Betrifft `default.nix:27` ein anderes Thema („flat structure"), dann ist dort der
   korrekte Anker **§1** („Two-Level Tree & Meaningful Isomorphism"), nicht §4.
   Die vier Stellen also **einzeln** bewerten, nicht pauschal ersetzen.
3. Alle vier Kommentare auf die verifizierte Sektion umstellen.
4. `nix flake check --no-build` grün.

## Nicht Teil dieser Aufgabe

- Keine Änderung an ADR-0000 selbst (die Sektionen sind korrekt, die Verweise sind falsch).
- Kein Sweep der übrigen `lib/`-Referenzen (Welle 3, Teil 3).
- Keine Modul-Nummern-Umverteilung.

## Herkunft

Gefunden am 2026-11-04 beim Vollzug von Welle 3, Teil 1 (§14 Datei-Klassifikation),
Nebenbefund der Verifikation `grep -rn "ADR-0000 §"`.

## Welle

4 — nach Abschluss von Welle 3 (Teile 2–5).
