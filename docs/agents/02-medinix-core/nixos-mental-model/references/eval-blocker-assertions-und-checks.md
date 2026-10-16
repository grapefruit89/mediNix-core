# Eval-Blocker, Assertions und Checks - Belegsammlung (2026-10-16)

Sechs Kurzregeln, jede mit Beleg aus der mediNix-core-Session vom 2026-10-16
(`/home/moritz/repos/mediNix-core`, Branch `audit-2026-10-15`).

## 1. Eval-Blocker: erst bisecten, dann Hypothesen
- Rezept: `git worktree add --detach /tmp/opencode/bisect-wt <roter-commit>`; Probe-Skript mit
  `nix eval --option eval-cache false .#checks.x86_64-linux.<ein-check>.drvPath` (Exit 0 = gruen);
  `git bisect start <bad> <good>` + `git bisect run <probe>`.
- `--option eval-cache false` ist Pflicht: Nix cached Evaluierungsfehler (sonst "gruene" Antworten).
- Probe = **ein** Check, nicht die ganze Leiter (`nix flake check` = 40 Checks, dauert Minuten).
- Beleg: 4 Hypothesen (591 -> 585 -> Manifest-Leser -> 591 als Erzwingungspunkt) waren falsch;
  der Bisect fand den Bruch commit-genau (`2254f8c`) in 5 Messungen. Siehe L-046, AB-041.

## 2. Fixpunkt-Kreuz
Ein Modul darf nicht gleichzeitig **einen Teil** von `config` schreiben und **einen anderen Teil**
im selben Modul lesen. Beleg: `58-observability/585-exporters.nix` (`2254f8c`) schrieb
`users.users`/`users.groups` und las `config.medinix.manifest` -> `infinite recursion`, weil
`users.users` (immer gebraucht fuer `system.build.toplevel`) an `manifest` haengt.

## 3. Assertions laufen WAEHREND der Config-Auswertung - Checks danach
- Assertions duerfen nur **Quellen** lesen (Registry, Absichts-Optionen). Pruefungen des
  **abgeleiteten Ergebnisses** (`users.users`, `systemd.services`) gehoeren in `checks.*` in
  `/home/moritz/repos/mediNix-core/flake.nix` (siehe AB-040, ADR-040).
- Beleg: die Band-Pruefung in `59-guardrails/591-cross-domain.nix` blockierte als Assertion jede
  Konfiguration mit synthetischem Manifest-Dienst (`probe`) - jetzt
  `checks.mediNix-frameband-fremdkonten` (L-048), negativ getestet mit `users.users.eindringling`.

## 4. Engine-Defaults vs. nixpkgs-Assertions
`users.mutableUsers = lib.mkDefault false` (Engine, `lib/decimal-framework.nix`) aktiviert die
nixpkgs-Assertion "Neither the root account nor any wheel user has a password or SSH authorized
key" (Bedingung: `!mutableUsers && !allowNoPasswordLogin`). Jede Konfiguration, deren
`system.build.toplevel` gebaut wird, braucht ein privilegiertes Konto. Pruefkonfigurationen:
test-only Stub (`testHostAccess`) - echte Hosts brauchen eine echte Quelle. Siehe L-047.

## 5. Ein Check-Ausgang ist kein Ursachenbeleg
Der rote Test `mediNix-negative-ankreuzbogen` sah nach "585 hat die Form geaendert" aus; er war
Folge von L-047/L-048 (sein `evaluates`-Helfer faengt den Fehler und meldet irrefuehrend
"der Test beweist nichts"). Vor jeder Zuschreibung: Testcode lesen **und** die Config mit
`builtins.getFlake` + identischer Modulliste nachbauen, um die echte Meldung zu sehen.

## 6. Mess-Metrik und Build-Gates
- `nix flake check` zaehlt auch `apps`/`devShells`/`formatter`/`modules`/`overlays`/`packages` mit;
  der Flake hat 40 Checks (+10 andere Outputs = max. 50 Zeilen). Kriterium ist **0 ❌**, nicht "✅ >= N".
- Ein fehlgeschlagener Check erscheint als `❌ checks.…` (mit Trace), **nicht** immer als `error:`-Zeile.
- `--no-build` verdeckt die Build-Gates: `nixfmt-check`, `statix-check`, `deadnix-check`,
  `nixmeta-check`, `mediNix-unit-scripts` muessen **gebaut** werden
  (`nix build .#checks.x86_64-linux.<name>`), sonst bleibt "eval gruen, CI rot" unsichtbar.
