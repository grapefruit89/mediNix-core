# Code-Abgleich (Phase 6: Verifikation der Entwurfshypothesen)

> Vergleicht alle 22 `better`-Entscheidungen mit dem tatsächlichen Code im Repository.
> Stand: 2026-10-25.

## Zusammenfassung

- **Geprüfte Einträge gesamt:** 22
- **Offen:** 17
- **Umgesetzt:** 1
- **Konflikt:** 1
- **Unklar (Live-Test nötig):** 3

---

## D-02-01: Caddy Catch-All: abort durch respond 404 ersetzen
- **Datei:** /home/moritz/repos/mediNix-core/51-ingress/511-caddy.nix
- **Zeile/Bereich:** 340–348
- **Ist-Zustand:** bestätigt: catchAllSites rendert 'abort' für *.${domain} sowohl bei HTTP als auch HTTPS (Zeilen 341 und 345).
- **Soll-Zustand:** catchAllSites rendert 'respond "Get off my lawn" 404' für *.${domain}, sowohl HTTP als auch HTTPS.
- **Status:** offen
- **Risiko:** gering
- **Begründung Status:** abort ist im Catch-All-Block noch aktiv; Ersetzung durch respond 404 schließt TCP sauber ab und triggert die CrowdSec-Detektion.

## D-03-01: CrowdSec: Hub-Collections um crowdsecurity/http-probing erweitern
- **Datei:** /home/moritz/repos/mediNix-core/51-ingress/516-crowdsec.nix
- **Zeile/Bereich:** 147
- **Ist-Zustand:** bestätigt: hub.collections = [ "crowdsecurity/caddy" ]; (Zeile 147); http-probing fehlt.
- **Soll-Zustand:** hub.collections um "crowdsecurity/http-probing" erweitern.
- **Status:** offen
- **Risiko:** gering
- **Begründung Status:** Reines Hinzufügen des Collection-Strings in die Nix-Liste ohne Nebeneffekte auf bestehende Scenarios.

## D-03-03: CrowdSec: Ban-Dauer von 4h auf 168h (7 Tage) verlängern
- **Datei:** /home/moritz/repos/mediNix-core/51-ingress/516-crowdsec.nix
- **Zeile/Bereich:** 164
- **Ist-Zustand:** bestätigt: duration = "4h"; in den Profil-Entscheidungen (Zeile 164).
- **Soll-Zustand:** Dauer auf duration = "168h" anheben oder Option `medinix.crowdsec.banDuration` einführen.
- **Status:** offen
- **Risiko:** gering
- **Begründung Status:** Erhöht die Blockadedauer für scannende IPs deklarativ im CrowdSec-Profil; keine strukturellen Risiken.

## D-04-03: Secret-Management: *.cred und *.encrypted in .gitignore ergänzen
- **Datei:** /home/moritz/repos/mediNix-core/.gitignore
- **Zeile/Bereich:** 11–15
- **Ist-Zustand:** bestätigt: .gitignore enthält *.key, *.age, secrets/, *.env; *.cred und *.encrypted fehlen vollständig.
- **Soll-Zustand:** *.cred und *.encrypted in .gitignore ergänzen.
- **Status:** offen
- **Risiko:** gering
- **Begründung Status:** Wichtige Sicherheitsergänzung, verhindert versehentliches Committen hardwaregebundener systemd-creds-Blobs.

## D-04-04: Pocket-ID: Umstellung auf Unix Domain Socket (UDS) evaluieren
- **Datei:** /home/moritz/repos/mediNix-core/51-ingress/512-pocket-id.nix
- **Zeile/Bereich:** 79, 245
- **Ist-Zustand:** bestätigt: Hört auf Loopback 127.0.0.1:5120; keine Erwähnung von UNIX_SOCKET oder TRUST_PROXY im Modul vorhanden.
- **Soll-Zustand:** Testweise UNIX_SOCKET + TRUST_PROXY=true setzen, Audit-Log prüfen. Wenn IPs erscheinen: umstellen.
- **Status:** unklar
- **Risiko:** mittel
- **Begründung Status:** Live-Test nötig – Upstream Gin PR #3359 fixt Bug #1249 möglicherweise erst ab v2.18.0; im Code existiert noch kein UDS-Support und Caddy-Forward-Auth muss am laufenden Prozess auf IP-Forwarding getestet werden.

