# mediNix-Core — Doku-geprüfte Runde: Protokolle, Sockets, East-West, Reifegrad

Gegengeprüft: systemd (`src/bpf/socket-bind.bpf.c`, `src/shared/parse-helpers.c`, `src/core/socket.c` via Context7), nftables-Wiki (Chain-Typen, `meta skuid`), Caddy-Website-Doku (`bind`), sowie **nixpkgs am gepinnten Rev `ec2d622`** direkt aus der Quelle (`services/networking/nftables.nix`, `firewall-nftables.nix`, `firewall.nix`).

---

## 1. Doku-Check — was sich dadurch ändert

Vier Befunde korrigieren Aussagen aus den letzten Runden. Zwei davon sind material.

### 1.1 `SocketBindDeny/Allow` filtert **nicht** nach Adresse — nur nach Family/Protokoll/Port

Aus `src/bpf/socket-bind.bpf.c`:

```c
static __always_inline bool match(__u8 af, __u32 protocol, __u16 port,
                                  const struct socket_bind_rule *r) {
        return match_af(af, r) && match_protocol(protocol, r) && match_user_port(port, r);
}
SEC("cgroup/bind4") int sd_bind4(struct bpf_sock_addr *ctx) { … }
```

Der BPF-Kontext enthält zwar `user_ip4`, aber keine Match-Funktion liest ihn. Damit gilt:

| Aussage aus früherer Runde | Korrektur |
|---|---|
| „Bindet die App auf `0.0.0.0`, bekommt sie `EPERM`" | **Falsch.** `SocketBindAllow = "ipv4:tcp:5410"` erlaubt `0.0.0.0:5410` genauso wie `127.0.0.1:5410`. |
| „Bind-Erzwingung statt Bind-Bitte" | **Halb richtig.** Erzwungen wird **Port-Disziplin**: die App kann keinen fremden Port und keinen Zusatzport öffnen. **Adress-Disziplin** kommt weiterhin nur aus Firewall + Test. |

Weitere bestätigte Semantik: Allow-Regeln werden **vor** Deny geprüft, ohne Treffer gilt Allow (`bind_socket()`); nur `cgroup/bind4`/`bind6` sind gehookt, also **kein Effekt auf `AF_UNIX`** und **kein Effekt auf `connect()`**. Syntax laut `parse-helpers.c`: `[ipv4|ipv6]:[tcp|udp]:<port|N-M|any>`, jedes Token optional. [Annahme: stabil seit v249.]

**Konsequenz für den Core:** `SocketBindDeny/Allow` bleibt drin — aber als *Port*-Invariante deklariert, nicht als Bind-Adress-Garantie. Die Adresse prüft der `ss`-Test (4.4 der Checkliste) und sonst nichts.

### 1.2 `checkReversePath` ist ein zweiter, unabhängiger Reverse-Path-Filter — und vermutlich euer VPN-Bug

`nixos/modules/services/networking/firewall-nftables.nix` @ `ec2d622`:

```nft
chain rpfilter {
  type filter hook prerouting priority mangle + 10; policy drop;
  meta nfproto ipv4 udp sport . udp dport { 67 . 68, 68 . 67 } accept
  fib saddr . mark ${optionalString (checkReversePath != "loose") ". iif"} oif exists accept
  jump rpfilter-allow
}
```

`networking.firewall.checkReversePath` hat **Default `true` = strict** (`firewall.nix:208`).

Wichtig: das ist **nicht** `net.ipv4.conf.*.rp_filter`. Der nftables-Backend der NixOS-Firewall setzt den Sysctl gar nicht, sondern implementiert die Prüfung als eigene Chain. Wer nur den Sysctl auf `2` stellt, hat nichts geändert.

Warum das genau euer Symptom erzeugt:

| Paket | `fib`-Lookup | Ergebnis |
|---|---|---|
| WireGuard-Handshake (UDP zum Peer, über `eth0` rein) | Rückroute zum Peer geht über `eth0` = `iif` | accept — **Tunnel kommt hoch** |
| NNTP-Rückverkehr (kommt über `wg0` rein) | Lookup nutzt `saddr . mark . iif`; eingehende Pakete tragen **keinen** fwmark (der wird erst im Output-Hook gesetzt) → Main-Tabelle → Rückroute über `eth0` ≠ `iif` = `wg0` | kein accept → **policy drop** |

