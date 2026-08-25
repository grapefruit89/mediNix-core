# mediNix-Core — Architektur-Abschluss

Belege: systemd (`src/bpf/socket-bind.bpf.c`, `src/shared/parse-helpers.c`, `src/core/socket.c`, `src/core/exec-invoke.c` via Context7) · nftables-Wiki (Chain-Typen, `meta skuid`) · Caddy-Doku (`conventions`, `caddyfile/directives/bind`) · nixpkgs @ `ec2d622` (`nftables.nix`, `firewall-nftables.nix`, `firewall.nix`) direkt aus der Quelle.

---

## 1. Priorisierte Entscheidungs-Tabelle

| # | Thema | Entscheidung | Core / Host / Test | Prio | Begründung |
|---|---|---|---|---|---|
| 1 | **Counter in jeder Kill-Chain-Regel** | Jede `accept`/`drop`-Regel der Mark- und Filter-Chain trägt `counter`. Nicht optional, nicht nur zum Debuggen. | **Core** (Regelerzeugung) | **jetzt** | Ohne Zähler ist nicht unterscheidbar, ob ein Paket die Chain nie erreicht, dort gedroppt wird oder sie passiert und später stirbt. Das ist die Voraussetzung für Punkt 2 — und der Grund, warum „VPN-oben kaputt" bisher eine Vermutung ist. |
| 2 | **Messung vor Änderung** | Kein Eingriff am Kill-Switch, bevor Abschnitt 2 durchlaufen ist. | **Test** | **jetzt** | Nach `firewall-nftables.nix` @ `ec2d622` kann `checkReversePath` (Default `true`) das Symptom vollständig allein erklären. Ein Umbau am Kill-Switch würde dann ein funktionierendes Modul „reparieren". |
| 3 | **`checkReversePath`: gezielt statt global** | Vorzug: `networking.firewall.extraReversePathFilterRules` mit einer `iifname <vpn-if> accept`-Zeile. Fallback: `checkReversePath = "loose"`. Nie `false`. | **Host** (Singleton); Core **empfiehlt** und **assertiert** | **jetzt** | Die generierte Chain endet auf `jump rpfilter-allow`, und `chain rpfilter-allow { ${cfg.extraReversePathFilterRules} }` ist genau die vorgesehene Ausnahmestelle. `"loose"` entfernt `. iif` für **alle** Interfaces; die gezielte Regel nur für den Tunnel. Anti-Spoofing bleibt sonst intakt. |
| 4 | **Loopback-Accept für den konfinierten UID entfällt** | In Mark- **und** Filter-Chain: kein pauschales `ip daddr 127.0.0.0/8 accept` für `skuid <vpn-uid>`. Stattdessen `drop`, mit einer aus `localAllow` erzeugten Ausnahmeliste (Default leer). | **Core** | **jetzt** (an denselben Eingriff hängen) | Löst zwei offene Punkte mit einer Änderung: das East-West-Loch **und** den DNS-Fallback. Fällt glibc mangels `nameserver` auf `127.0.0.1` zurück, wird die Query gedroppt statt am Tunnel vorbeigeleitet — aus einem Leck wird ein lauter Fehler. |
| 5 | **Mark- und Filter-Chain beide `family = "inet"`** | Eine Tabelle, ein Mark-Wert, v4 und v6 gemeinsam. | **Core** | **jetzt** (kostenlos) | nftables-Wiki: *route … supported by the ip, ip6 and inet table families* (Output-Hook). Die bisherige `ip`-only-Mark-Chain lässt v6 unmarkiert und macht jede IPv6-Option zu toter Konfiguration. |
| 6 | **`src` in der Policy-Route** | Die Quelladresse gehört in den Route-Vertrag: `host.vpn.address` (`nullOr`, Default `null`), Core baut daraus die Route. | Core (Mechanismus) / **Host** (Wert) | **nach Messung** | nftables-Wiki: die `route`-Chain löst ein Reroute aus, *wenn ein Headerfeld oder die Mark geändert wird*. Ob dabei auch die Quelladresse neu gewählt wird, hängt davon ab, ob der Socket bereits gebunden ist. [Annahme, Kernel-Verhalten — mit `ip route get … mark …` messbar, siehe 2.] Nur bauen, wenn die Messung es zeigt. |
| 7 | **Switch-/Stop-Invariante** | Formulierung: *„UID `<vpn-uid>` hat zu keinem Zeitpunkt Egress ohne aktive `medinix_*`-Tabellen."* Durchsetzung über die `Requires`-Kette Dienst → Route-Unit → `nftables.service`. | Core (Ordering) / **Test** | **nach Messung** | `nftables.nix` @ `ec2d622`: `reloadIfChanged = true` und `ExecReload` ist eine einzige `nft -f`-Datei mit Deletions **und** neuen Tabellen ⇒ der Switch ist atomar, dort ist kein Fenster. `ExecStop` löscht die Tabellen ⇒ die verbleibende Lücke ist ein `systemctl stop nftables`, und nur die Stop-Propagation muss bewiesen werden. |
| 8 | **East-West nicht generalisieren** | Regeln werden **nur** für Dienste mit `egressClass = "vpn"` erzeugt. `localAllow` existiert als Registry-Feld für alle, bleibt für alle anderen wirkungslos. | **Core** | jetzt (als Teil von 4) | East-West-Regeln schützen ausschließlich gegen die *Umgehung einer Egress-Beschränkung*. Wo keine Beschränkung existiert, gibt es nichts zu umgehen — eine Vollmatrix wäre Regelpflege ohne Bedrohungsmodell. |
| 9 | **`SocketBindDeny/Allow` als Port-Invariante** | Wortlaut in Optionsbeschreibung, Registry-Doku und Checkliste: *„kein fremder und kein zusätzlicher Port"*. Ausdrücklich **keine** Aussage über die Bind-Adresse. | **Core** | nach VPN+Test | `socket-bind.bpf.c`: `match()` liest ausschließlich `address_family`, `protocol`, `port`. Der BPF-Kontext enthält `user_ip4`, keine Regel wertet ihn aus. Nur `cgroup/bind4`/`bind6` gehookt ⇒ kein Effekt auf `AF_UNIX`, keiner auf `connect()`. |
| 10 | **Bind-Adresse: Lücke sichtbar machen statt wegdefinieren** | Neues Registry-Feld, etwa `bindControl = "app" \| "none"`: hält die App eine konfigurierte Bind-Adresse ein oder nicht. Bei `"none"` ist der `ss`-Test **Pflicht**, und die Doku sagt: erreichbar auf allen Interfaces, sobald der Host den Port öffnet. | **Core** (Registry) + **Test** | nach VPN+Test | Es gibt **keinen** Per-Unit-Mechanismus für die Bind-Adresse — weder `SocketBind*` (9) noch sonst etwas ohne App-Kooperation. Die einzige verbleibende Schranke ist Default-Deny-Input plus die Assertion gegen `allowedTCPPorts`. Ein selbstbeschreibender Core benennt das, statt eine Garantie zu behaupten, die er nicht hat. |
| 11 | **Caddy `:80/:443`** | Bleibt bei `AmbientCapabilities` **und** `CapabilityBoundingSet` = `CAP_NET_BIND_SERVICE`, zwingend mit `PrivateUsers = false`. Zweitoption für den Host: `net.ipv4.ip_unprivileged_port_start`. Socket-Activation: **nein**. | Core (Caps) / Host (Sysctl-Option) | nach VPN+Test | Caddys `conventions`-Seite listet die Netzwerkschemata `tcp`, `tcp6`, `udp`, `unix` — **kein** `fd/`. [zu verifizieren am Pin: `caddy adapt` mit `bind fd/3`.] Bis dahin nicht darauf bauen. Der Sysctl ist netns-scoped und braucht überhaupt keine Capability — architektonisch die sauberere Host-Option. |
| 12 | **`PrivateUsers = false` überall** | Bestätigt, als Assertion, nicht nur als Profil-Default. | **Core** | nach VPN+Test | `exec-invoke.c` beschreibt den `identity`-Modus als *„gaining capability set isolation"* — genau diese Isolation ist das Problem: Capabilities wirken im Kind-Userns, die Netzwerk-Namespace gehört dem initialen. [Annahme, praxisbelegt: Bind <1024 und `SupplementaryGroups` auf `/dev/dri` scheitern dadurch.] Cheap zu prüfen im VM-Test. |
| 13 | **`RestrictNamespaces=true`, `AF_NETLINK` behalten, `SystemCallErrorNumber=EPERM`, kein MDWE bei JIT, kein `~@resources`** | Bestätigt, unverändert. `ProcSubset` bleibt **draußen**. | **Core** | nach VPN+Test | `@system-service` enthält `@resources`; ein Deny entfernt `sched_setaffinity`/`setpriority`. `ProcSubset=pid` blendet `/proc/cpuinfo` und `/proc/meminfo` aus, die .NET-GC und ffmpeg lesen. |
| 14 | **Rückfallsperre für die drei Egress-Killer** | Assertion über die **gemergte** `serviceConfig` jeder Unit mit `egressClass = "vpn"`: `IPAddressDeny`, `IPAddressAllow`, `RestrictNetworkInterfaces`, `PrivateNetwork` dürfen nicht gesetzt sein. | **Core** | jetzt (billig) | Alle drei sind cgroup-BPF bzw. Namespace und greifen unterhalb von Routing und fwmark — beim Routing-Debugging unsichtbar. Eine Profil-Konvention verhindert den Rückfall nicht; eine Assertion auf dem Endzustand schon. |
| 15 | **Resource-Profile role-based** | Registry-Feld `resourceClass`; Default setzt **nur** `MemoryHigh`, nie `MemoryMax`, nie `IOWeight`. | **Core**, opt-in | später | `MemoryHigh` drosselt, `MemoryMax` tötet. Auf einem Transcoder ist ein hartes Limit ein Ausfall, kein Schutz. `IOWeight` braucht cgroup-v2-IO-Controller und ist ohne Messung Kaffeesatz. |
| 16 | **Package-Injection** | `package = nullOr package`, Default `null`, Factory nimmt sonst `pkgs.<name>` — **und die Option muss auch benutzt werden**. | **Core** | nach VPN+Test | Ein öffentlicher Flake muss erlauben, ein CVE zu pinnen, ohne zu forken. Eine deklarierte, aber ungenutzte `package`-Option ist schlimmer als keine: sie sieht nach Kontrolle aus. |
| 17 | **Credential-Vertrag** | Bedarf im Core (`credentials.<name>.{format, consumer}`), Lieferung beim Host (`host.credentials.<name>`), beides `nullOr`/`null`, Runtime-Pfad **mit** `.service`-Suffix, genau ein Mechanismus. | Core (Bedarf) / **Host** (Lieferung) | nach VPN+Test | TPM-gesiegelte Credentials sind host-gebundene Artefakte — sie können weder im Flake liegen noch von ihm erzeugt werden. Ein Klartext-Fallback „für den Notfall" wird der Hauptpfad. |
| 18 | **Mover legt sein Ziel nicht an** | `mountpoint`-Prüfung auf Staging **und** Archiv; fehlt eins, Exit ungleich 0. Kein `mkdir -p` auf dem Zielpfad. | **Core** | nach VPN+Test | `RequiresMountsFor` löst auf `-.mount` auf, wenn für den Pfad keine Mount-Unit existiert — die Bedingung ist dann immer erfüllt. Wer das Ziel anlegen darf, schreibt die Mediathek bei fehlendem Mount auf das Root-Dateisystem. |
| 19 | **State vs. Medien: ein Registry-Feld** | `mediaAccess = "none" \| "read" \| "write"` steuert `SupplementaryGroups` und `UMask`. State bleibt unabhängig davon service-eigen `0700`. | **Core** | nach VPN+Test | Zwei getrennte Schalter für dieselbe Entscheidung driften. Die geteilte GID gilt für Mediendaten; State ist nie gruppenlesbar, sonst liest ein kompromittierter Dienst die SQLite-DB des nächsten inklusive API-Keys. |
| 20 | **ACME-Gruppe abgeleitet** | Aus der **effektiv laufenden** Proxy-Unit, nie literal. | **Core** | nach VPN+Test | Bei `reverseProxy = external` heißt die Unit anders als bei `managed`; ein literales `"caddy"` macht `key.pem` unlesbar. |
| 21 | **Auth: eine Quelle** | Nur `ingress.auth.mode`. `authProxyPresent` wird abgeleitet oder gelöscht. | **Core** | nach VPN+Test | Zwei Schalter für dieselbe Entscheidung erlauben die Kombination „App vertraut Proxy-Headern, Proxy setzt keine" — ein Auth-Bypass, den keine Assertion abfängt, weil beide Werte für sich zulässig sind. |
| 22 | **Factory-Rückgabewerte werden gemerged, nie selektiert** | Regel, nicht Empfehlung. | **Core** | jetzt (billig) | Wer `.systemd.services.<n>` aus dem Ergebnis herausgreift, verliert `users.users.<n>` — die Unit läuft dann gegen einen Account, den es nicht gibt. |

