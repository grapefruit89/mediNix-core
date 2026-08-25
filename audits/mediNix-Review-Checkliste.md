# mediNix — Review-Checkliste (geschärft)

## Leitregel

Eine Checkbox, die eine Assertion sein könnte, ist technische Schuld. Sie wird einmal abgehakt und danach nie wieder geprüft — während die Assertion bei jedem Build läuft.

Deshalb bekommt **jeder Punkt genau eine Kategorie**:

| | Bedeutung | Lebensdauer |
|---|---|---|
| **[A]** | Assertion oder Eval-Check im Repo | dauerhaft, läuft bei jedem Build |
| **[T]** | `nixosTest` oder Laufzeit-Kommando | dauerhaft, läuft in CI |
| **[M]** | echtes Urteil, nicht automatisierbar | einmalig pro Datei |

**Ziel des Reviews ist nicht, alle Haken zu setzen, sondern die [M]-Liste kurz zu machen.** Jeder Punkt, den du nach [A] oder [T] verschiebst, verschwindet danach aus der Checkliste.

Zweite Regel: **kein „wo sinnvoll", kein „soweit der Dienst es verträgt".** Jede Vorgabe ist Default plus namentliche Ausnahmeliste mit Begründung. Weichmacher machen einen Punkt unprüfbar.

---

## Stufe 0 — Eval-Breaker (fehlt in der bisherigen Liste, kostet am meisten)

Diese Klasse fängt keine inhaltliche Checkliste ab, weil sie nichts mit Architektur zu tun hat. Sie bricht den Build und ist mit drei Kommandos vollständig erschlagen. **Vor jedem inhaltlichen Review laufen lassen.**

```bash
# 0.1 Parse — fängt Klammerfehler UND doppelte Attributpfade
#      (Nix wirft dupAttr bereits beim Parsen)
for f in $(git ls-files '*.nix'); do
  nix-instantiate --parse "$f" >/dev/null || echo "PARSE: $f"
done

# 0.2 Eval — fängt undefinierte Bezeichner, fehlende Optionspfade,
#      Typfehler, Skalar-Kollisionen mit Upstream-Modulen
nix flake check --no-build

# 0.3 Tote Bindings — korreliert stark mit "let-Eintrag entfernt, Referenz vergessen"
nix run nixpkgs#deadnix -- --fail .
nix run nixpkgs#statix -- check .
```

| # | Prüfung | Kat. | Kriterium |
|---|---|---|---|
| 0.1 | Kein Attributpfad zweimal in derselben Attrmenge | [A] | `--parse` grün. Typischer Fall: `systemd.services.<n> = {…}` oben und `systemd.services.<n> = lib.mkIf …` unten. Nix merged nur, wenn **beide** Seiten Attrset-**Literale** sind — `mkIf` ist eine Funktionsanwendung, also `already defined`. Fix: ein `lib.mkMerge`. |
| 0.2 | Kein Schlüssel zweimal innerhalb eines Literals | [A] | `--parse` grün. Beispiel: `after` im Unit-Literal *und* später als `systemd.services.<n>.after`. |
| 0.3 | Alle `let`-Bezeichner definiert | [A] | `nix flake check`. `deadnix` fängt die Gegenrichtung (Binding da, Referenz weg). |
| 0.4 | `cfg`-Scope korrekt | [M] | Pro Datei: zeigt `cfg` auf den Dienst (`medinix.sonarr`) und `svc` auf die Wurzel (`medinix`)? Zugriffe wie `cfg.secrets.*` oder `cfg.storage.*` sind fast immer Scope-Verwechslungen. Grep: `grep -n 'cfg\.\(secrets\|storage\|ingress\|host\)\.' 5*/*.nix` |
| 0.5 | Modul-Syntax konsistent | [A] | Entweder Top-Level-Attribute **oder** explizites `config = …`. Beides gemischt ⇒ `Module has an unsupported attribute`. |
| 0.6 | `lib.mkIf` nie als Listenelement | [M] | Grep: `grep -n '(lib\.mkIf' 5*/*.nix lib/*.nix` — in Listen `lib.optional`/`lib.optionals` verwenden. |
| 0.7 | Alle `pkgs.<name>` existieren am gepinnten Rev | [A] | `nix eval nixpkgs#<name>.name` bzw. fällt bei 0.2 auf. |
| 0.8 | Keine Nix-Escapes in systemd-Unit-Namen | [M] | In `"…"` gilt: `\x` → `x`. `"run-foo\x2dbar.mount"` wird zu `run-foox2dbar.mount`. Doppelt escapen oder `utils.escapeSystemdPath` nutzen. Grep: `grep -n '\\x' 5*/*.nix` |
| 0.9 | Kein Platzhalter-Hash | [A] | `grep -rn 'fakeSha256\|fakeHash\|sha256-AAAA' .` muss leer sein. |