Das passt exakt zu „fail-closed bewiesen, VPN-oben kaputt": der Tunnel steht, die Nutzlast kommt nicht zurück.

**Konsequenz:** `networking.firewall.checkReversePath = "loose"` (entfernt `. iif` aus dem Lookup) ist ein **Host-Singleton** → gehört als `recommended` + Umgebungs-Assertion in den Core, nicht als Setzung. Die bisherige Assertion auf `net.ipv4.conf.all.rp_filter` bleibt gültig (für iptables-Backends und Fremdhosts), reicht aber allein nicht.

### 1.3 `route`-Chains funktionieren in `inet`

nftables-Wiki, Chain-Typen: *route … supported by the ip, ip6 and inet table families* (Output-Hook).

Damit entfällt die bisher angenommene v4/v6-Trennung: **Mark-Chain und Filter-Chain können beide `family = "inet"`** sein. Ein `meta mark set` greift dann für v4 und v6, und die `ipv6`-Option ist keine tote Konfiguration mehr. `meta skuid` unterstützt laut Wiki Sets und Ranges (`meta skuid { 5410 }`, `meta skuid 5410`) — für East-West direkt nutzbar.

### 1.4 `nftables.service` — Reload atomar, Stop nicht

`services/networking/nftables.nix` @ `ec2d622`:

| Eigenschaft | Beleg | Bedeutung für die Invariante |
|---|---|---|
| `reloadIfChanged = true` | Z. 297 | `nixos-rebuild switch` **reloadet** statt neu zu starten, wenn sich der Ruleset geändert hat. |
| `ExecReload` = `rulesScript` | Z. 377 | Eine einzige `nft -f`-Datei, die Deletions **und** neue Tabellen enthält ⇒ **eine Transaktion, kein Leck-Fenster** beim Switch. |
| `ExecStop` = `makeDeletions` | Z. 382 | Beim **Stop** werden die Tabellen gelöscht (bzw. `flush ruleset`, wenn `flushRuleset`). Der Kill-Switch ist danach weg. |
| `checkRuleset` Default an, `nft --check` im `checkPhase` | Z. 355 | Ein syntaktisch kaputter Kill-Switch bricht den **Build**, nicht den Boot. Das ist ein kostenloser Stufe-0-Check, den ihr schon habt. |
| `DefaultDependencies = false`, `before = network-pre.target` | Z. 288, 390 | Regeln stehen vor der Netzwerkkonfiguration ⇒ fail-closed gilt ab Boot. |

**Konsequenz:** Die Invariante über `switch` ist besser als gedacht — die kritische Lücke ist nicht der Switch, sondern ein `systemctl stop nftables`. Ob die `Requires`-Kette `sabnzbd → medinix-vpn-route → nftables` den Stop propagiert, ist genau das, was der Test aus 4.4 prüfen muss.

### 1.5 Die NixOS-Firewall hat keine Output-Chain

`firewall-nftables.nix` erzeugt `rpfilter` (prerouting), `input`, `forward` — **keinen Output-Hook**. Der Kill-Switch besitzt den Output-Hook also allein; es gibt keinen Konflikt und keine Reihenfolgen-Frage mit `networking.firewall`.

### 1.6 Caddy `bind fd/` — nicht belegt

Die Caddy-Doku belegt `bind unix//run/caddy` und `bind <host>` (ohne Port). Ein `fd/N`- oder `fdgram/`-Netzwerktyp taucht in den abgerufenen Doku-Abschnitten **nicht** auf. [zu verifizieren am gepinnten Rev: `nix run nixpkgs#caddy -- list-modules | grep -i fd` bzw. `caddy adapt` mit `bind fd/3`.] Bis dahin gilt: Socket-Activation für Caddy ist **nicht** als gangbar anzunehmen.

---

## 2. Thema 1 — Protokolle & Exposure

**Kurzbefund:** Die Protokoll-Liste aus der letzten Runde ist inhaltlich richtig und vollständig genug. Der Fehler liegt nicht bei den Protokollen, sondern beim Kontrollpunkt: sie ordnet jedem Protokoll eine Härtung zu, ohne zu sagen, **welcher Mechanismus** sie durchsetzt und **wo** er lebt.

**Lücke:** „Bind nur Registry-Port (`SocketBindDeny`), Backend ideal nur 127.0.0.1" verschmilzt zwei Dinge, die nach 1.1 auseinanderfallen.

**Empfehlung — Exposure-Matrix mit Durchsetzungspunkt:**

