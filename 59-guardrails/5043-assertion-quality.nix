# ---
# id: "ADR-5043"
# title: "Assertion Quality Standard (fail-closed, readable what/why/fix)"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-12
# links:
#   adr: ADR-0000 (fail-closed Prinzip), ADR-5050 (systemd-hardening-baseline)
#   skill: medinix-assertion-quality
#   repo-harvest: mynixos-knowledge-base (GUIDE-58-seven-quality-gates, Tor 4 SRE-Hardening)
# ---

# ADR-5043 — Assertion Quality Standard

## Status
Angenommen (2026-08-12). Verbindlich für alle `assertions` / `invariants` in mediNix-core.

## Kontext
Assertions sind die einzige Verteidigungslinie gegen fehlerhafte Consumer-Konfigurationen
(fail-closed: Build bricht, nie nur Warnung — ADR-0000). Bisher lagen Assertions verstreut in
Modulen mit inkonsistenter Message-Qualität. Dieses ADR standardisiert das Format und die
Semantik, damit jeder Build-Fehler selbst-erklärend ist.

## Entscheidung

### 1. Zwei Kategorien (niemals mischen)
- **Invarianten** (`INV-*`): Architektur-Garantien des Systems. Unabhängig von User-Config.
  Beispiele: Port = Num×10, GID=5000, 127.0.0.1-Binding, keine Container.
  Zentrale SSoT: `59-guardrails/590-registry.nix` (`invariants` Attrset).
- **Errors** (`VPN-*` / `TLS-*` / `AUTH-*` / `DNS-*` / `SEC-*` / `STORE-*`):
  User-Config-Fehler. Zentrale SSoT: `590-registry.nix` (`errors` Attrset).

### 2. Message-Format (VERBINDLICH)
Jede Assertion-Message MUSS enthalten:
- **Was** ist falsch (konkret, keine Vagheit)
- **Warum** es falsch ist (Architektur-Begründung)
- **Wie** der Fix aussieht (konkrete Anweisung)

Schema:
```
[INVARIANTE|CODE] KURZE_BESCHREIBUNG.
  Erwartet: <korrekter Zustand>
  Gefunden: <tatsächlicher Zustand>
  Fix: <konkrete Anweisung, z.B. "setze grapefruitMedia.X.enable = true">
  Ref: ADR-XXXX
```

### 3. Fail-closed (KEINE Ausnahme)
- Assertions brechen den `nix flake check` mit **Exit-Nonzero**.
- Niemals `warn` oder `lib.warn` — das wird im Deploy übersehen.
- Conditional: nur `lib.mkIf cfg.enable` wrappen, nicht die Assertion selbst abschwächen.

### 4. Keine dynamischen Strings in Registry
`590-registry.nix` enthält statische Message-Templates (String, kein `toString` zur Laufzeit).
Dynamische Werte (z.B. tatsächlicher Port) werden im aufrufenden Modul via `lib.mkIf`
in die Message injiziert — die Registry bleibt die SSoT für den Text.

### 5. Jeder Bug → Invariante
Wird ein Bug gefunden (Audit, Deploy, Runtime), MUSS er als Invariante/Error in
`590-registry.nix` verewigt werden, die den gleichen Fehler beim nächsten Mal im Build
abfängt. Ad-hoc-Fixes ohne Registry-Eintrag sind verboten (sonst driftet die Docs weg).

## Konsequenzen
- `medinix-assertion-quality` Skill ist die Implementierungs-Referenz (grep-Checks für Format).
- `medinix-pre-commit` Gate prüft: keine Assertion ohne `[CODE]`-Prefix, keine leeren Messages.
- Consumer die mediNix-core importieren bekommen lesbare, actionable Build-Fehler.

## Anti-Patterns (VERBOTEN)
- `assertions = [ { assertion = ...; message = "something is wrong"; } ];` (kein Was/Warum/Fix)
- `lib.warn "..."` statt `mkInvariant` (kein Fail-closed)
- Inline-Text in Modulen statt zentraler Registry (Docs-Drift)
- `INV-*` für Config-Fehler nutzen (das sind `errors`, nicht Invarianten)
