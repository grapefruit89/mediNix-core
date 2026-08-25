# mediNix-Core — geschärfte Empfehlung

Vorbemerkung zu [Annahme]-Markierungen: die Dekaden-Umbenennung (`510-*`, Namespace `medinix`) ist ein Neubau, den ich nicht im Code gesehen habe. Aussagen über den *Ist-Zustand* sind entsprechend markiert; Aussagen über Mechanik und Zielzustand nicht.

---

## A. Zielbild

mediNix-Core ist ein NixOS-Modulsatz, der einen Medien-Stack **vollständig aus einer Auswertung** beschreibt: Prozessidentität, Unit-Definition, Härtung, Bindung und Egress-Klasse jedes Programms stehen an einer Stelle und werden bei jedem `switch` atomar gemeinsam durchgesetzt. Der Core beschreibt sich selbst — welche Ports, UIDs, State-Pfade, Credentials und Umgebungszusagen er braucht, ist als Daten abfragbar, nicht als Prosa dokumentiert. Er ist **additiv**: er legt eigene Units, User und nft-Tabellen an, schaltet aber keinen Host-Schalter um, sondern prüft per Assertion, ob die Umgebung seine Annahmen erfüllt. Isoliert wird nicht der Stack gegen den Host — der Host ist bekannt und vertraut — sondern **die Programme gegeneinander**: jedes Programm hat eine feste UID, ein eigenes State-Verzeichnis, das kein anderes lesen kann, eine erzwungene Bindung und eine explizite Egress-Klasse. Die geteilte media-GID ist die eine bewusste Ausnahme davon und gilt für Mediendaten, nicht für State.

---

## B. „Wenig externe Abhängigkeiten" — konkret

### B.1 Drei Stufen von App-Konfiguration

Die entscheidende Frage ist nicht *ob* App-Config in den Core gehört, sondern **ob die App die Einstellung bei jedem Start neu liest**. Danach richtet sich alles:

| Stufe | Merkmal | Beispiele | Gehört in den Core? |
|---|---|---|---|
| **1 — Start-gelesen** | Env-Var oder CLI, App liest bei jedem Start, überschreibt eigenen State | `SONARR__SERVER__PORT`, `SONARR__AUTH__METHOD`, `ND_PORT`/`ND_ADDRESS`, ABS `PORT`/`HOST`, Jellyfin `--datadir` | **Ja, vollständig.** Deklarativ im Wortsinn. |
| **2 — Datei, von der App überschrieben** | INI/XML, App schreibt zurück | `sabnzbd.ini`, Jellyfin `network.xml`/`system.xml` | **Ja, aber schreibgeschützt.** Genau ein Eigentümer. |
| **3 — Datenbank-State** | liegt in SQLite, nur über API/GUI änderbar | Arr-Indexer, Root-Folders, Quality-Profiles, Jellyfin-Bibliotheken, Jellyseerr-Settings | **Nein, per Default.** |

Zu Stufe 2 die einzige KISS-taugliche Regel: **entweder Nix besitzt die Datei (schreibgeschützt, App meckert im Log) oder die App besitzt sie (Nix fasst sie nie an).** Beides gleichzeitig — Datei generieren *und* der App Schreibrecht lassen — erzeugt einen Zustand, der nach jedem Switch anders ist als vor dem Switch, und zerstört die Rollback-Eigenschaft. Für SABnzbd heißt das `allowConfigWrite = false` und alles Nötige über `settings`.

Zu Stufe 3: Provisioning gegen eine laufende App ist ein Zustandskrieg gegen die GUI und läuft dem „eine Auswertung, atomarer Switch"-Versprechen zuwider. Empfehlung: **Bootstrap-only**, ausgelöst durch `ConditionPathExists=!<flag>`, niemals bei jedem Switch, und als klar benanntes Opt-in (`medinix.bootstrap.enable = false` per Default). Wer es einschaltet, akzeptiert, dass GUI-Änderungen beim nächsten erzwungenen Lauf verloren gehen — das muss in der Optionsbeschreibung stehen.