| Protokoll | Wo | Durchsetzung | In Core? |
|---|---|---|---|
| TCP, App-Ports | Arrs, SABnzbd-UI, Jellyfin | Port: `SocketBindDeny/Allow`. Adresse: **`networking.firewall` default-deny input** (keine App-Ports in `allowedTCPPorts`) + `ss`-Test | Core: Deny/Allow + Assertion; Host: Firewall-Backend |
| TLS/HTTPS | nur Caddy | ACME-Gruppe == effektive Proxy-Unit (Assertion) | Core |
| HTTP intern | Loopback | kein Firewall-Loch; **nicht** die Bind-Adresse | Core (Assertion), Host (Firewall) |
| NNTP | SABnzbd → Usenet | `meta skuid 5410` + Policy-Routing. **Kein** protokollspezifischer Sonderweg | Core-Mechanismus, Host-Interface |
| WireGuard (UDP) | Tunnel | MTU/MSS-Clamping, `checkReversePath = "loose"`, `src` in der Policy-Route | Host; Core assertiert |
| DNS (UDP/TCP) | SABnzbd | eigene `resolv.conf`, **nicht leer** (sonst glibc-Fallback `127.0.0.1`) | Core-Assertion, Host liefert Server |
| mDNS | `.local` | LAN-only, nie WAN | Core, hinter Enable |
| ICMP | Diagnose | nicht blind blocken | Host |
| QUIC/HTTP3 | — | nicht aktivieren, solange nicht gebraucht | — |

**Klarstellung zu einer Formulierung der letzten Runde:** „NNTP hinter Kill-Switch" ist richtig, aber `meta skuid` unterscheidet keine Protokolle. Der Kill-Switch deckt **jeden** Egress von UID 5410 ab — NNTP, DNS, HTTP-Updatecheck. Das ist die Stärke des Modells und der Grund, warum kein Protokoll einzeln behandelt werden muss.

---

## 3. Thema 2 — Socket-Activation vs. `SocketBindDeny`