## D-04-04: oauth2-proxy: Umstellung auf Unix Domain Socket
- **Datei:** /home/moritz/repos/mediNix-core/51-ingress/517-oauth2-proxy.nix
- **Zeile/Bereich:** 126
- **Ist-Zustand:** bestätigt: httpAddress = "http://127.0.0.1:${toString svc.port}"; (Zeile 126).
- **Soll-Zustand:** httpAddress = unix:///run/oauth2-proxy/oauth2-proxy.sock; 511 forward_auth-Upstream anpassen.
- **Status:** offen
- **Risiko:** mittel
- **Begründung Status:** Nativ in oauth2-proxy möglich, erfordert jedoch Anpassung der Socket-Berechtigungen und des Upstreams in 511-caddy.nix.

## D-05-01: mDNS-Ausmusterung: 515-mdns.nix entfernen / deaktivieren
- **Datei:** /home/moritz/repos/mediNix-core/51-ingress/515-mdns.nix
- **Zeile/Bereich:** 1–186
- **Ist-Zustand:** bestätigt: 515-mdns.nix existiert mit 186 Zeilen und startet Avahi-Publishing.
- **Soll-Zustand:** Modul entfernen oder per Option standardmäßig deaktivieren. 515-blocky.nix übernimmt Split-DNS.
- **Status:** offen
- **Risiko:** gering
- **Begründung Status:** Caddy bindet .local bereits nicht mehr; Avahi kann gefahrlos ausgemustert werden, sobald Split-DNS aktiv ist.