---

## 2. Mess- und Verifikationsplan

Vor jeder weiteren Änderung am Kill-Switch. Ziel ist nicht „es geht wieder", sondern **zu wissen, welche der vier möglichen Ursachen zutrifft**. Die vier sind unterscheidbar, wenn man in dieser Reihenfolge misst.

### Stufe 0 — Zähler einbauen (einmalig, Voraussetzung für alles Weitere)

Jede Regel der Mark- und Filter-Chain bekommt `counter`. Ohne das sind die folgenden Messungen nicht interpretierbar.

### Stufe 1 — Erreicht das Paket die Kill-Chain überhaupt?

| Beobachtung | Schluss |
|---|---|
| Mark-Chain-Counter bleibt bei 0 | Das Paket wird vor dem Output-Hook gestoppt — Verdacht: `IPAddressDeny`/`RestrictNetworkInterfaces` (cgroup-BPF, greift beim `connect()`, das Paket entsteht nie) |
| Mark-Counter zählt, `accept`-Counter zählt | Ausgehend ist alles in Ordnung. Problem liegt auf dem **Rückweg** → Stufe 2 |
| Mark-Counter zählt, `drop`-Counter zählt | Mark oder Route stimmen nicht → Stufe 3 |

### Stufe 2 — Droppt die Firewall den Rückweg?