---

## Stufe 1 — Pro Moduldatei

### 1.1 Struktur

| Prüfung | Kat. | Kriterium |
|---|---|---|
| Genau ein Enable-Gate | [A] | Eval-Check: Konfiguration mit `medinix.enable = false` muss **identisch** zur Konfiguration ohne mediNix sein. Das prüft „Datei löschen ⇒ Dienst weg" maschinell und macht den Einzelhaken überflüssig. |
| Dekade-`default.nix` nur Imports | [M] | Kein `config`-Block, keine Options außer Struktur. |
| Ein Dienst pro Datei | [M] | — |

### 1.2 Identität

| Prüfung | Kat. | Kriterium |
|---|---|---|
| `port == uid == nummer * 10` | [A] | Über **alle** Registry-Einträge, nicht pro Datei. |
| Keine Doppelnummer, kein Dienst auf `N00` | [A] | Registry-weite Assertion. |
| Modul liest Werte **nur** aus der Registry | [M] | Grep pro Datei: `grep -nE '(port|uid|gid|stateDir) *= *[0-9"]' <datei>` — jeder Treffer ist ein Hardcode. |
| `StateDirectoryMode = "0700"` | [A] | Assertion über alle erzeugten Units. Ausnahmeliste: keine. State ist nie gruppenlesbar — sonst liest ein kompromittierter Dienst die SQLite-DB des nächsten inklusive API-Keys. |

### 1.3 Shared Media — die Trennlinie präzise

Der häufigste Denkfehler ist, GID 5000 auf State *und* Daten anzuwenden. Präzise:

| Objekt | Eigentümer | Mode | Mechanismus |
|---|---|---|---|
| State (`/var/lib/<n>-<port>`) | Dienst-User | `0700` | `StateDirectoryMode` |
| Mediendaten (`/data/media/…`) | `root:media` | `2775` | tmpfiles `d '<pfad>' 2775 root media -` |
| Neue Dateien im Medienbaum | Dienst-User:media | `0664`/`0775` | `UMask = "0002"` + setgid vom Elternverzeichnis |

| Prüfung | Kat. | Kriterium |
|---|---|---|
| Gruppenzugehörigkeit korrekt gesetzt | [M] | Für Dienste: `serviceConfig.SupplementaryGroups = [ "media" ]`. **Nicht** `users.users.<n>.extraGroups` — das ist die User-Ebene und greift bei einer Unit mit explizitem `Group=` nicht zuverlässig. Beides zu setzen ist kein Fehler, aber `SupplementaryGroups` ist das Wirksame. |
| `UMask = "0002"` nur bei Schreibern | [M] | Leser (Jellyfin, Navidrome) brauchen es nicht. |
| Medienbaum ist read-only wo möglich | [M] | `BindReadOnlyPaths` statt `ReadWritePaths`. Ausnahmeliste benennen (z. B. Audiobookshelf schreibt Cover). |

### 1.4 Härtung