### B.2 Core vs. Host, entlang der Fakten-Grenze

| Core (Stack-Fakt) | Host (Maschinen- oder Personen-Fakt) |
|---|---|
| Nummern, Ports, UIDs, GIDs, State-Pfade unter `/var/lib` | Bibliothekspfade, Mountpoints, Dateisystem-Layout |
| Bind-Adresse `127.0.0.1` + Port + **Erzwingung** | Domain, LAN-CIDRs, DNS-Server-IPs, Interface-Namen |
| Auth-Modus, abgeleitet aus `ingress.auth.mode` | Ob überhaupt Forward-Auth gefahren wird |
| Auto-Updater der Apps **aus** (siehe B.3) | Kernel, sysctl, initrd, Bootloader, TPM/PCR |
| Log-Level, Telemetrie/Analytics aus, `urlBase = ""` | Locale, Quality-Profiles, Indexer, Usenet-Provider |
| Querverweise *innerhalb* des Stacks (Arr → Download-Client) | Alle Credentials und deren Pfade |
| Egress-Klasse pro Dienst, nft-Regeln **als Daten** | `networking.nftables.enable`, Firewall-Backend |
| Hardening-Profile, Credential-*Bedarf* (Name + Format) | Credential-*Lieferung* (Pfad, Sealing, Rotation) |

Merksatz für Grenzfälle: **Wenn der Wert auf einer anderen Maschine sinnvoll gleich bleibt, ist er Core. Wenn er sich zwingend ändern muss, ist er Host — und dann `nullOr` mit Default `null`.**

### B.3 `flake.lock` als Untergrenze

Der Lock fixiert nixpkgs und damit die App-Versionen. Er ist die *untere* Grenze der Reproduzierbarkeit; alles darüber (Host, Secrets, Mediendaten) ist nicht reproduzierbar und muss deshalb ein **expliziter Eingang** sein, keine stille Annahme. Vier Konsequenzen:

1. **Nichts wird außerhalb des Locks bezogen.** Keine `@latest`-Plugin-Pins, kein `fetchurl` ohne Hash, kein `builtins.fetchTarball` ohne `sha256`, kein `curl` in `ExecStartPre`. Ein `lib.fakeSha256` als Platzhalter ist kein TODO, sondern ein garantierter Build-Fehler.
2. **App-Auto-Updater gehören aus — und zwar im Core.** Nix hat die Version gepinnt; ein Selbst-Updater hebt genau diesen Pin auf und macht Rollback wirkungslos. Das ist keine Geschmacksfrage, sondern die direkte Folge des Locks, und deshalb Core-Config (Stufe 1).
3. **Default-Werte für Host-Fakten sind Fälschungen.** Ein Default `"wg0"` oder `/data/library` behauptet einen Fakt, den der Lock nicht garantieren kann. `null` + Assertion ist die einzige ehrliche Form.
4. **Inputs minimieren.** Ideal: nur `nixpkgs`. Jeder weitere Input ist ein zusätzlicher Vertrauensanker und eine zusätzliche Rot-Quelle. `flake-utils` lässt sich durch fünf Zeilen `forAllSystems` ersetzen — bei einem öffentlichen Flake ein realer Gewinn. [Annahme: aktuell sind `nixpkgs` + `flake-utils` gepinnt.] Ebenso: kein Overlay, das große Pakete neu baut; wer Jellyfin lokal kompilieren muss, hat ein Wartungsproblem statt einer Anpassung.

---

## C. Boundary-Mechanik

### C.1 Arity-Regel

| Schreibziel | Regel |
|---|---|
| Additiv, **eigener** Schlüssel — `systemd.services.medinix-*`, `users.users.<unsere-uid>`, `networking.nftables.tables.medinix_*`, `systemd.tmpfiles.rules` | erlaubt |
| Additiv, **fremder** Schlüssel — `services.caddy.virtualHosts.<domain>`, `networking.firewall.allowedTCPPorts` | nur hinter explizitem Opt-in |
| **Singleton** — `networking.nftables.enable`, `boot.kernel.sysctl.*`, `boot.initrd.*`, `boot.kernelParams`, `services.caddy.enable`, `security.sudo.extraConfig`, `hardware.graphics.enable` | verboten; stattdessen Assertion |