`networking.firewall.logReversePathDrops` einschalten (`firewall.nix` @ `ec2d622` deklariert die Option), Switch, dann bei stehendem Tunnel den Kernel-Log beobachten, während der konfinierte Dienst nach außen verbindet.

| Beobachtung | Schluss |
|---|---|
| `rpfilter drop`-Zeilen mit Quelladressen aus dem Tunnel | **Ursache gefunden.** Der Kill-Switch ist intakt; es fehlt eine Host-Zeile (Entscheidung 3). |
| keine solchen Zeilen | Weiter zu Stufe 3 |

### Stufe 3 — Stimmen Route und Quelladresse?

`ip route get <ziel-ip> mark <mark> from <erwartete-quelle>` und `ip rule show`.

| Beobachtung | Schluss |
|---|---|
| Route zeigt nicht auf das VPN-Interface | `ip rule`/Tabelle fehlt oder falsche Priorität |
| Route zeigt auf das Interface, aber `src` ist die LAN-Adresse | Entscheidung 6 greift: `src` in die Policy-Route |
| Route und `src` korrekt, Handshake steht, Nutzlast nicht | MTU/MSS — zuletzt prüfen, nicht zuerst |

### Stufe 4 — Invarianten, die nach dem Fix zu beweisen sind

| Invariante | Nachweis |
|---|---|
| fail-closed | Tunnel runter ⇒ Egress der UID scheitert |
| fail-open | Tunnel oben ⇒ Egress geht **durch** den Tunnel (nicht nur: geht) |
| Stop-Propagation | `systemctl stop nftables` ⇒ der konfinierte Dienst ist danach nicht mehr aktiv |
| Switch | `nixos-rebuild switch` mitten im Test, danach fail-closed erneut prüfen |
| DNS | Bei leerer `resolv.conf` scheitert die Auflösung, statt über `127.0.0.1` zu gehen |
| East-West | Als konfinierte UID ein anderer Loopback-Port ⇒ Verbindung scheitert |

