# Archiv 2026-10-15 — Momentaufnahmen der Doku-Konsolidierung

Hier liegen die Dokumente, die bis zum 2026-10-15 als **konkurrierende Quellen** existierten.
Sie sind **nicht gelöscht**, sondern eingefroren: Der Inhalt bleibt als Beweis und Vorgeschichte
erhalten, ist aber nicht mehr handlungsleitend. Die kanonische Roadmap ist `ROADMAP.md` im Root.

| Datei | Was sie war | Warum archiviert |
|---|---|---|
| `ROADMAP.md` | „Architektur-Leitfaden & Zukunfts-Roadmap" (vierte Roadmap) | offene Punkte und die „bewusst abgelehnt"-Liste sind in die Root-`ROADMAP.md` übernommen |
| `ROADMAP-DEZIMALRAHMEN-MIGRATION.md` | Migrationsplan Altstand → ADR-0000 | Migration am 2026-10-15 abgeschlossen (Weg B: ein Eigentümer für `users.users`, UPG, SetGID, Guardrail 591) |
| `PHASE4-SPEC.md` | Implementierungs-Spec Phase 4 (577 Zeilen) | der Kernbefund betraf `52-security/524-systemd-credentials.nix` — dieses Modul existiert im aktuellen Stand nicht mehr; offene Items (2–7) sind als Backlog-Einträge übernommen |
| `AGENTS-docs-veraltet.md` | Agenten-Anleitung unter `docs/` | nannte `mediahost` / `192.168.0.10` / `/opt/data/50-mediNix`; ersetzt durch einen Zeiger auf das Root-`AGENTS.md` |

## Lehren dieser Runde (für den nächsten Agenten)

1. **Vier Roadmaps sind vier Wahrheiten.** Zwei davon beschrieben Arbeit, die längst erledigt war
   (Gatus als „nächster Schritt", `lib.fakeHash` in `511-caddy.nix`, der Zwei-Engine-Konflikt).
   Wer der falschen folgt, macht Arbeit doppelt oder repariert etwas, das es nicht mehr gibt.
2. **Ein veraltetes Dokument ist gefährlicher als ein fehlendes.** `docs/AGENTS.md` hätte jeden
   Agenten auf einen Host geschickt, den es nicht mehr gibt.
3. **Archivieren heißt einfrieren, nicht löschen.** Im Zweifel `git mv` nach `docs/audit/<datum>/` —
   die Historie bleibt, der Irrtum verschwindet aus dem Weg.
4. **Vor dem Verschieben prüfen, wer verlinkt** (mkdocs-Navigation, ADRs, Index-Dateien) — sonst
   bricht der `docs`-Build in der CI, so wie es die `order-lint.yml` am 2026-10-15 fast getan hätte.

---

## Fehlversuche und Sackgassen dieser Runde

Nichts davon ist gelöscht — jede Sackgasse bleibt als Warnschild stehen.

| Fehlversuch | Was passierte | Lehre |
|---|---|---|
| Top-Level-`inherit` in einem Modul (`lib/decimal-framework.nix:114-121`) | `nix flake check` war seit `5cf7038` rot — über **5 Commits** lang unbemerkt | Ein Modul darf nur `imports`/`options`/`config` auf oberster Ebene haben (`lib/modules.nix:670`) |
| Account-Eigentum in der Factory aus `config.medinix.manifest` ableiten | **Endlosrekursion**, 12 statt 43 grüne Checks in einem Lauf | `config.*` nie aus einer Funktion lesen, die während der Config-Auswertung läuft → explizite Parameter |
| `# shellcheck disable=SC2035: <Text>` | SC1125 „Invalid key=value pair" — die Direktive wirkte nicht | Direktive allein auf die Zeile, Erklärung in die Zeile darüber |
| Annahme, `551:165` und `552:134` seien doppelte Eltern-Deklarationen | es sind **Unterverzeichnisse** (`${storage.metadataDir}/jellyfin`) | Variablendefinitionen nachlesen statt aus dem Grep-Kontext schließen |
| `nix build '.#packages.x86_64-linux.*'` | nix expandiert keine Glob-Wildcards (Fehler: „expected a derivation … found a set") | Paketliste per `nix eval` ableiten und in einer Schleife bauen |
| actionlint-Fund auf `cp` verortet | der SC2035-Treffer saß auf `git add *.md` (Zeile 48), nicht auf `cp` (Zeile 47) | Zeilennummern aus dem Werkzeug übernehmen, nicht selbst zählen |
| Vertrauen in `nix flake check --no-build` | ein nixfmt-Fund (`582-gatus.nix`) ging lokal durch, die CI wurde rot | Lint-Checks müssen **gebaut** werden; Format-Sweep über alle `.nix` |
| Vertrauen in `nix flake check` | `packages.docs` war seit einem mkdocs-Bump kaputt, die CI blieb grün | Was nicht gebaut wird, verrottet → Paket-Build-Step in der CI |
| `services.gatus` / `services.ntfy-sh` delegieren | `DynamicUser = true` = stiller Verfassungsbruch; Gatus band Port 8080 statt 5820 | Upstream-Module vor der Delegation auf `DynamicUser`, `User`/`Group` und Port prüfen |
| `types.enum` auf `ui.group` gesetzt und fuer erledigt gehalten | `ui.group = "Bogus"` lief durch die Auswertung: **NixOS-Typen sind lazy** — geprueft wird erst, wenn der Wert GELESEN wird, und nur 582-gatus liest das Feld (fuer aktiv ueberwachte Dienste) | Jede neue Typ-/Enum-Pruefung negativ testen; zusaetzlich eine Assertion, die das Feld fuer jeden Eintrag auswertet |
| Negativtest mit neuer Datei | Der Check sah die Datei nicht: `git+file`-Flakes kopieren nur den **getrackten** Stand, untracked Files sind unsichtbar | Probe-Datei mit `git add -N` stagen, messen, danach `git rm --cached` + `rm` |
| IP-Filter/TTL auf Cloudflare-Tokens (Sicherheitsvorschlag) | für DDNS eine Selbstblockade (die IP *soll* sich ändern), für ACME ein stiller Renewal-Ausfall | Maßnahmen gegen ihre eigene Zweckbestimmung prüfen, bevor man sie übernimmt |