**Kurzbefund:** Die Schlussfolgerung („flächendeckend nein, `SocketBindDeny` ja, für SABnzbd hart nein") bleibt nach dem Doku-Check unverändert richtig. Zwei Begründungen ändern sich.

| Punkt | Status nach Doku-Check |
|---|---|
| Activation für Arrs/SABnzbd/Jellyfin | **Nein** — unverändert. Kein `sd_listen_fds`-Pfad. |
| Activation für den konfinierten Dienst | **Nein, hart** — unverändert. Bei `Accept=yes` erzeugt PID 1 den Verbindungs-Socket; `skuid` trüge dann `0`. `src/core/socket.c` bestätigt die Trennung `Accept=no` (Unit-Start, FD-Übergabe) vs. `Accept=yes` (pro Verbindung). Ein fail-closed-Pfad darf nicht von einem Unit-Flag abhängen. |
| `SocketBindDeny/Allow` | **Ja — aber als Port-Invariante**, nicht als Bind-Adress-Garantie (1.1). Formulierung in Options-Doku und Checkliste anpassen. |
| Unix-Socket Caddy ↔ Backend | **Nur wo belegt.** Caddy kann `bind unix//…` für den *Listener*; ob eure Backends Unix sprechen, ist app-abhängig. Bei fehlendem App-Support entsteht die Timeout-ohne-Log-Falle. |
| Caddy `:80/:443` per Socket-Unit | **Zurückgestellt** — `bind fd/` nicht belegt (1.6). Bleibt: `AmbientCapabilities` **und** `CapabilityBoundingSet` = `CAP_NET_BIND_SERVICE` mit `PrivateUsers = false`. Alternative `net.ipv4.ip_unprivileged_port_start = 0` als `recommended.sysctl`. |

**Einordnung in den Core:** Registry-Feld `port`; Factory setzt `SocketBindDeny = [ "any" ]` und `SocketBindAllow = [ "ipv4:tcp:<port>" "ipv6:tcp:<port>" ]` als Default für jeden Dienst mit Port. Ausnahmeliste: Caddy (mehrere Ports, ebenfalls auflistbar). Keine `.socket`-Units im Core.

---

## 4. Thema 3 — East-West / Loopback

**Kurzbefund:** Die Analyse der letzten Runde ist korrekt — das Loch ist real, und `skuid` + `dport` ist das richtige Mittel. Zwei Präzisierungen aus dem Doku-Check.

**Präzisierung 1:** `SocketBindDeny` ändert East-West **nachweislich nicht**. Es hookt `bind()`, nicht `connect()` (1.1). Das war in der letzten Runde richtig vermutet und ist jetzt belegt.

**Präzisierung 2:** Die Regel gehört in dieselbe `inet`-Tabelle wie der Kill-Switch (1.3), nicht in eine zweite. Konkret, als Ergänzung der bestehenden `kill_sabnzbd`-Chain, **vor** dem generischen Loopback-Accept:

```nft
# statt: ip daddr 127.0.0.0/8 accept
meta skuid 5410 ip daddr 127.0.0.1 tcp dport { 5410 } accept   # eigenes Web-UI
meta skuid 5410 ip daddr 127.0.0.0/8 drop                      # alles andere lokal: nein
ip daddr 127.0.0.0/8 accept                                     # übrige UIDs: unverändert flach
```

Die erlaubten Ports kommen aus einem Registry-Feld `localAllow = [ ]` (Default leer). SABnzbd braucht typischerweise **keinen** ausgehenden Loopback-Kontakt — die Arrs rufen *ihn* auf, nicht umgekehrt. [Annahme: kein Post-Processing-Skript ruft eine lokale API.] Damit ist der KISS-Start nicht „eine kurze Allowlist", sondern **eine leere Allowlist plus `drop`** — kleiner und strenger als vorgeschlagen.

**Wann:** Nach VPN-oben und Test-Gate. Aber: sobald die Kill-Chain ohnehin angefasst wird (Schritt 1), kostet die Zeile fast nichts und ist im selben Test verifizierbar. Ich würde sie **nicht** auf „später" schieben, sondern an Schritt 1 anhängen — mit einem Test, der `curl 127.0.0.1:<anderer-port>` als UID 5410 fehlschlagen lässt.

---

## 5. Thema 4 — „Rundum abgesichert?"

Die Selbsteinschätzung der letzten Runde (Konzept ~85–90 %, Umsetzung darunter, Beweis fast keiner) ist ehrlich und trifft zu. Drei Ergänzungen:

| Ergänzung | Warum |
|---|---|
| Der Kill-Switch ist möglicherweise **nicht** kaputt — die Firewall droppt den Rückweg | Nach 1.2 kann `checkReversePath = true` allein das Symptom erklären. Vor jedem Umbau am Kill-Switch: erst messen. |
| Die Switch-Invariante ist teilweise schon gegeben | `reloadIfChanged` + atomarer `nft -f` (1.4). Zu beweisen bleibt die Stop-Propagation, nicht der Switch. |
| Ein Stufe-0-Check läuft bereits | `checkRuleset` prüft den Ruleset zur Bauzeit mit LKL. Das ist der einzige Punkt der Checkliste, der ohne Zutun grün ist. |

**Was fehlt, bevor man „rundum" sagen darf** — unverändert: VPN-oben grün, UID/Bind je Dienst getestet, Umgebungs-Assertions im Code, `no-host-takeover` grün, .NET-Arrs laufen unter der Härtung. Kein Punkt davon ist Architektur, alle vier sind Code.

---

## 6. Synthese

| Thema | In Core? | Mechanismus | Priorität | KISS-Falle |
|---|---|---|---|---|
| `checkReversePath` | **Nein** — Host-Singleton | `recommended.sysctlAndFirewall` + Umgebungs-Assertion `ksActive → checkReversePath != true` | **jetzt** | Am Sysctl `rp_filter` schrauben, während die nft-`rpfilter`-Chain droppt |
| `rp_filter`-Sysctl-Assertion | Ja (Assertion) | bestehende Assertion behalten | jetzt | Für nftables-Backends allein wirkungslos |
| `src` in der Policy-Route | Ja | `ip route replace default dev <if> src <addr> table N` | **jetzt** | Reroute wählt die Quelle nur bei ungebundenem Socket neu |
| `IPAddressDeny`/`RestrictNetworkInterfaces`/`PrivateNetwork` raus | Ja | Assertion im `unpack`-Profil | **jetzt** | cgroup-BPF ist beim Routing-Debugging unsichtbar |
| Mark- und Filter-Chain beide `inet` | Ja | `family = "inet"` für beide | **jetzt** (kostenlos beim Anfassen) | `family = "ip"` lässt v6 unmarkiert und macht die `ipv6`-Option tot |
| `SocketBindDeny/Allow` | Ja | Factory-Default je Dienst mit Port | nach VPN+Test | Als Bind-**Adress**-Garantie verkaufen (1.1) |
| Bind-Adresse verifizieren | Ja (Test) | `ss -Hltn` gegen Registry | nach VPN+Test | Deklaration für Wirkung halten |
| East-West für UID 5410 | Ja | `meta skuid` + `dport` in der Kill-Chain, Registry-Feld `localAllow = [ ]` | **an Schritt 1 anhängen** | Vollmatrix für alle UIDs |
| East-West für übrige UIDs | Nein | dokumentierte Grenze | nie (bis ein Bedarf belegt ist) | Pflegeaufwand ohne Bedrohungsmodell |
| Unix-Sockets Caddy↔Backend | Ja, wo belegt | `bind unix//…` + Socket-Rechte | später | App spricht kein Unix ⇒ Timeout ohne Log |
| Socket-Activation | Nein | — | nie | „moderner" ist kein Grund |
| Caddy `:80/:443` | Ja | Ambient **und** Bounding `CAP_NET_BIND_SERVICE`, `PrivateUsers = false` | nach VPN+Test | Bounding allein verleiht nichts |
| `ip_unprivileged_port_start` | Nein — Host | `recommended.sysctl` | später | Im Core setzen |
| DNS für den konfinierten Dienst | Ja (Assertion) | `host.vpn.dns != []` | **jetzt** | Leere `resolv.conf` ⇒ `127.0.0.1` ⇒ Leck |
| ACME-Gruppe | Ja (Assertion) | == Gruppe der effektiv laufenden Proxy-Unit | nach VPN+Test | Literal `"caddy"` bei `external` |
| Protokoll-Härtung je Protokoll | Nein | `skuid` deckt alle Protokolle einer UID ab | nie | NNTP/DNS einzeln filtern wollen |
| Auth an den UIs | Ja | `auth.mode` → App-Auth-Modus, eine Quelle | nach VPN+Test | Zwei Schalter für dieselbe Entscheidung |
| Backup, SSH, NTP | Nein — Host | Bridge | Host-Thema | In den Core ziehen, weil „gehört ja dazu" |

---

## 7. Nicht-Ziele aus diesen Themen

| Nicht bauen | Grund |
|---|---|
| `.socket`-Units für Arrs/SABnzbd/Jellyfin | Kein `sd_listen_fds`; erzeugt `EADDRINUSE` oder stille Timeouts |
| Socket-Activation in **jeder** Form für UID 5410 | `skuid`-Semantik dürfte nicht von `Accept=` abhängen |
| Protokollspezifische nft-Regeln (NNTP, DNS getrennt) | `meta skuid` deckt die UID vollständig ab; Zusatzregeln sind Pflegeaufwand ohne Gewinn |
| East-West-Vollmatrix über alle UIDs | Ohne belegtes Bedrohungsmodell reine Regelpflege |
| Umstellung des Stacks auf Unix-Sockets | Nur dort, wo die App es belegt kann |
| QUIC/HTTP3, mTLS zwischen Diensten, eigene PKI | Kein Bedarf, hoher Dauerbetriebsaufwand |
| `flushRuleset = true` setzen, um „sauber" zu sein | Löscht beim Stop den gesamten Ruleset inklusive Host-Regeln |
| `checkReversePath = false` statt `"loose"` | `loose` entfernt nur `. iif` und behält den Anti-Spoofing-Nutzen |
| Kill-Switch umbauen, bevor 1.2 gemessen ist | Das Symptom kann vollständig außerhalb des Kill-Switches liegen |

---

## 8. Nächster Schritt

**Vor jedem Codeänderung messen, ob die Firewall den Rückweg droppt:**

```bash
# 1. Drops sichtbar machen (Host, temporär)
networking.firewall.logReversePathDrops = true;   # firewall.nix:231

# 2. nach dem Switch, bei aktivem Tunnel:
journalctl -kf | grep "rpfilter drop"
# parallel als UID 5410 eine Verbindung nach außen versuchen

# 3. wenn Treffer erscheinen:
networking.firewall.checkReversePath = "loose";
```

Zeigt Schritt 2 `rpfilter drop`-Zeilen mit Quelladressen aus dem Tunnel, ist der Kill-Switch nicht defekt — dann fehlt genau eine Host-Zeile, und `IPAddressDeny`/`src`/MSS sind gar nicht die Ursache.