**Regel:** Solange Stufe 1–3 nicht durchlaufen sind, ist jede Aussage über den Kill-Switch eine Hypothese. Die bisherigen Runden haben drei plausible Ursachen produziert; genau eine Messung unterscheidet sie.

---

## 3. Neue und geschärfte Invarianten

Nur was sich gegenüber den bisherigen Runden ändert.

**Neu:**

```
INV-RPF     ksActive → firewall.checkReversePath != true
                       || firewall.extraReversePathFilterRules ≠ ""
            "Der Rückweg durch den Tunnel wird sonst im prerouting-Hook verworfen."

INV-EGRESS  ∀ unit mit egressClass = "vpn":
              gemergte serviceConfig enthält weder IPAddressDeny/Allow
              noch RestrictNetworkInterfaces noch PrivateNetwork
            "Diese greifen unterhalb von Routing und fwmark."

INV-LOOP    ∀ unit mit egressClass = "vpn":
              Loopback-Ziele nur aus localAllow; sonst drop
            "Deckt East-West und den glibc-DNS-Fallback in einer Regel ab."

INV-INET    Mark-Chain und Filter-Chain haben dieselbe family = "inet"
            "Sonst bleibt v6 unmarkiert."

INV-FACTORY ∀ Modul: kein Attributzugriff auf das Factory-Ergebnis
            "Selektion verliert users.users."
```