## D-06-01: WAN-IP: Speedport-Adapter via Default-Gateway
- **Datei:** /home/moritz/repos/mediNix-core/51-ingress/513-cloudflare-dns.nix
- **Zeile/Bereich:** 188–195
- **Ist-Zustand:** abweichend: Nutzt externe HTTP-Echo-Dienste (for url in https://ifconfig.me https://api.ipify.org; do); keine speedport-api in flake.nix oder 513 vorhanden.
- **Soll-Zustand:** WAN_IP-Ermittlung auf modularen Provider-Dispatch (Router/DNS) umstellen. Speedport-Adapter: speedport-api public_ip_v4 via Default-Gateway.
- **Status:** unklar
- **Risiko:** hoch
- **Begründung Status:** Live-Test nötig – keine Speedport-API-Integration in flake.nix oder 513 vorhanden; ob der Speedport Smart 4 die Public IP unauthentifiziert liefert, muss am physischen Router getestet werden.

## D-06-02: Keine festen Router-IPs: Default-Gateway dynamisch ableiten
- **Datei:** /home/moritz/repos/mediNix-core/51-ingress/513-cloudflare-dns.nix
- **Zeile/Bereich:** 180–186
- **Ist-Zustand:** bestätigt: LAN-IP wird dynamisch ermittelt (ip route get 1.1.1.1); Router-IP ist noch nicht als Gateway-Variable abstrahiert.
- **Soll-Zustand:** ROUTER_IP aus Default-Gateway ableiten für lokale Router-Abfragen.
- **Status:** offen
- **Risiko:** gering
- **Begründung Status:** Standard-Linux-Mechanismus (ip route show default | awk '{print $3}'), der ohne Risiko in das Update-Skript eingebunden werden kann.

## D-06-04: Modularer Provider-Dispatch für DDNS via types.enum
- **Datei:** /home/moritz/repos/mediNix-core/51-ingress/513-cloudflare-dns.nix
- **Zeile/Bereich:** 35–60
- **Ist-Zustand:** bestätigt: Feste for-Schleife mit ifconfig.me / ipify.org; kein Provider-Dispatch vorhanden.
- **Soll-Zustand:** Einführen von options.medinix.dns.ddns.wanIp.provider.
- **Status:** offen
- **Risiko:** gering
- **Begründung Status:** Reine Option-Deklaration mit Fallback-Mechanismus, abwärtskompatibel umsetzbar.

## D-07-03: PQC-Hardening: Hybriden Schlüsselaustausch für SSH dokumentieren
- **Datei:** /home/moritz/repos/mediNix-core/docs/adr/ADR-52-ssh-port-policy.md
- **Zeile/Bereich:** 1–75
- **Ist-Zustand:** bestätigt: ADR-52 regelt Port 5202 und Key-Only Auth; Erwähnung von mlkem768x25519 fehlt.
- **Soll-Zustand:** Empfehlung für hybride PQC-Kex (mlkem768x25519) in SSH-Hardening ergänzen.
- **Status:** offen
- **Risiko:** gering
- **Begründung Status:** Reine Dokumentationserweiterung in der Architektur-Dokumentation.

## D-08-03: Firewall: Deklarativer Debug-Reject-Modus mit Logging
- **Datei:** /home/moritz/repos/mediNix-core/52-security/520-core-security.nix
- **Zeile/Bereich:** 85–95
- **Ist-Zustand:** bestätigt: recommended.firewall.checkReversePath deklariert; kein expliziter debugReject-Schalter vorhanden.
- **Soll-Zustand:** Option für debugReject mit Log-Präfix zur Diagnose vorschlagen.
- **Status:** offen
- **Risiko:** mittel
- **Begründung Status:** REJECT erleichtert Debugging, darf aber im Normalbetrieb wegen Information-Leakage nicht dauerhaft aktiv sein.

## D-09-03: Kernel-Hardening: Modul-Blacklist & lockKernelModules evaluieren
- **Datei:** /home/moritz/repos/mediNix-core/52-security/520-core-security.nix
- **Zeile/Bereich:** 70–84
- **Ist-Zustand:** bestätigt: medinix.recommended.sysctl ist deklariert; Modul-Blacklist und lockKernelModules fehlen.
- **Soll-Zustand:** Empfohlene Modul-Blacklist (z. B. medinix.recommended.blacklistedKernelModules) vorschlagen.
- **Status:** unklar
- **Risiko:** mittel
- **Begründung Status:** Live-Test nötig – security.lockKernelModules sperrt dynamisches Laden nach Boot; muss auf Hardware getestet werden, um Inkompatibilitäten mit USB/VPN auszuschließen.

## D-10-01: Power-Management: schedutil und auto-cpufreq im Manifest verankern
- **Datei:** /home/moritz/repos/mediNix-core/docs/adr/ADR-0003-architektur-manifest.md
- **Zeile/Bereich:** 1–120
- **Ist-Zustand:** bestätigt: Beschreibt mediNix-Appliance; Governor schedutil und auto-cpufreq sind nicht erwähnt.
- **Soll-Zustand:** Empfehlung für schedutil / auto-cpufreq in Host-Dokumentation aufnehmen.
- **Status:** offen
- **Risiko:** gering
- **Begründung Status:** Reine Dokumentationsergänzung zur Leitlinie für Host-Repositories (q958).

## D-10-02: GPU-Transcoding: Intel GuC/HuC Kernel-Parameter in Jellyfin-ADR
- **Datei:** /home/moritz/repos/mediNix-core/docs/adr/ADR-551-jellyfin-media-playback.md
- **Zeile/Bereich:** 1–130
- **Ist-Zustand:** bestätigt: Dokumentiert Jellyfin-Transcoding; GuC/HuC-Parameter i915.enable_guc=3 fehlt.
- **Soll-Zustand:** GuC/HuC Kernel-Parameter i915.enable_guc=3 als Host-Voraussetzung vermerken.
- **Status:** offen
- **Risiko:** gering
- **Begründung Status:** Dokumentationsergänzung zur optimalen Hardware-Transcoding-Effizienz auf Intel UHD 630.

## D-11-01: 51-Baum: Slot 515 für 515-blocky.nix nachnutzen
- **Datei:** /home/moritz/repos/mediNix-core/51-ingress/515-mdns.nix
- **Zeile/Bereich:** Dateiname / Modul-Slot
- **Ist-Zustand:** bestätigt: 515-mdns.nix deklariert Avahi; 515-blocky.nix existiert noch nicht.
- **Soll-Zustand:** 515-mdns.nix durch 515-blocky.nix ersetzen (UID 5150, Port 53, Split-DNS).
- **Status:** offen
- **Risiko:** mittel
- **Begründung Status:** Erfordert Neuanlage des Blocky-Moduls und anschließenden Flake-Syntaxcheck.

## D-11-02: 51-Baum: Vollständige Ausmusterung von 515-mdns.nix
- **Datei:** /home/moritz/repos/mediNix-core/51-ingress/515-mdns.nix
- **Zeile/Bereich:** 1–186
- **Ist-Zustand:** bestätigt: Modul existiert im Repository.
- **Soll-Zustand:** Modul löschen bzw. durch Blocky ersetzen.
- **Status:** offen
- **Risiko:** gering
- **Begründung Status:** Keine anderen Module hängen hart von 515-mdns.nix ab.

## D-11-03: 51-Baum: LAN-Publishing aus 513 entfernen & Provider-Lib auslagern
- **Datei:** /home/moritz/repos/mediNix-core/51-ingress/513-cloudflare-dns.nix
- **Zeile/Bereich:** 314–328
- **Ist-Zustand:** bestätigt: Enthält LAN-Record-Logik und RFC1918-Pruning.
- **Soll-Zustand:** LAN-Publishing entfernen und WAN-IP-Ermittlung über Provider-Lib anbinden.
- **Status:** offen
- **Risiko:** gering
- **Begründung Status:** Bereinigung von Legacy-Code, da Blocky die LAN-Auflösung übernimmt.

## D-12-01: Dezimalrahmen: Fraktales Dateisystem-Ordnungsprinzip in ADR-0000 verankern
- **Datei:** /home/moritz/repos/mediNix-core/docs/adr/ADR-0000-dezimalrahmen-verfassung.md
- **Zeile/Bereich:** 1–50
- **Ist-Zustand:** bestätigt: Formuliert Dezimalrahmen primär als Modul- und Port/UID-Matrix.
- **Soll-Zustand:** Präambel erweitern: Dezimalrahmen als fraktales Dateisystem- und Ordnungsprinzip etablieren.
- **Status:** offen
- **Risiko:** gering
- **Begründung Status:** Klarstellende Dokumentationserweiterung ohne Code-Auswirkungen.

## D-12-03: Dezimalrahmen: Secret-Pfade und Credentials-Speicherort in ADR-0000 ergänzen
- **Datei:** /home/moritz/repos/mediNix-core/docs/adr/ADR-0000-dezimalrahmen-verfassung.md
- **Zeile/Bereich:** 180–220
- **Ist-Zustand:** bestätigt: Erwähnt Credentials noch nicht als eigene Strukturkomponente.
- **Soll-Zustand:** Abschnitt über Credentials-Speicherorte und Secret-Pfade ergänzen.
- **Status:** offen
- **Risiko:** gering
- **Begründung Status:** Reine Dokumentationserweiterung zur Harmonisierung mit ADR-521.

## D-14-01: Caddy: customConfig strikt nach forward_auth und IP-Filter platzieren
- **Datei:** /home/moritz/repos/mediNix-core/51-ingress/511-caddy.nix
- **Zeile/Bereich:** 224–228
- **Ist-Zustand:** bestätigt: route { ${stripAuthHeaders} ${lib.optionalString isLocal lanAbort} ${authBlock} ${customConfig} ... }
- **Soll-Zustand:** customConfig zwingend nach forward_auth und IP-Filtering einsortieren.
- **Status:** umgesetzt
- **Risiko:** gering
- **Begründung Status:** Bereits im Code verifiziert: ${customConfig} wird in Zeile 228 gerendert – strikt nach ${lanAbort} (Zeile 226) und ${authBlock} (Zeile 227).

## D-14-02: Ingress: Semantische CIDR-Validierung
- **Datei:** /home/moritz/repos/mediNix-core/lib/ingress-access.nix
- **Zeile/Bereich:** nicht zutreffend (bereits in /home/moritz/repos/mediNix-core/51-ingress/511-caddy.nix Zeilen 431–450 und /home/moritz/repos/mediNix-core/default.nix Zeilen 400–415)
- **Ist-Zustand:** abweichend/korrigiert: `lib/ingress-access.nix` berechnet nur vHost-Access-Gruppen und enthält keine CIDR-Prüfungen. Die semantische CIDR-Prüfung existiert bereits in `511-caddy.nix` (Zeilen 431–450) und `default.nix` (Zeilen 400–415).
- **Soll-Zustand:** Keine Änderung in lib/ingress-access.nix nötig — semantische CIDR-Validierung ist bereits in 511-caddy.nix und default.nix umgesetzt.
- **Status:** konflikt
- **Risiko:** gering
- **Begründung Status:** Die Code-Referenz auf `lib/ingress-access.nix` ist falsch platziert, da die semantische CIDR-Validierung bereits in `511-caddy.nix` (Zeile 431–450) und im Optionstyp von `default.nix` implementiert ist; ein Einbau in `ingress-access.nix` wäre redundant und ein Schnittstellenbruch.

