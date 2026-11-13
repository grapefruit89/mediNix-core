---
title: 582-gatus — Health-Dashboard (Manifest-Konsument)
---

# 582-gatus — Gatus Health-Dashboard

**Datei:** [`58-observability/582-gatus.nix`](../../58-observability/582-gatus.nix) · **Nummer:** 582 → Port/UID 5820 · **ADR:** [ADR-582](../adr/ADR-582-gatus-health-dashboard.md)

## 1. Zweck

Ein Dashboard, das in einer Ansicht zeigt, ob die Dienste laufen. Ohne Gatus gibt es
keinen Ort für „läuft alles?" — nur `journalctl` pro Unit.

## 2. Warum nicht `services.gatus`

Zwei Gründe, beide im Quelltext belegt (`58-observability/582-gatus.nix:67-69`):

1. Das Upstream-Modul setzt `DynamicUser = true`. Das verletzt die gelockten Invarianten
   (`DynamicUser = false`, `UID = Port = 5820`).
2. Es bindet standardmäßig Port 8080 statt 5820 — der Dezimalrahmen wäre gebrochen.

Deshalb baut das Modul die Konfiguration selbst (`gatusConfig`) und die Unit über die
Factory. Das ist der Musterfall „Upstream-Modul passt nicht in den Rahmen": **eigener
Block statt `mkForce`**.

## 3. Architektur-Muster

**Manifest-Konsument.** Gatus kennt keine Dienste. Es liest `config.medinix.manifest`
und filtert (`582-gatus.nix:33-35`):

```
m.enable && m.monitoring.enable && m.monitoring.type != "none"
```

Daraus entstehen zwei Listen: HTTP (`[STATUS] == expectedStatus`, Intervall 30 s) und
TCP (`[CONNECTED] == true`). Alles andere wird ignoriert.

**Besitz:** `ownsAccount = false` (`582-gatus.nix:135`). `users.users.gatus`, die
UPG-Gruppe und das `StateDirectory` gehören der Engine (`50-core/501-decimal-engine.nix`),
nicht dem Modul.

**Unit-Entstehung:** Die Factory liefert ein ganzes Config-Fragment (`systemd.*` +
`medinix.*`). Deshalb wird sie als eigener Block in `mkMerge` gelegt und nicht
zugewiesen (`582-gatus.nix:127-142`).

**Selbstüberwachung ist aus:** `monitoring.enable = false` (`582-gatus.nix:105`), sonst
prüfte Gatus sich selbst und meldete beim eigenen Neustart einen Ausfall.

## 4. Fallstricke

| Fallstrick | Wirkung | Schutz |
|---|---|---|
| Dienst hat keinen oder einen falschen Manifest-Eintrag | fehlt im Dashboard, **Build bleibt grün** | keiner — bewusst: das Manifest ist die Quelle |
| `monitoring.type = "http"` ohne `healthPath` | Build bricht | Assertion in `50-core/service-contract.nix:414-422` (fail-closed) |
| `monitoring.type = "none"` bei `enable = true` | Dienst wird nicht überwacht | gewollt für Gatus selbst |
| ICMP-Prüfungen | werden nicht generiert | bräuchten `CAP_NET_RAW` + `AmbientCapabilities` (`582-gatus.nix:131-132`) |
| ntfy aus | Endpunkte ohne `alerts` | `lib.optional (svc.ntfy.enable or false)` |

## 5. Abhängigkeiten

Liest: `50-core/registry.nix` (Port/UID/StateDir), `50-core/service-factory.nix` (Unit),
`config.medinix.manifest` (Endpunkte), `config.medinix.ntfy` (Alarme, optional).

Liest **nicht**: die Dienste selbst. Gatus kennt nur, was im Manifest steht.

## 6. Prüfen

```bash
systemctl show gatus -p User -p DynamicUser -p StateDirectory
ss -ltnp | grep 5820
curl -sI http://127.0.0.1:5820/
```

Erwartet: `DynamicUser=no`, ein Listener auf 5820, HTTP-Antwort der Weboberfläche.
`User` und `StateDirectory` müssen zum Registry-Eintrag passen.

## 7. Offene Fragen

- **ungeprüft:** ob `585-exporters` die Gatus-Metriken (`metrics = true`) tatsächlich
  abholt. Gegenprobe: Exporter-Port abfragen und im Metrik-Text nach `gatus` suchen.
- **ungeprüft:** ob die JSON-API (`/api/v1/…`) in der ausgelieferten Gatus-Version
  denselben Pfad hat. Gegenprobe: `curl` gegen den Pfad, Statuscode prüfen.
- **ungeprüft:** ob `monitoring.healthPath` für alle aktiven HTTP-Dienste gesetzt ist.
  Die Assertion greift nur bei `type = "http"` **und** `enable`; ein Dienst mit
  `type = "none"` fällt still heraus.