| Prüfung | Kat. | Kriterium |
|---|---|---|
| Profil aus der Registry, nicht pro Datei gewählt | [M] | Grep: `grep -n 'profile *= *"' 5*/*.nix` — der Wert muss aus `reg.hardeningProfile` kommen. |
| `.jit`-Dienste ohne MDWE und ohne `~@resources` | [A] | Assertion über die **gemergte** `serviceConfig`, nicht über das Profil. Begründung: `@system-service` **enthält** `@resources`; ein Deny entfernt `sched_setaffinity`/`setpriority`, die .NET beim Start braucht. |
| `SystemCallErrorNumber = "EPERM"` | [A] | Default für alle. SIGSYS killt beim Syscall-Probing still. |
| `RestrictNamespaces = true` | [A] | Default für alle, **Ausnahmeliste leer**. Kein Dienst in diesem Stack legt Namespaces an. Das ist zugleich die per-Unit-Antwort auf „userns systemweit abschalten" — ohne die Nix-Build-Sandbox zu brechen. |
| `PrivateUsers = false` | [A] | Default für alle. Sonst wirken Capabilities nur im eigenen Userns (privilegierte Ports brechen) und `SupplementaryGroups` für `/dev/dri` erscheinen als `nogroup`. |
| `ProcSubset` **nicht** in der Baseline | [M] | `ProcSubset = "pid"` blendet `/proc/cpuinfo`, `/proc/meminfo`, `/proc/stat` aus. .NET-GC, Node und die ffmpeg-Hardware-Erkennung lesen davon. Nur als Opt-in pro Dienst, nach Test. |
| `RestrictAddressFamilies` enthält `AF_NETLINK` | [A] | .NET ruft beim Start `NetworkInterface.GetAllNetworkInterfaces()` über Netlink. |
| Caddy: Ambient **und** Bounding `CAP_NET_BIND_SERVICE` | [A] | Bounding allein *begrenzt*, es *verleiht* nicht. Vorbedingung: `PrivateUsers = false`. `setcap` scheidet aus — Nix-Store-Pfade tragen keine File-Caps. |
| Kein `mkForce` im Core | [A] | `grep -rn 'mkForce' 5*/ lib/` muss leer sein. |
| Profil wird nicht in Upstream-Units gemergt | [M] | Entscheidungsregel: **entweder** eigene Unit (volles Profil) **oder** `services.<x>.enable` (nur additive Listen + `mkDefault`, niemals `User`/`Group`/`StateDirectory`/`ExecStart`/`Restart` per `serviceConfig`). Dazwischen liegt nur `mergeEqualOption`. |

### 1.5 Netzwerk / Bind

| Prüfung | Kat. | Kriterium |
|---|---|---|
| `SocketBindDeny = ["any"]` + `SocketBindAllow` | [A] | Default für **jeden** Dienst mit Port. Ausnahmeliste: nur der Reverse-Proxy (mehrere Ports — auch dort auflistbar). Kein „wo sinnvoll". |
| Bindung wird erzwungen, nicht erbeten | [T] | Siehe 4.3. Konfiguration sagt `127.0.0.1:5410`; ob die App gehorcht, sagt nur `ss`. |
| Konfinierter Dienst ohne `IPAddressDeny` / `RestrictNetworkInterfaces` / `PrivateNetwork` | [A] | Assertion im `unpack`/`vpn`-Profil. Alle drei greifen unterhalb von Routing und fwmark und blockieren genau den Pfad, den der Kill-Switch erlauben soll. |
| Keine LAN-CIDR im Modul | [M] | Grep: `grep -nE '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+' 5*/*.nix` — Treffer nur in `medinix.host.*`-Defaults zulässig, und die sind `null`. |

### 1.6 Boundary

| Prüfung | Kat. | Kriterium |
|---|---|---|
| Kein Schreiben auf Host-Singletons | [A] | `no-host-takeover`-Eval-Check (siehe 4.1). Grep als Vorfilter: `grep -rnE '(networking\.(nftables\|firewall)\.enable\|boot\.(kernel\.sysctl\|initrd\|kernelParams)\|services\.caddy\.enable\|hardware\.graphics\.enable) *=' 5*/ lib/` |
| Host-Fakten nur über `medinix.host.*` | [M] | Und dort `nullOr` mit Default `null`. Ein plausibler Default (`"wg0"`, `/data/library`) ist eine Behauptung über die Maschine — er verwandelt einen Konfigurationsfehler in stillen Fehlbetrieb. |
| Assertion sitzt am Verbraucher | [M] | `sabnzbd.enable → host.vpn.interface != null`, nicht umgekehrt. Sonst muss jemand, der nur Jellyfin will, ein VPN deklarieren. |