Die Regel ist grepbar und damit ein Check, kein Vorsatz.

### C.2 publish-don't-apply

```nix
options.medinix.recommended = {
  sysctl       = mkOption { type = types.attrsOf types.anything; readOnly = true; };
  nftables     = mkOption { type = types.attrsOf types.anything; readOnly = true; };
  mountOptions = mkOption { type = types.attrsOf (types.listOf types.str); readOnly = true; };
};
```

Host-Bridge, eine Zeile pro Ebene:

```nix
boot.kernel.sysctl         = config.medinix.recommended.sysctl;
networking.nftables.enable = true;
networking.nftables.tables = config.medinix.recommended.nftables;
```

Der Core bleibt inert und die Empfehlungen sind vor der Anwendung diffbar (`nix eval …#…config.medinix.recommended.sysctl`).

### C.3 Umgebungs-Assertions — die zweite Hälfte der Grenze

```nix
assertions = [
  # 1 — Regeln werden nur geladen, wenn der Host das Backend fährt
  { assertion = ksActive -> config.networking.nftables.enable;
    message = "[medinix] Kill-Switch aktiv, aber networking.nftables.enable = false. "
            + "Der Core schaltet das Backend nicht selbst um — in der Host-Bridge setzen."; }

  # 2 — der Grund, warum der VPN-oben-Pfad still bricht
  #     Kernel nutzt max(conf/all, conf/<iface>) — 'all' allein entscheidet
  { assertion = ksActive -> (config.boot.kernel.sysctl."net.ipv4.conf.all.rp_filter" or 0) != 1;
    message = "[medinix] rp_filter=1 auf 'all' verwirft asymmetrisch geroutete Rückpakete. "
            + "Policy-Routing braucht 2 (loose). Per-Interface-Ausnahmen wirken nicht."; }

  # 3 — leere resolv.conf ⇒ glibc-Fallback auf 127.0.0.1 ⇒ DNS am Tunnel vorbei
  { assertion = ksActive -> (cfg.host.vpn.dns != [] && cfg.host.vpn.interface != null);
    message = "[medinix] Kill-Switch braucht Interface UND DNS-Server. Ohne DNS entsteht ein Leak, kein Schutz."; }

  # 4 — 'external' ist sonst eine ungeprüfte Hoffnung
  { assertion = (cfg.hostIntegration.reverseProxy == "external") -> config.services.caddy.enable;
    message = "[medinix] reverseProxy = external, aber kein Caddy auf dem Host. "
            + "Entweder Host-Caddy aktivieren oder auf managed stellen."; }

  # 5 — Apps sind Loopback-only; ein offener Port heißt: ohne TLS und ohne Auth erreichbar
  { assertion = lib.intersectLists medinixPorts config.networking.firewall.allowedTCPPorts == [];
    message = "[medinix] mediNix-Dienstport in networking.firewall.allowedTCPPorts. "
            + "Exposition läuft ausschließlich über den Reverse-Proxy."; }

  # 6 — ACME-Gruppe muss zur effektiv laufenden Proxy-Unit passen
  { assertion = acmeActive -> (config.security.acme.defaults.group == effectiveProxyGroup);
    message = "[medinix] Zertifikat-Gruppe passt nicht zur Proxy-Unit — key.pem ist nicht lesbar."; }
];

warnings = lib.optional
  ((config.boot.kernel.sysctl."net.ipv4.ip_forward" or 0) == 1)
  "[medinix] ip_forward = 1: der skuid-Kill-Switch hängt am output-Hook und erfasst "
+ "geforwardeten Traffic nicht. Kein Loch, solange kein konfinierter Dienst Forwarding auslösen kann.";
```

Assertion 2 ist wahrscheinlich die, die den aktuellen Debug-Fall in Zukunft überflüssig macht.

### C.4 Tri-State — nur wo nötig, mit Wechselkosten