**Geschärft:**

```
INV-RP-SYSCTL   bleibt bestehen, ist aber für nftables-Backends allein wirkungslos
                → gilt nur noch zusammen mit INV-RPF
INV-BIND        Wortlaut: Port-Invariante, keine Adress-Garantie
INV-DNS         host.vpn.dns ≠ [] bleibt, ist nach INV-LOOP aber
                keine Sicherheits-, sondern eine Funktionsassertion
```

**Jede Assertion braucht einen Negativtest.** Eine Assertion, für die keine Konfiguration existiert, bei der sie feuert, ist eine Tautologie — und Tautologien melden grün, ohne zu prüfen.

---

## 4. Core vs. Host — finale Grenze

Vier greppbare Regeln. Wenn eine davon verletzt ist, ist es ein Boundary-Bug, unabhängig davon, wie sinnvoll die Einstellung wäre.

| # | Regel | Greppbar über |
|---|---|---|
| **G1** | Der Core schreibt nie auf ein Singleton. | `networking.(nftables\|firewall)\.`, `boot\.(kernel\.sysctl\|initrd\|kernelParams)`, `services\.caddy\.enable`, `hardware\.` — Treffer nur hinter `hostIntegration = "managed"` |
| **G2** | Der Core trifft keine Aussage über die Maschine. | Interface-Namen, CIDRs, `/dev/*`, absolute Pfade außerhalb `/var/lib`+`/run`, Domains. Jeder Host-Fakt ist `nullOr` mit Default `null`. |
| **G3** | Der Core empfiehlt als Daten, wendet nie an. | `recommended.{sysctl, nftables, mountOptions, firewall}` — `readOnly`, keine Setzung |
| **G4** | Der Core assertiert die Umgebung, die er annimmt. | Jede Annahme, die G1 verbietet zu setzen, ist eine Assertion am Verbraucher |

**Tri-State nur für drei Ressourcen:** `reverseProxy`, `nftables`, `storage`. Übertrieben für sysctl (immer Host), Firewall-Ausnahmen (immer Host), Credentials (immer Host), Kernel (immer Host) — dort gibt es kein sinnvolles `managed`, also auch keinen Schalter.

Ergänzung zu G3: `recommended.firewall` ist neu und nötig. `checkReversePath`/`extraReversePathFilterRules` sind weder Sysctl noch nft-Tabelle, hängen aber direkt am Kill-Switch — ohne eigenes Feld landet dieses Wissen in der Prosa und wird von jedem Fremdnutzer neu erlitten.