---

## Stufe 2 — `lib/`

| # | Prüfung | Kat. | Kriterium |
|---|---|---|---|
| 2.1 | Registry ist einzige Ableitungsstelle | [M] | `port = uid = nummer * 10` steht genau einmal. Grep nach `* 10` im Rest des Repos muss leer sein. |
| 2.2 | Registry-Eintrag ⇔ Modul | [A] | Bidirektional: jeder Eintrag hat eine Datei, jede Datei einen Eintrag. Fängt „Option existiert, Modul fehlt" und „Modul da, Registry kennt es nicht". |
| 2.3 | Factory gibt **vollständig** zurück | [M] | Wenn die Factory `{ systemd.services.<n>; users.users.<n>; }` liefert und der Aufrufer nur `.systemd.services.<n>` selektiert, verschwindet der User. Die Unit läuft dann mit `User=` auf einen nicht existierenden Account. Grep: `grep -n ')\.systemd\.services\.' 5*/*.nix` |
| 2.4 | Skalare als Listen, wo systemd merged | [M] | `SystemCallFilter`, `CapabilityBoundingSet`, `AmbientCapabilities`, `RestrictAddressFamilies`, `ReadWritePaths`. `unitOption` konkateniert Listen und verlangt bei Skalaren Gleichheit — Listen sind übersteuerbar ohne Konflikt. |
| 2.5 | Übersteuerbar ohne Fork | [M] | `medinix.hardening.profiles.<name>` als **Option** (nicht als privates `let`-Binding) plus `extraServiceConfig.<unit>`. |
| 2.6 | `recommended.*` ist `readOnly` und wird nicht angewandt | [A] | Teil von `no-host-takeover`. |
| 2.7 | Ein Credential-Mechanismus | [A] | Assertion: kein `EnvironmentFile` mit Klartext-Token neben `LoadCredentialEncrypted`. Ein Klartext-Fallback „für den Notfall" wird in der Praxis zum Hauptpfad. |
| 2.8 | Credential-Optionen sind `nullOr` mit Default `null` | [A] | `types.str` mit Default-Pfad ⇒ `mkIf (… != null)` ist eine Tautologie ⇒ `LoadCredentialEncrypted` wird unbedingt gesetzt ⇒ Dienst startet nicht. |
| 2.9 | Runtime-Pfad mit `.service`-Suffix | [M] | `/run/credentials/<unit>.service/<id>`. Grep: `grep -rn '/run/credentials/' .` — jeder Treffer ohne `.service` ist falsch. |

---

## Stufe 3 — Security-Modul (520)