Nötig für: `reverseProxy`, `nftables`, `storage`. **Nicht** nötig für Kernel-sysctl (immer `recommended` + Host) und nicht für Secrets (immer Host).

Default im öffentlichen Core: `external`. `profiles.standalone` setzt `managed`.

Wechselkosten, die pro Ressource dokumentiert gehören:

| Ressource | `managed → external` hinterlässt | Folge |
|---|---|---|
| Caddy | `/var/lib/caddy-<uid>`, ACME-Zertifikate mit Gruppe der alten Unit | neuer Proxy kann `key.pem` nicht lesen → kein TLS |
| Caddy | `reloadServices = [ "<alte-unit>.service" ]` in `security.acme` | Renewal reloadet ins Leere → abgelaufenes Zertifikat |
| nftables | Tabelle `medinix_*` bleibt im Kernel, bis geflusht | tote Regeln, die niemand mehr verwaltet |
| storage | tmpfiles-erzeugte Verzeichnisse mit setgid | verwaist, aber gruppenbeschreibbar |

`managed` ist außerdem **exklusiv**: sobald der Core `services.caddy` besitzt, streitet der Host um dieselben Skalare (`globalConfig`, `package`, ACME-`email`). Das braucht eine eigene Assertion.

---

## D. Programm-gegen-Programm

Kein netns, kein `PrivateNetwork` für SABnzbd, keine Isolation vom Host. Nur diese sieben nativen Mittel:

| Mittel | Konkret | Wogegen |
|---|---|---|
| **Feste UID + eigene Unit** | `users.users.<n>.uid` aus der Registry; Unit besitzt sie | Grundlage für skuid, Dateieigentum, Audit |
| **State-Trennung** | `StateDirectoryMode = "0700"`, Eigentümer = Dienst-User | verhindert, dass ein kompromittierter Dienst die SQLite-DB eines anderen liest — inkl. API-Keys und Provider-Zugangsdaten |
| **Geteilte media-GID, bewusst begrenzt** | GID 5000 + setgid 2775 + `UMask=0002` **nur auf Mediendaten**, nie auf State-Dirs | die eine gewollte Ausnahme; das Verwischen von State und Daten ist der teure Fehler |
| **Protect\*-Baseline (.NET-tauglich)** | siehe unten | Rechteausweitung nach RCE |
| **Bind-Erzwingung** | `SocketBindDeny = ["any"]` + `SocketBindAllow = ["ipv4:tcp:<port>" "ipv6:tcp:<port>"]` | Konfiguration ist eine Bitte, das hier ist Durchsetzung — die App scheitert laut statt still auf `0.0.0.0` zu lauschen |
| **Egress-Klasse** | Registry-Feld; `unrestricted` (Default, keine Regel) und `vpn` (skuid + Policy-Routing) | KISS: zwei Klassen bauen, nicht vier. `none`/`lan` erst, wenn ein Dienst sie braucht |
| **Dateisystem-Confinement** | `ProtectSystem = "strict"` + `ReadWritePaths` + `BindReadOnlyPaths` + `TemporaryFileSystem = ["/tmp:noexec,nosuid,nodev"]` | bösartiger Archivinhalt beim Entpacken |

**Baseline, für .NET/Node/Python gleichermaßen tragfähig:**

```nix
NoNewPrivileges         = true;
PrivateTmp              = true;
PrivateMounts           = true;
PrivateUsers            = false;   # bricht sonst CAP_NET_BIND_SERVICE und /dev/dri via SupplementaryGroups
ProtectSystem           = "strict";
ProtectHome             = true;
ProtectClock            = true;
ProtectHostname         = true;
ProtectKernelTunables   = true;
ProtectKernelModules    = true;
ProtectKernelLogs       = true;
ProtectControlGroups    = true;
RestrictNamespaces      = true;    # per-Unit statt systemweitem userns-Kill
RestrictRealtime        = true;
RestrictSUIDSGID        = true;
LockPersonality         = true;
RemoveIPC               = true;
SystemCallArchitectures = "native";
SystemCallFilter        = [ "@system-service" ];   # @resources ist enthalten und bleibt drin
SystemCallErrorNumber   = "EPERM";                 # nicht SIGSYS: sonst stiller Tod bei Syscall-Probing
CapabilityBoundingSet   = [ "" ];
AmbientCapabilities     = [ "" ];
RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
```