### Erwartungen an die beiden Eval-Checks

**`hostile-minimal`** — Core an, alle Dienste an, Host liefert nichts.
Erwartet: Build bricht mit `assertions`, und **der Fehlertext nennt den Optionspfad**, der fehlt. Nicht erwartet: `undefined variable`, `attribute … missing`, `option … does not exist`, Typfehler.
*Kriterium: Der Unterschied zwischen einem Konfigurationsfehler und einem Bug ist, ob die Fehlermeldung sagt, welche Option zu setzen ist.*

**`no-host-takeover`** — Core an, `hostIntegration` überall `external`.
Erwartet: `networking.nftables.enable`, `networking.firewall.checkReversePath`, `boot.kernel.sysctl`, `boot.initrd.luks.devices`, `services.caddy.enable` stehen exakt auf ihren nixpkgs-Defaults. Ein Diff gegen eine Konfiguration ohne mediNix darf außerhalb von `medinix.*` nur additive Schlüssel zeigen.

---

## 5. Nicht-Ziele

Bestätigt: netns/Container pro Dienst · Landlock · SELinux/AppArmor · systemweites userns-Abschalten · L7-WAF im Proxy · eigener Kernel · Overlays, die Apps neu bauen · flächendeckende Socket-Activation · Activation in jeder Form für den konfinierten Dienst · protokollspezifische nft-Regeln neben `skuid` · East-West-Vollmatrix · deklaratives DB-State-Provisioning bei jedem Switch · mehr Flake-Inputs als nötig.

Ergänzt:

| Nicht bauen | Grund |
|---|---|
| `checkReversePath = false` | Wirft Anti-Spoofing für alle Interfaces weg; `"loose"` oder die gezielte Ausnahme lösen dasselbe Problem enger |
| `MemoryMax` als Default | Auf einem Transcoder ein Ausfall statt eines Schutzes; `MemoryHigh` drosselt |
| `IOWeight` ohne Messung | Braucht cgroup-v2-IO-Controller und eine Baseline, die es nicht gibt |
| Bind-Adress-Garantie behaupten | Es gibt keinen Per-Unit-Mechanismus dafür (Entscheidung 9/10). Lieber als Registry-Feld sichtbar machen |
| Auf Caddy `fd/` bauen, bevor es verifiziert ist | In der `conventions`-Doku nicht gelistet |
| Zweite nft-Tabelle für East-West | Gehört in dieselbe `inet`-Tabelle wie der Kill-Switch, sonst driften Reihenfolge und Lebenszyklus |
| Tri-State für sysctl/Firewall/Credentials | Es gibt kein sinnvolles `managed` — ein Schalter ohne zweite Stellung ist Ballast |

---

## 6. Nächster Architektur-Schritt

**Genau zwei Dinge, in dieser Reihenfolge:**

**(1) Beobachtbarkeit in die Kill-Chain entscheiden — `counter` an jeder Regel.**
Das ist keine Debug-Maßnahme, sondern eine dauerhafte Architektur-Eigenschaft: ein selbstbeschreibender Core muss zur Laufzeit sagen können, welche seiner Regeln greift. Ohne diese Entscheidung bleibt Abschnitt 2 unausführbar und jede Ursachenhypothese unentscheidbar.

**(2) `recommended.firewall` als vierte Publish-Kategorie festlegen.**
`checkReversePath` und `extraReversePathFilterRules` sind Host-Singletons, die der Kill-Switch aber zwingend braucht. Ohne eigenes Feld existiert dieses Wissen nur in der Dokumentation — und die Erfahrung dieser Runde ist genau, dass ein Fremdnutzer es sonst als „VPN kaputt" neu erlebt. Zusammen mit `INV-RPF` schließt das die letzte offene Stelle im Publish-don't-apply-Modell.

Beides sind Entscheidungen über Struktur, nicht über Verhalten — sie ändern keinen laufenden Pfad und können vor der Messung fallen.