| Prüfung | Kat. | Kriterium |
|---|---|---|
| Kill-Switch opt-in, Default aus | [A] | — |
| Instanz an `usenet-confinement` gekoppelt | [M] | Nicht „unconditionally", sonst feuert die Interface-Assertion, sobald jemand nur SABnzbd anschaltet. |
| Mark-Tabelle **und** Filter-Tabelle `family = "inet"` | [M] | Steht die Mark-Chain in `family = "ip"`, wird v6 nie markiert — die `ipv6`-Option ist dann tote Konfiguration, auch wenn v6 durch die Filter-Chain fail-closed gedroppt wird. |
| `fwmark` an Registry-UID gebunden | [T] | Nicht nur deklariert: `nft list chain … | grep skuid` gegen `id -u sabnzbd`. |
| resolv.conf **nicht leer** | [A] | Assertion `host.vpn.dns != []`. Leere resolv.conf ⇒ glibc fällt auf `127.0.0.1` zurück ⇒ die Loopback-Accept-Regel lässt die Query durch ⇒ DNS am Tunnel vorbei. Das ist ein Leak, kein Schutz. |
| Ordering | [M] | `RemainAfterExit = true`, **kein** `ExecStop`, `before = [ "<dienst>.service" ]`. |
| Interface nur über `host.vpn.interface` | [A] | `nullOr`, Default `null`, Assertion am Verbraucher. |
| Loopback-Accept ist eingeschränkt | [M] | Blanket-`ip daddr 127.0.0.0/8 accept` erlaubt dem konfinierten UID jeden anderen Loopback-Dienst. Bietet einer davon ein Fetch-Primitiv, existiert ein Relay am Tunnel vorbei. Entweder auf `skuid` + `dport` einschränken oder **explizit als bekannte Grenze dokumentieren**. |
| Umgebungs-Assertions vollständig | [A] | Siehe 4.2. |
| Namen, auf die andere Module prüfen, stimmen | [M] | Wenn ein Monitoring-Skript `nft list table inet medinix_vpn` prüft, die Tabelle aber `medinix_vpn_filter` heißt, alarmiert es bei jedem Lauf — und echte Leaks gehen im Rauschen unter. |

---

## Stufe 4 — Gesamt-Stack

### 4.1 Zwei Eval-Checks, die die Grenze zum Test machen

```nix
# hostile-minimal: Core an, Host liefert nichts
#   Erwartung: sauberer Assertion-Text — kein "undefined variable",
#              kein "attribute missing", kein "does not exist"
checks.hostile-minimal = …;

# no-host-takeover: Core an, hostIntegration = external
#   Erwartung:
#     config.networking.nftables.enable == false
#     config.boot.kernel.sysctl        == {}
#     config.boot.initrd.luks.devices  == {}
#     config.services.caddy.enable     == false
checks.no-host-takeover = …;
```

Ab hier ist „additiv" eine getestete Eigenschaft und keine Behauptung mehr.

### 4.2 Assertions — Build muss brechen bei

**Interne Invarianten:**
- UID ≠ Port ≠ Nummer × 10; Doppelnummer; Dienst auf Block-ID
- `.jit`-Unit mit MDWE oder `~@resources`
- konfinierte Unit mit `IPAddressDeny`/`RestrictNetworkInterfaces`/`PrivateNetwork`
- `StateDirectoryMode ≠ 0700`
- Credential-Option gesetzt, aber Datei-Option nicht `nullOr`

**Umgebungs-Assertions (die zweite Hälfte der Grenze):**
- Kill-Switch aktiv → `networking.nftables.enable`
- Kill-Switch aktiv → `boot.kernel.sysctl."net.ipv4.conf.all.rp_filter" ≠ 1`
  *Der Kernel nutzt `max(conf/all, conf/<iface>)` — eine Per-Interface-Ausnahme wirkt nicht, solange `all` auf 1 steht.*
- Kill-Switch aktiv → `host.vpn.interface != null && host.vpn.dns != []`
- `reverseProxy == "external"` → `services.caddy.enable`
- kein mediNix-Port in `networking.firewall.allowedTCPPorts`
- ACME-Gruppe == Gruppe der **effektiv laufenden** Proxy-Unit
- Warning bei `ip_forward = 1` (skuid hängt am output-Hook, geforwardeter Traffic hat keinen Socket-UID)

### 4.3 Guardrail-Review — die Prüfung der Prüfungen

Der teuerste Fehler ist nicht die fehlende Assertion, sondern die, die grün meldet, ohne etwas zu prüfen.