Drei Punkte, die leicht falsch laufen:

- **`AF_NETLINK` bleibt drin.** .NET ruft beim Start `NetworkInterface.GetAllNetworkInterfaces()` über Netlink. Streichen ⇒ Startfehler ohne verwertbares Log.
- **`ProcSubset = "pid"` gehört *nicht* in die Baseline.** Es blendet `/proc/cpuinfo`, `/proc/meminfo`, `/proc/stat` aus; .NET-GC, Node und ffmpeg-Hardware-Erkennung lesen davon. Als Opt-in pro Dienst, nach Test.
- **`IPAddressDeny`, `RestrictNetworkInterfaces`, `PrivateNetwork` sind für den konfinierten Dienst tabu.** Alle drei sind cgroup-BPF bzw. Namespace und greifen *unterhalb* von Routing und fwmark — sie sind beim Routing-Debugging unsichtbar und blockieren genau den Pfad, den der Kill-Switch erlauben soll. Egress-Kontrolle macht ausschließlich nftables über skuid.

**Bewusst offen gelassen:** Loopback ist zwischen allen Diensten flach. Ein konfinierter Dienst erreicht jeden anderen Loopback-Port; bietet einer davon ein Fetch-Primitiv, existiert ein Relay am Tunnel vorbei. Sauber wäre `skuid` + `dport` in der Output-Chain. KISS-Position: **jetzt dokumentieren, später bauen** — es betrifft genau eine UID, und der Aufwand lohnt erst, wenn der Grundpfad steht.

---

## E. Reihenfolge

| # | Schritt | Warum an dieser Stelle |
|---|---|---|
| **1** | **VPN-oben reparieren.** `IPAddressDeny` / `RestrictNetworkInterfaces` / `PrivateNetwork` aus dem SABnzbd-Profil. Dann: `src <wg-addr>` in der Policy-Route, `rp_filter = 2` auf **`all`**, zuletzt MSS-Clamping. [Annahme: mindestens eine der drei Direktiven steht aktuell im Profil.] | Drei-Zeilen-Eingriff, hängt an keiner Factory. Danach existiert ein funktionierender Pfad als Regressionsanker — sonst debuggt man später ein bewegtes Ziel. Zerlegt die bestehende Kill-Switch-Arbeit nicht, sondern macht sie erst wirksam. |
| **2** | **Test-Gate.** `nixosTest`: Unit läuft, User existiert mit Registry-UID, App lauscht auf dem Registry-Port und **nur** dort, HTTP antwortet. Zweiter Knoten als WireGuard-Peer: fail-closed **und** fail-open als Regressionstests. Plus `switch` mitten im Test — die Fail-closed-Eigenschaft muss den Switch überleben. | Macht deklarierte Identität zu bewiesener Identität. Ohne das ist jede Härtung Blindflug, und die häufigste Fehlklasse (Config sagt X, App tut Y) bleibt statisch unsichtbar. |
| **3** | **Grenzvertrag.** `medinix.host.*` mit `null`-Defaults, `medinix.recommended.*` als `readOnly`, die Assertions aus C.3, plus zwei Eval-Checks: `hostile-minimal` (nichts vom Host geliefert ⇒ saubere Assertion, kein `undefined variable`) und `no-host-takeover` (Core an, `external` ⇒ `nftables.enable == false`, `boot.kernel.sysctl == {}`). | Ab hier ist „additiv" eine getestete Eigenschaft statt einer Behauptung. |
| **4** | **Härtungs-Factory + `SocketBindDeny`**, abgesichert durch Schritt 2. Trennung: eigene Unit ⇒ volles Profil; Upstream-Modul ⇒ nur additive Keys und `mkDefault`, niemals `User`/`Group`/`StateDirectory`/`ExecStart` per `serviceConfig`. Kein `mkForce` im Core. | Riskantester Schritt der Liste, deshalb nach dem Test. Die Trennung verhindert den `mergeEqualOption`-Abbruch und ist zugleich die Antwort auf „keine Doppel-Abstraktionen". |
| **5** | **Caddy-Tri-State** + ACME-Eigentum an die effektive Unit koppeln + die Wechselkosten aus C.4 dokumentieren. | Erst jetzt gefahrlos: die Assertions aus 3 fangen den `external`-Fall ab, der Test aus 2 beweist den `managed`-Fall. |
| **6** | **Secrets-Vertrag** (`medinix.credentials` = Bedarf, `medinix.host.credentials` = Lieferung, Assertion am Verbraucher, Runtime-Pfad mit `.service`-Suffix) und `recommended.sysctl` / `recommended.mountOptions` befüllen — inkl. `noexec,nosuid,nodev` auf dem Staging-Mount. | Beides additiv und ohne Risiko für das Bestehende; gehört ans Ende, weil es nichts blockiert. |