| Prüfung | Kat. | Kriterium |
|---|---|---|
| Jede Assertion ist falsifizierbar | [T] | Pro Assertion ein Negativtest: eine Konfiguration, bei der sie **feuern muss**. `builtins.tryEval` + `throw`, wenn sie nicht feuert. |
| Keine Tautologien | [M] | Klassiker: Vergleich gegen einen Wert, den das Enum nicht kennt (`auth.mode != "off"` bei `enum [ "none" "forward-auth" ]` ist immer wahr). Kurzschluss-`||` verdeckt dahinter zusätzlich fehlende Optionen. |
| Keine doppelten IDs | [A] | Gleiche Assertion-ID an zwei Stellen mit unterschiedlicher Logik ⇒ eine von beiden ist falsch. |
| Assertion prüft den **effektiven** Zustand | [M] | „Toggle steht auf X" ist schwächer als „Prozess läuft unter UID Y und lauscht auf Port Z". Wo nur der Toggle prüfbar ist, gehört die Wirkungsprüfung nach 4.4. |

### 4.4 Tests — deklariert ≠ wirksam

```python
# je Dienst
machine.wait_for_unit(f"{svc}.service")

pid = machine.succeed(f"systemctl show -p MainPID --value {svc}").strip()
uid = machine.succeed(f"awk '/^Uid:/{{print $2}}' /proc/{pid}/status").strip()
assert uid == str(reg_uid), f"{svc}: UID {uid} != Registry {reg_uid}"

machine.succeed(f"ss -Hltn 'sport = :{reg_port}' | grep -q 127.0.0.1")
machine.fail(f"ss -Hltn 'sport = :{reg_port}' | grep -q '0\\.0\\.0\\.0'")
machine.succeed(f"curl -sfo /dev/null http://127.0.0.1:{reg_port}/")
machine.succeed(f"systemd-analyze security --threshold={thr} {svc}.service")
```

| Prüfung | Kriterium |
|---|---|
| Reverse-Proxy-Upstream == Registry-Port | Sonst 502 bei laufendem Dienst — der häufigste stille Fehler. |
| Referenzierte Unit-Namen existieren | `reloadServices`, sudo-Listen, `after`/`requires`. Ein `after = [ "jellyfin-5510.service" ]` gegen eine Unit namens `jellyfin.service` ordnet gegen nichts. |
| Kill-Switch fail-closed | VPN unten → Drop. |
| Kill-Switch fail-open | VPN oben → Traffic durch den Tunnel. *(noch offen)* |
| Invariante hält über `switch` | `nixos-rebuild switch` mitten im Test, danach fail-closed erneut prüfen. Units starten in Abhängigkeitsreihenfolge neu — die Eigenschaft muss den Wechsel überleben, nicht nur den eingeschwungenen Zustand. |

### 4.5 Pinning

| Prüfung | Kat. | Kriterium |
|---|---|---|
| Inputs minimal | [M] | Ideal nur `nixpkgs`. `flake-utils` ist durch fünf Zeilen `forAllSystems` ersetzbar; jeder Input ist Vertrauensanker und Rot-Quelle. |
| Nichts außerhalb des Locks | [A] | Kein `@latest`, kein `fetchurl` ohne Hash, kein `curl` in `ExecStartPre`. |
| App-Auto-Updater aus | [A] | Direkte Folge des Locks: Nix hat die Version gepinnt, ein Selbst-Updater hebt genau das auf und macht Rollback wirkungslos. |
| Keine Overlays, die Apps neu bauen | [M] | Verwandelt Konfiguration in Wartung. |

### 4.6 Doku-Vertrag

| Prüfung | Kat. | Kriterium |
|---|---|---|
| Jede README-/ADR-Behauptung hat einen Codebeleg | [M] | Tabelle `Behauptung | Datei:Zeile | Urteil`. Sätze wie „Netzwerkisolation via `RestrictNetworkInterfaces`" oder „RAM-Disk für Downloads" ohne Beleg sind nicht Doku-Schulden, sondern Sicherheits-Fehlinformation: sie suggerieren Schutz, den es nicht gibt. |
| ADR-IDs auflösbar | [A] | Jede `adr:`-Referenz im Header zeigt auf eine existierende Datei. |

---

## Durchlauf-Reihenfolge

| # | Schritt | Warum hier |
|---|---|---|
| 0 | Stufe 0 komplett (drei Kommandos) | Ohne evaluierenden Code ist jedes inhaltliche Urteil Spekulation. |
| 1 | `lib/registry` → `lib/factory` → `lib/hardening` | Alles darüber erbt von hier. Ein Fehler in der Factory ist ein Fehler in *n* Diensten. |
| 2 | Je ein Dienst pro Dekade als Referenz | 511-caddy, 532-sonarr, 541-sabnzbd, 551-jellyfin. Muster festzurren, bevor es sich vervielfältigt. |
| 3 | Restliche Dekaden-Module | Jetzt mechanisch: Abweichung vom Referenzmuster ist der Befund. |
| 4 | 520-security | Braucht die Registry-UIDs als stabile Basis. |
| 5 | Flake-Root, `default.nix`, Standalone- vs. Embedded-Profil | — |
| 6 | Assertions + Guardrail-Review (4.3) | Erst wenn es Assertions gibt, lohnt es, sie zu prüfen. |
| 7 | `nixosTest`-Gate (4.4) | — |
| 8 | VPN-oben-Fix | Der Test aus 7 macht ihn beweisbar statt anekdotisch. |

---

## Gate vor „fertig"

| Gate | Kriterium | Nachweis |
|---|---|---|
| Evaluiert | `--parse`, `flake check`, `deadnix`, `statix` grün | Stufe 0 |
| Identität wirksam | Prozess-UID == Registry-UID, Dienst lauscht auf Registry-Port und nur dort | 4.4 |
| Grenze dicht | `no-host-takeover` und `hostile-minimal` grün | 4.1 |
| Guardrails echt | jede Assertion hat einen Negativtest, der sie zum Feuern bringt | 4.3 |
| Härtung folgenlos | .NET-Arrs laufen, `systemd-analyze security` unter Schwellwert | 4.4 |
| Kill-Switch | fail-closed **und** fail-open bewiesen, Invariante hält über `switch` | 4.4 |
| Doku wahr | keine unbelegte Behauptung in README/ADR | 4.6 |

---

## Anhang — Kurzform zum Abhaken

```
STUFE 0  [ ] nix-instantiate --parse (alle Dateien)
         [ ] nix flake check --no-build
         [ ] deadnix --fail . && statix check .
         [ ] grep: cfg-Scope, mkIf-in-Liste, \x-Escape, fakeSha256

LIB      [ ] Registry: eine Ableitung, keine Doppelnummer, Eintrag⇔Modul
         [ ] Factory: vollständiger Rückgabewert, Listen statt Skalare, kein mkForce
         [ ] Profile: jit ohne MDWE/~@resources, PrivateUsers=false, RestrictNamespaces=true
         [ ] recommended.* readOnly, wird nicht angewandt
         [ ] Credentials: ein Mechanismus, nullOr/null, .service-Suffix

MODUL    [ ] ein mkIf-Gate, keine Hardcodes, StateDirectoryMode=0700
         [ ] SupplementaryGroups=media nur bei Bedarf, UMask nur bei Schreibern
         [ ] SocketBindDeny+Allow gesetzt
         [ ] kein IPAddressDeny/RestrictNetworkInterfaces/PrivateNetwork (konfiniert)
         [ ] kein Host-Singleton, keine LAN-CIDR
         [ ] Profil nicht in Upstream-Unit gemergt

520      [ ] opt-in, an usenet-confinement gekoppelt
         [ ] mark+filter beide family=inet
         [ ] dns != [] assertiert
         [ ] kein ExecStop, RemainAfterExit, before=dienst
         [ ] Loopback-Accept eingeschränkt oder dokumentiert

GESAMT   [ ] no-host-takeover + hostile-minimal
         [ ] Umgebungs-Assertions (nftables, rp_filter/all, dns, caddy, ports, acme-gruppe)
         [ ] jede Assertion mit Negativtest
         [ ] nixosTest: UID, Bind, Proxy-Upstream, security-Schwelle
         [ ] Kill-Switch: closed + open + über switch
         [ ] Inputs minimal, kein @latest, Updater aus
         [ ] README/ADR-Behauptungen belegt
```