---

## F. Nicht-Ziele

| Nicht bauen | Grund |
|---|---|
| **Eigene Factory, die nixpkgs-Servicemodule umhüllt** | Genau die Doppel-Abstraktion, die das Zielbild ausschließt. Entweder man besitzt die Unit oder man nutzt das Modul — dazwischen liegt nur `mergeEqualOption`. |
| **Deklaratives Provisioning von DB-State bei jedem Switch** | Zustandskrieg gegen die GUI; hebt Rollback praktisch auf. Bootstrap-only, Opt-in. |
| **netns / `PrivateNetwork` pro Dienst** | Zerstört die skuid-Markierung, auf der der Kill-Switch beruht. Bereits entschieden, hier nur als Grenze markiert. |
| **Systemweites `user.max_user_namespaces = 0`** | Bricht die Nix-Build-Sandbox (nixpkgs assertet das selbst gegen `nix.settings.sandbox`), `DynamicUser=` und `PrivateUsers=`. `RestrictNamespaces = true` per Unit deckt dieselbe Fläche portabel ab. |
| **Landlock** | Keine native systemd-Direktive; Mount-Namespaces liefern hier dasselbe, deklarativ und übersteuerbar. |
| **SELinux / AppArmor** | Auf NixOS kein policy-vollständiger, gepflegter Pfad. Aufwand geht komplett ins Policy-Debugging. |
| **L7-Sicherheit in Caddy** (WAF, Rate-Limit, Geoblock, Bouncer-Plugins) | Verlagert Policy in die TLS-Terminierung und macht das Proxy-Paket unreproduzierbar. Caddy bleibt dünn. |
| **Eigener Kernel, kernelPatches, hardened-Kernel im Core** | Host-Fakt, Rebuild-Kosten, bricht Out-of-Tree-Module fürs Transcoding. |
| **Overlays, die Apps neu bauen** | Verwandelt Konfiguration in Wartung; der Lock verliert seinen Sinn als Untergrenze. |
| **Mehr Flake-Inputs als nötig** | Jeder Input ist Vertrauensanker und Rot-Quelle. `flake-utils` ist durch fünf Zeilen ersetzbar. |
| **Metriken/Dashboards vor Schritt 2** | Überwachung eines Dienstes, dessen korrektes Verhalten nie definiert wurde, misst Rauschen. |
| **Vier Egress-Klassen, bevor zwei laufen** | Registry-Feld vorbereiten ja, Regelwerk bauen nein. |
| **Perfect-Dendritic-Refactor vor Boundary und Test** | Umbau ohne Netz; die Reihenfolge ist genau falsch herum. |

---

**Nächster konkreter Schritt:** `IPAddressDeny`, `RestrictNetworkInterfaces` und `PrivateNetwork` aus dem SABnzbd-Profil entfernen, `src <wg-adresse>` in die Policy-Route aufnehmen und `net.ipv4.conf.all.rp_filter` auf `2` setzen — dann prüfen, ob Traffic durch den Tunnel geht.
