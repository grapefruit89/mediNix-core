# Pocket-ID Nix-Modul: Produktionsreife-Audit

**Created:** 8/21/2026 14:08:52  
**Updated:** 8/22/2026 20:25:35  
**Exported:** 8/24/2026 17:24:39  
**Link:** [https://claude.ai/chat/7036d919-266d-4721-9010-658151f83d1a](https://claude.ai/chat/7036d919-266d-4721-9010-658151f83d1a)  

## User:

> 8/21/2026 14:08:53

> File: 

## Assistant:

> 8/21/2026 14:22:33

> Cataloging critical P0 issues and tracing system conflicts.
>
> - [https://github.com/grapefruit89/mediNix-core/tree/main/50-core](https://github.com/grapefruit89/mediNix-core/tree/main/50-core)
> - [https://api.github.com/repos/grapefruit89/mediNix-core/contents/50-core](https://api.github.com/repos/grapefruit89/mediNix-core/contents/50-core)
> - grapefruit89/mediNix-core github
> - Investigated missing repository and strategized alternative search methods.
> - Check if the repo exists via GitHub API
> - Clone the repo
> - List folder contents
> - Read manifest and READMEs
> - Read caddy module
> - Deciphering Nix's chained fallback semantics.
> - Read pocket-id and acme
> - Identifying critical service mismatch causing certificate staleness.
> - Read cloudflare dns
> - Unearthed multiple critical bugs spanning undefined variables, JSON formatting, and DNS leaks.
> - Verify undefined variable idpDomains
> - Check nixpkgs pin
> - Read registry head
> - Scrutinized registry discrepancies across multiple service configurations.
> - Grep default.nix for ingress options
> - Read default.nix imports
> - Read ingress + pocketId options
> - Investigating auth.skipPa configuration issue.
> - Read service factory
> - Reconciling systemd service configuration with security group assignments.
> - Read hardening profiles
> - Scrutinized capability scoping conflicts across hardened systemd profiles.
> - Fetch nixpkgs pocket-id module at pinned rev
> - Inspect pocket-id module details
> - Debugged NixOS module conflicts across service configuration options.
> - Check deprecated settings list
> - Read mdns and landingpage
> - Unearthed critical configuration bugs and security violations in Caddy setup.
> - Read 52 small modules
> - Identifying resource creation logic outside module guards.
> - Read killswitch
> - Excavated multiple security vulnerabilities in VPN killswitch configuration.
> - Find killswitch consumers
> - Check sabnzbd killswitch wiring and cross-domain guardrails
> - Unearthed conflicting module requirements blocking build completion.
> - Check vpnInterface wiring
> - Identified contradictory configuration requirements causing inevitable build failures.
> - Check nftables/firewall/crowdsec cross-domain
> - Identified naming inconsistencies and conditional enablement gaps in firewall configuration.
> - Check runtime guard, crowdsec, guardrail gating
> - Excavated cascading mismatches across VPN, firewall, and CrowdSec configurations.
> - Check phantom options and nix availability
> - Diagnosed duplicate attribute error in Nix configuration file.
> - Verify duplicate vhost and ingress guardrails
> - Investigated configuration schema validity and authentication logic flaws.
> - Check phantom option and ADRs
> - Unearthed hidden configuration bug masked by logical short-circuiting.
> - Read key ADRs
> - Excavated architectural drift, DNS leaks, and manifest contradictions systematically.
> - Check if lib.toCamelCase exists in pinned nixpkgs
> - Cataloging critical P0 issues and tracing system conflicts.
> - Check available public skills for md
> - Cross-domain audit report for mediNix-core 50/51/52
> - Presenting file(s)...
> - **Done**

Repo geklont und vollständig gelesen (nicht nur READMEs), inkl. `lib/registry.nix`, `hardening-profiles.nix`, `service-factory.nix`, `default.nix`, `flake.nix` und den 53/54/55/58/59-Konsumenten. Zur Absicherung habe ich das `services.pocket-id`-Modul aus dem gepinnten nixpkgs-Rev (`ec2d622`) gegengelesen.

**Kurzfassung: nicht produktionsreif — das Repo evaluiert nicht.** Vier harte Nix-/Modulsystem-Fehler blockieren `nix flake check`, bevor irgendeine Sicherheitsaussage überhaupt testbar wird:

- `526`: `systemd.services` zweimal im selben Attrset (Z. 121 + Z. 171) → `attribute 'services' already defined`
- `520`: Top-Level-`users` neben explizitem `config` → *„unsupported attribute"*
- `513`: `idpDomains` ist nirgends definiert
- `555`: identische VHost-Zeile zweimal (Z. 81/83)

Danach bleiben echte Fail-Open-Stellen: der Public-VHost-Guardrail vergleicht `auth.mode != "off"` gegen ein Enum ohne `"off"` (Tautologie, verdeckt zusätzlich die Phantom-Option `allowPublicUnauth`), Forward-Auth erzeugt einen Lockout-Deadlock, und der Killswitch mountet eine leere `resolv.conf` → glibc-Fallback auf `127.0.0.1`, der von der `mark`-Chain akzeptiert wird = DNS am Tunnel vorbei.

Positiv verifiziert: `proxied=false` ist fest verdrahtet (ADR-5130 eingehalten), die `route`-Chain sitzt korrekt in der `ip`- statt der `inet`-Tabelle, `oifname wg0` steht hinter dem Mark-Match, und SABnzbds `skuid` kommt sauber aus `registry.sabnzbd.uid` (5410). `50-core` enthält keine `.nix` und wird vom Auto-Import nie erfasst — als Vertrag geprüft, lügt es bei vier von fünf Prinzipien.

> File: [/mnt/user-data/outputs/AUDIT-50-51-52.md](https://claude.ai/api/organizations/1bf68e4d-4589-4229-97d3-b02ff6d570ca/conversations/7036d919-266d-4721-9010-658151f83d1a/wiggle/download-file?path=%2Fmnt%2Fuser-data%2Foutputs%2FAUDIT-50-51-52.md)

---

**Sources:**

- [GitHub - grapefruit89/FritzBoxBlacklist: kurze aber knackige Blacklist für die Fritzbox (unter 500 Einträge), blockiert schonmal einen großen Teil Werbung und Scripte · GitHub](https://github.com/grapefruit89/FritzBoxBlacklist)
- [GitHub - ds84182/Grapefruit: Modular Hypervisor for OpenComputers](https://github.com/ds84182/Grapefruit)
- [GitHub - grapefruitinc/grapefruit: open source learning management system (inactive as of May 2016)](https://github.com/grapefruitinc/grapefruit)
- [GitHub - chanpu9/Grapefruit: (WIP) Runtime Application Instruments for iOS. Previously Passionfruit · GitHub](https://github.com/chanpu9/Grapefruit)
- [grapefruit89 - Overview](https://github.com/grapefruit89)
- [GitHub - ChiChou/grapefruit: (WIP) Runtime Application Instruments for iOS. Previously Passionfruit](https://github.com/ChiChou/Grapefruit)
- [grapefruit - Overview](https://github.com/grapefruit)
- [FritzBoxBlacklist/Fritz 500 2020-11-23.txt at master · grapefruit89/FritzBoxBlacklist](https://github.com/grapefruit89/FritzBoxBlacklist/blob/master/Fritz%20500%202020-11-23.txt)
- [GitHub - grapefruitjs/grapefruit: Outdated, I recommend you use photonstorm/phaser instead!](https://github.com/grapefruitjs/grapefruit)
- [GrapeFruit · GitHub](https://github.com/grapefruitjs)
- [grapefruit · GitHub Topics](https://github.com/topics/grapefruit)
- [FritzBoxBlacklist/docs/06-testing.md at master · grapefruit89/FritzBoxBlacklist](https://github.com/grapefruit89/FritzBoxBlacklist/blob/master/docs/06-testing.md)
- [FritzBoxBlacklist/README.md at master · grapefruit89/FritzBoxBlacklist](https://github.com/grapefruit89/FritzBoxBlacklist/blob/master/README.md)
- [Activity · grapefruit89/FritzBoxBlacklist](https://github.com/grapefruit89/FritzBoxBlacklist/activity)
- [grapefruit89 on CodePen](https://codepen.io/grapefruit89/collections/loved?love_type=beta)
- [{Grapefruit89's Friends and Followers} - Scratch Studio](https://scratch.mit.edu/studios/5900243/)
- [grapefruit/README.md at master · ChiChou/grapefruit](https://github.com/ChiChou/grapefruit/blob/master/README.md)
- [GeeXboX](https://en.wikipedia.org/wiki/GeeXboX)
- [GRAPE](https://en.wikipedia.org/wiki/GRAPE)
- [grapefruit/README.md at archive · ChiChou/grapefruit](https://github.com/ChiChou/grapefruit/blob/archive/README.md)

## User:

> 8/21/2026 14:42:15

> File: 

## Assistant:

> 8/21/2026 14:54:08

> Cataloging inconsistencies across indexer query documentation.
>
> - Verify repo present and list folders
> - Read sonarr and prowlarr
> - Excavated multiple Nix syntax errors and configuration inconsistencies.
> - Check other arr modules and brace balance
> - Read sabnzbd
> - Scrutinizing storage paths against mover expectations.
> - Check raw backslash in mount unit name
> - Read mover
> - Detecting recursive directory mismatch triggering failures.
> - Read jellyfin
> - Unearthed critical infrastructure bugs and security misconfigurations throughout Jellyfin module.
> - Read remaining playback modules
> - Scrutinized NixOS media stack for config bugs and security vulnerabilities.
> - Read arr-settings
> - Scrutinized environment variable configurations and identified misaligned framework assumptions.
> - Check package existence in pinned nixpkgs
> - Check packages via raw
> - Check feishin outputs and seerr location
> - Verified package alias and identified missing dependency error.
> - Check seerr and sabnzbd nixos modules
> - Find module paths
> - Verified package absence across nixpkgs repositories.
> - Read nixpkgs sabnzbd module
> - Inspect sabnzbd module config section
> - Excavated configuration conflicts and identified network policy blocking service functionality.
> - Check options in default.nix
> - Read mover/storage options
> - Identifying API key configuration bug behavior.
> - Check per-service options incl secrets scope
> - Investigated configuration structure and identified missing attribute error.
> - Check sabnzbd and remaining service options
> - Identified unused configuration options and module mismatches.
> - Read 53 and 55 READMEs
> - Scrutinized network configuration claims and access permissions.
> - Check RW paths and storage/provisioning
> - Identified type coercion incompatibility in conditional systemd configuration.
> - Check tmpfiles dir list
> - Cataloging inconsistencies across indexer query documentation.
> - Check ADRs for 53/54/55
> - List 53-56 ADRs
> - Cross-domain audit report for mediNix-core 53/54/55
> - Presenting file(s)...
> - **Done**

Repo neu geprüft auf Commit `ff0a0eb` (main, 2026-08-20), nixpkgs-Rev `ec2d622`. Das SABnzbd-Modul, `module-list.nix`, `all-packages.nix` und die `by-name`-Pfade habe ich am gepinnten Rev gegengelesen.

**Evaluiert nicht.** Acht der zwölf Module haben harte Nix-Fehler:

- `536-prowlarr.nix:89` — eine Klammer zu viel (20 auf / 21 zu; die vier Schwesterdateien liegen bei 20/20)
- `cfg.secrets.*` im Service- statt Root-Scope in **sieben** Dateien (`medinix.sonarr.secrets` existiert nicht)
- `systemd.services.<name>` zweimal in derselben Attrmenge in acht Modulen; bei `541` sogar `after` doppelt
- `reg` undefiniert in `551`/`552`; `554` liest `medinix.services.feishin`
- `pkgs.seerr` gibt es am gepinnten Rev nicht (kein by-name-Eintrag, kein all-packages-Eintrag, kein NixOS-Modul)

Drei Laufzeitbefunde, die auch nach der Reparatur bleiben:

**Die Arrs bekommen keinen User.** `532:51` selektiert `(mkService {...}).systemd.services.sonarr` und wirft damit die `users.users.sonarr`-Hälfte der Factory weg. Keine der fünf Units hat einen existierenden `User=` — und die isomorphen UIDs 5320–5360 werden nie vergeben.

**Der Killswitch schützt eine Leiche.** Das `python`-Profil merged `IPAddressDeny=any` mit nur Loopback-Freigabe in die SABnzbd-Unit. Das ist ein eBPF-Socketfilter, unabhängig von Routing und fwmark — NNTP auf 563 ist unmöglich, egal welches Interface. Der Profilkommentar („geht durch VPN-ns") ist ein Rest des Ansatzes, den ADR-5260 verworfen hat.

**Der Mover schreibt auf Root.** Geprüft wird nur `[ -d "$STAGING" ]`, dann `mkdir -p "$ARCHIVE"`. `archiveDir` ist per Default `/data/library`, und `570-storage` legt nur `/data/media/{movies,series,books,music}` an — der Pfad ist also nie ein Mountpoint, womit auch `RequiresMountsFor` auf `-.mount` auflöst und immer erfüllt ist.

Sauber verifiziert: die UID-Kette SABnzbd → `registry.sabnzbd.uid` = 5410 → `meta skuid 5410` stimmt exakt, und `AUTH__METHOD` hängt bei allen fünf Arrs korrekt an `ingress.auth.mode` — nur bei Seerr nicht.

> File: [/mnt/user-data/outputs/AUDIT-53-54-55.md](https://claude.ai/api/organizations/1bf68e4d-4589-4229-97d3-b02ff6d570ca/conversations/7036d919-266d-4721-9010-658151f83d1a/wiggle/download-file?path=%2Fmnt%2Fuser-data%2Foutputs%2FAUDIT-53-54-55.md)

## User:

> 8/22/2026 13:31:39

> File: 

## Assistant:

> 8/22/2026 13:38:04

> Architected layered architecture separating portable policy from host-specific integration.
>
> - Architected layered architecture separating portable policy from host-specific integration.
> - Architecture recommendation for mediNix flake/host boundary and kernel hardening
> - Presenting file(s)...
> - **Done**

Die vier Kernaussagen vorab, damit du entscheiden kannst, ob sich das Lesen lohnt:

**Die Grenze ist eine Fakten-Grenze, keine Options-Grenze.** Der Kern darf keine Aussage über die Maschine treffen. Prüfbar wird das über die Arity des Schreibziels: additive Schreibvorgänge mit eigenem Schlüssel (`systemd.services.<unsere-unit>`, `nftables.tables.medinix_*`) sind erlaubt, Singletons (`networking.nftables.enable`, `boot.kernel.sysctl.*`, `boot.initrd.*`) nie. Das Muster, das den scheinbaren Widerspruch zwischen „Security im Kern" und „nichts Globales anfassen" auflöst, ist **publish-don't-apply**: der Kern veröffentlicht `medinix.recommended.{sysctl,nftables,mountOptions}` als `readOnly`-Daten, die Host-Bridge wendet sie mit je einer Zeile an.

**Zum userns-Punkt, der dich am meisten beschäftigt: systemweit abschalten ist der falsche Hebel.** `user.max_user_namespaces = 0` zerlegt die Nix-Build-Sandbox, `DynamicUser=` und `PrivateUsers=`. `RestrictNamespaces = true` per Unit deckt genau die Angriffsfläche ab, die du meinst — portabel, ohne Host-Wirkung. Und `PrivateUsers` gehört im ganzen Stack auf `false`: es bricht privilegierte Ports (Capabilities wirken nur im eigenen Namespace, die Netzwerk-Namespace gehört dem initialen) und den `render`-Gruppenzugriff auf `/dev/dri`.

**Zum kaputten VPN-oben-Pfad — konkreter Verdacht.** Drei systemd-Direktiven sehen aus wie Netzwerk-Policy, greifen aber unterhalb von Routing und fwmark an: `IPAddressDeny` (cgroup-eBPF auf Zieladresse, wirkt unabhängig vom Routing), `RestrictNetworkInterfaces` (der Socket ist bei Policy-Routing nicht an `wg0` gebunden, er wird dorthin geroutet) und `PrivateNetwork`. Alle drei müssen für den konfinierten Dienst aus sein. Bleibt es danach kaputt: Quelladressen-Selektion (`ip route replace default dev wg0 src <wg-addr> table N`), dann `rp_filter = 2`, dann MSS-Clamping.

**Der größte Einzelgewinn ist kein Härtungsschritt, sondern ein `nixosTest`**, der pro Dienst prüft, ob er auf dem Registry-Port lauscht — und nur dort. Die häufigste Fehlklasse in solchen Stacks (Konfiguration sagt `127.0.0.1:5510`, App lauscht auf `0.0.0.0:8096`) ist statisch unsichtbar. Ergänzend `SocketBindDeny = ["any"]` + `SocketBindAllow`: damit ist der Bind kein Wunsch mehr, sondern erzwungen, und die App scheitert laut statt still falsch zu laufen.

> File: [/mnt/user-data/outputs/mediNix-Architektur-Empfehlung.md](https://claude.ai/api/organizations/1bf68e4d-4589-4229-97d3-b02ff6d570ca/conversations/7036d919-266d-4721-9010-658151f83d1a/wiggle/download-file?path=%2Fmnt%2Fuser-data%2Foutputs%2FmediNix-Architektur-Empfehlung.md)

## User:

> 8/22/2026 13:39:37

> File: 

Wie bewertest du diese überlegungen?

## Assistant:

> 8/22/2026 13:41:57

> Korrigierte syscall-Gruppen und verifizierte NixOS-Konfigurationsannahmen gründlich.
>
> - Analysierte technische Architektur und deckte mehrere Sicherheitslücken auf.
> - Check NixOS userns options
> - Check nixos userns assertion and systemd @system-service set
> - Korrigierte syscall-Gruppen und verifizierte NixOS-Konfigurationsannahmen gründlich.
> - **Done**

Solide Arbeit — die Einstufungen sind zu ~80 % richtig, und an einer wichtigen Stelle ist das Papier **besser als meine eigene Empfehlung**. Es hat aber vier handfeste technische Fehler und drei strukturelle Lücken.

## Wo es recht hat — und ich falsch lag

**`@resources` bei .NET nicht denyen.** Das ist der wichtigste Punkt im ganzen Papier, und ich habe ihn in meiner Baseline falsch gehabt. Ich hatte `SystemCallFilter = [ "@system-service" "~@resources" ]` empfohlen. Nachgesehen in `src/shared/seccomp-util.c`: `@system-service` **enthält** `@resources`. Der Deny würde also aktiv `sched_setaffinity`, `setpriority`, `ioprio_set`, `mbind`, `set_mempolicy` entfernen — genau das, was der .NET-Threadpool und die GC beim Start anfassen. Streich das `~@resources` aus meiner Liste.

Gleiche Quelle, umgekehrtes Ergebnis für ihre eigenen Deny-Listen: `@privileged`, `@mount`, `@raw-io`, `@obsolete`, `@clock`, `@cpu-emulation`, `@debug` sind in `@system-service` **gar nicht drin**. Das `~@raw-io` für SABnzbd und die „optionale Verschärfung" `~@clock`/`~@cpu-emulation`/`~@debug` sind No-Ops. Von der ganzen Spalte beißt nur `~@keyring` (das ist tatsächlich enthalten). Als Selbstdokumentation okay, als Härtungsgewinn verbucht: nein.

Ebenfalls gut: die Regel „was den Dienst nachweislich bricht, gehört nicht in den Kern-Default", und der Nicht-Ziel-Eintrag „Perfect-Dendritic-Umstrukturierung bevor Boundary und Härtungs-Factory stehen". Das ist richtige Priorisierung.

## Vier konkrete Fehler

**1. `kernel.unprivileged_userns_clone` ist auf NixOS der falsche Knopf.** Das ist ein Debian/Arch-Downstream-Patch, kein Upstream-Sysctl. Der kanonische Weg ist `security.allowUserNamespaces = false`, was `user.max_user_namespaces = 0` setzt. nixpkgs liefert dazu selbst die Assertion mit: `nix.settings.sandbox = true` konfligiert damit. Das bestätigt eure gemeinsame Schlussfolgerung („nicht in den Kern"), aber der Knopfname im Papier würde auf einem Standard-NixOS-Kernel schlicht ins Leere laufen.

**2. Caddy-Capabilities: die Kombination funktioniert nicht.** Die Tabelle sagt `CapabilityBoundingSet = CAP_NET_BIND_SERVICE`, `AmbientCapabilities = leer`. Der Bounding Set *begrenzt* nur, er *verleiht* nicht. Ein Dienst mit `User=caddy` und leerem Ambient Set hat die Capability nicht und bindet `:443` nicht. Du brauchst `AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ]` **plus** denselben Eintrag im Bounding Set. `setcap` als Alternative scheidet aus — Nix-Store-Pfade tragen keine File-Caps.

**3. „rp_filter-Feintuning pro Interface" reicht nicht.** Der Kernel benutzt `max(conf/all/rp_filter, conf/<iface>/rp_filter)`. Solange `all.rp_filter = 1` steht, ist `wg0.rp_filter = 2` wirkungslos. Wer loosen will, muss `all` mit absenken. Bei eurem aktuellen Debug-Fall ist das genau die Falle, in die man zweimal tappt.

**4. `mkForce` als dokumentiertes Host-Muster ist rückwärts.** Wenn der Host `mkForce` braucht, um einen Wert zu setzen, hat der Kern ihn mit Normal-Priorität definiert — das ist der eigentliche Bug. Richtige Disziplin: Kern nutzt `mkDefault` für alles Übersteuerbare, Host schreibt dann einfache Werte. `mkForce` bleibt Notnagel. Verwandt: `medinix.vpn.interface` mit Default `"wg0"` ist eine Aussage über die Maschine. Sicherheitsrelevante Host-Fakten gehören auf `nullOr str`/`null` mit Assertion; das `"wg0"` setzt das Standalone-**Profil**, nicht der Kern.

## Drei strukturelle Lücken

**Die Boundary ist inhaltlich beschrieben, nicht mechanisch abgesichert.** Die Tabelle listet *Inhaltskategorien* („keine Interface-Namen"). Was fehlt, ist die Arity-Regel: additiv mit eigenem Schlüssel erlaubt, Singleton verboten. Ohne die verhindert nichts, dass der Kill-Switch `networking.nftables.enable = true` setzt — kein hardcodierter Interface-Name, trotzdem Übernahme des Firewall-Backends des ganzen Hosts.

**Host-only-Wissen bekommt kein Artefakt.** Sachen wie das rp_filter-Problem landen in der Kategorie „host-only" — und damit nirgends. Jeder Fremdnutzer debuggt es neu. Genau dafür ist `medinix.recommended.sysctl` als `readOnly`-Ausgabe da: der Kern *veröffentlicht*, der Host *wendet an*, in einer Zeile.

**Nirgends steht, wie man beweist, dass es stimmt.** Fünf Schritte in D, kein einziger Verifikationsschritt. Bei einem Stand von „fail-closed live bewiesen, VPN-oben kaputt" ist der fehlende Pfeiler kein weiterer Kernel-Knopf, sondern ein `nixosTest` mit zweitem Knoten als WireGuard-Peer, der beide Richtungen zu Regressionstests macht.

Dazu zwei kleinere Auslassungen: `IPAddressDeny` und `RestrictNetworkInterfaces` kommen im Papier überhaupt nicht vor. „Kein `PrivateNetwork` für SABnzbd" ist richtig, aber die beiden anderen sind die wahrscheinlicheren Verdächtigen für den kaputten VPN-oben-Pfad — sie sind cgroup-BPF und damit beim Routing-Debugging unsichtbar. Und die „mkHardened-Factory" braucht die Unterscheidung eigene Unit vs. Upstream-Modul, sonst zerlegt sie sich an `mergeEqualOption`, sobald sie ein Profil in `services.sabnzbd` mergt.

## Fazit

Die Kernaussage am Ende („die größte Lücke ist nicht mehr Kernel-Knöpfe, sondern die Boundary plus eine .NET-taugliche Härtungs-Factory") teile ich vollständig. Ich würde ergänzen: **plus ein Test, der beweist, dass die Härtung den Dienst nicht zerlegt hat.** Nimm die Seccomp-Tabelle aus dem Papier (mit der `@resources`-Korrektur, gegen meine Version), nimm die Arity-Regel und den Publish-Mechanismus aus meiner, und korrigiere die vier Punkte oben.

## User:

> 8/22/2026 13:56:44

> File: 

Wie bewertest du diese überlegungen?

## Assistant:

> 8/22/2026 13:58:19

> Durchforstete Architektur-Schwächen und deckte kritische Testlücken auf.
>
> - Durchforstete Architektur-Schwächen und deckte kritische Testlücken auf.
> - **Done**

Die Richtungsaussage stimmt, und die Einordnung „nicht mehr *welche Härtung*, sondern selbsttragender getesteter Kern" ist richtig. Nur: das Dokument ist zu ~80 % Restatement dessen, was schon auf dem Tisch lag. Das einzige wirklich neue, tragende Element ist die **VM-/Appliance-Metapher** — und genau die hält der Prüfung am wenigsten stand.

## Die Metapher trägt nicht, und das hat Folgen

Eine VM hat eine Grenze, die vom Hypervisor *durchgesetzt* wird. mediNix hat keine — es ist ein Satz Optionen, der in den einen globalen Modulbaum des Hosts gemergt wird. Drei konkrete Konsequenzen, die das Dokument nicht zieht:

**Die Grenze ist einseitig.** Eine VM schützt auch *vor* dem Host. Ein Modul nicht. Der Host kann nicht nur `mkForce`, er kann mediNix' Invarianten still kippen, ohne mediNix überhaupt anzufassen: `boot.kernel.sysctl."net.ipv4.conf.all.rp_filter" = 1` in einem ganz anderen Host-Modul killt den VPN-oben-Pfad. Ein zweiter nftables-Table mit `policy drop` in der Output-Chain killt den Ingress. `services.fail2ban.enable` bringt eine eigene Tabelle mit.

Daraus folgt der Mechanismus, der in der Liste fehlt: **publish-don't-apply braucht eine zweite Hälfte — Umgebungs-Assertions.** Der Kern setzt Singletons nicht, aber er *liest* sie und verweigert den Build, wenn der Host seine Annahmen verletzt:

```nix
{ assertion = killswitchActive -> config.networking.nftables.enable; … }
{ assertion = killswitchActive -> (config.boot.kernel.sysctl."net.ipv4.conf.all.rp_filter" or 0) != 1; … }
{ assertion = hostIntegration.reverseProxy == "external" -> config.services.caddy.enable; … }
{ assertion = lib.all (p: !(lib.elem p config.networking.firewall.allowedTCPPorts)) medinixPorts; … }
```

Ohne das ist `external` eine unüberprüfte Hoffnung. Mit dem gilt: der Kern schreibt nichts Globales, merkt aber, wenn das Globale nicht passt. Das ist so nah an einer Hypervisor-Grenze, wie ein NixOS-Modul kommt.

**„Entschieden" ist nicht „wirksam".** Die Statustabelle hakt Identity als fertig ab. Aber Port=UID×10 ist eine Behauptung in einer Registry, bis ein Test zeigt, dass die Unit als existierender User läuft und die App wirklich auf diesem Port lauscht. Genau diese Lücke macht eine VM unmöglich — dort *ist* der Port der Port. Die Metapher lädt dazu ein, deklarierte Identität für effektive zu halten. Das ist der teuerste Denkfehler in dem Papier.

## Layering-Fehler in der Zwiebel

Der Kill-Switch steht ganz innen, neben der App. Zwei Zeilen darüber steht nftables ganz außen. Der Kill-Switch **ist** nftables. Er hängt an einem host-eigenen Singleton (`networking.nftables.enable`) und kann deshalb keine innere, selbsttragende Schale sein. Ehrlicher: UID-Vergabe ist innen (Core), Regelerzeugung ist Core-als-Daten, Regel-*Laden* ist außen (Host). Wer ihn innen zeichnet, implementiert ihn innen — und setzt am Ende wieder `nftables.enable` im Kern.

## Der Tri-State ist nicht symmetrisch

„external → nur vHosts anhängen / managed → `services.caddy.enable`" behandelt den Wechsel als kostenlos. Ist er nicht:

- `managed` ist **exklusiv**: sobald mediNix `services.caddy` besitzt, streitet der Host um dieselben Skalare (`globalConfig`, `package`, `dataDir`, ACME-`email`). Braucht eine Assertion, dass der Host keine eigenen `virtualHosts` definiert hat.
- Der Wechsel `managed → external` hinterlässt Zustand: `/var/lib/caddy`, ACME-Zertifikate mit der Gruppe des alten Owners, Unit-Namen in `reloadServices`. Eine Appliance, die man umschaltet und die dann Zertifikate nicht mehr lesen kann, ist nicht kugelrund.

Für jede Tri-State-Ressource muss dokumentiert sein, was einen Moduswechsel überlebt. Ein Satz pro Ressource, sonst bricht es beim ersten Umschalten.

## Reihenfolge: zwei Tausche

**Test vor Factory, nicht danach.** Der `nixosTest` steht auf 4, die Härtungs-Factory auf 3. Genau umgekehrt. Die Factory ist der riskanteste Schritt der Liste, und der Test ist das einzige, was das Risiko wegnimmt. Kostet nichts, den Tausch zu machen.

**VPN-oben vor der Factory.** Steht auf 5. Das Entfernen von `IPAddressDeny` und `RestrictNetworkInterfaces` plus `rp_filter` auf `all` ist ein Drei-Zeilen-Eingriff und hängt an keiner Factory. Wenn du zuerst die Factory umbaust, debuggst du danach ein bewegtes Ziel — und zwar an exakt den Direktiven, die die Factory neu setzt. Erst reparieren, dann hat man beim Factory-Umbau einen funktionierenden Pfad als Regressionsanker.

## Was in der Lückenliste fehlt

**Atomarität über `nixos-rebuild switch`.** Eine Appliance startet und stoppt als Einheit. Ein Modulsatz nicht: beim Switch werden Units in Abhängigkeitsreihenfolge neu gestartet, nftables lädt neu, wg kann kurz wegbrechen. Die Fail-closed-Eigenschaft muss *über* den Switch halten, nicht nur im eingeschwungenen Zustand. Das ist testbar — Switch mitten im `nixosTest` — und es ist die Sorte Loch, die man erst im Produktivbetrieb findet.

## Fazit

Die Frage „weicht das ab?" beantwortet das Papier richtig mit Nein. Es gibt aber eine echte Spannung, die es unter den Teppich kehrt: bei Ressourcen, deren `external`-Zustand am Eval nicht prüfbar ist (hat die Host-Firewall wirklich eine Accept-Output-Chain? terminiert der Host-Caddy wirklich TLS?), ist der Tri-State keine Lösung, sondern eine Vertagung. Dafür brauchst du eine vierte Kategorie neben assert: eine laufzeitseitige Selbstprüfung, die nach dem Boot meldet, wenn die Umgebung nicht das tut, was `external` versprochen hat.

Nimm aus dem Papier die Reihenfolge (mit den zwei Tauschen), die Verwässerungswarnung und die Zwiebel (mit korrigiertem Kill-Switch-Layer). Streich die VM-Metapher als Leitbild und ersetz sie durch die präzisere Formulierung: **selbstbeschreibend und additiv komponierbar, mit Umgebungs-Assertions als Ersatz für die fehlende Hypervisor-Grenze.** Das ist weniger griffig und führt zu besseren Entscheidungen.

## User:

> 8/22/2026 14:17:03

Du bist Senior-NixOS-Architekt. Arbeite streng, KISS, ohne Marketing, ohne Container-/VM-Metaphern.

## Zielbild (verbindlich)

mediNix ist ein **nativer NixOS-Media-Stack** (portabler Flake, Domäne 5):

- deklarativ, git-versioniert, flake-gepinnt
- nutzt NixOS-Stärken (eine Auswertung, atomare Switchs, Rollback, Reproduzierbarkeit)
- vermeidet typische Nix-Nachteile (Doppel-Abstraktionen, versteckte Host-Annahmen, Overengineering)
- **kein** eigener Kernel, **kein** Docker, **kein** netns-pro-Dienst, **keine** Isolation *vom* Host
- Isolation nur *zwischen* den Programmen: feste UIDs, getrennte State-Dirs, bewusste shared media-GID, systemd-Härtung, SocketBindDeny, Egress-Klassen
- Host ist bekannt und vertraut → Core ist additiv komponierbar und selbstbeschreibend
- Caddy macht nur TLS + reverse_proxy; nftables, fail2ban/crowdsec, kernel-sysctl bleiben eigene Schalen

Bereits entschieden (nicht neu verhandeln):
- Port = UID = Nummer × 10 (SABnzbd = 5410)
- GID 5000 + setgid 2775 + UMask=0002
- Kill-Switch nur SABnzbd: nftables skuid + Policy-Routing + fail-closed Drop
- netns/eBPF für den Kill-Switch verworfen
- .NET-Arrs: kein MemoryDenyWriteExecute, kein \~@resources im SystemCallFilter
- Namespace: medinix

Offen / unvollständig:
- VPN-oben-Pfad noch kaputt (Verdacht: IPAddressDeny / RestrictNetworkInterfaces / PrivateNetwork und/oder rp_filter/all + src)
- Identity und Binds sind deklariert, aber nicht durch Tests als wirksam bewiesen
- Flake/Host-Boundary ohne durchgängige Umgebungs-Assertions
- keine Härtungs-Factory, kein nixosTest-Gate
- Tri-State (external|managed|off) für Caddy etc. noch nicht implementiert

## Harte Leitplanken

1. Core schreibt **keine** Host-Singletons (`networking.nftables.enable`, `boot.kernel.sysctl.*`, `services.caddy.enable` nur hinter explizitem managed).
2. Core **veröffentlicht** Empfehlungen als Daten (`medinix.recommended.*`, readOnly); Host wendet an.
3. Core **assertet** die Umgebung (zweite Hälfte der Grenze): z.B. Kill-Switch aktiv → nftables an, rp_filter nicht streng 1, external-Caddy → services.caddy.enable, App-Ports nicht in allowedTCPPorts.
4. KISS: lieber wenige native Mechanismen richtig als viele Schichten.
5. Test vor großer Factory; VPN-oben-Fix bevor Härtungsprofile umgebaut werden.

## Auftrag

Liefere eine geschärfte, umsetzbare Empfehlung mit genau diesen Teilen:

### A. Zielbild in einem Absatz
Formuliere mediNix-Core ohne VM/Container-Metapher: selbstbeschreibend, additiv, NixOS-zentriert, Programme gegeneinander abgesichert.

### B. Was „wenig externe Abhängigkeiten“ konkret heißt
- Was gehört zwingend in den Core (inkl. soweit sinnvoll App-Config)?
- Was bleibt Host-Fakt?
- Wie greift flake.lock als Untergrenze?

### C. Boundary-Mechanik (kurz, scharf)
- Arity-Regel (additiv eigener Schlüssel vs. Singleton)
- publish-don't-apply
- Umgebungs-Assertions (mind. 5 konkrete, für diesen Stack)
- Tri-State nur wo nötig + Hinweis auf Wechsel-Kosten (Zertifikate, state)

### D. Programm-gegen-Programm-Absicherung (statt Host-Isolation)
Minimale native Mittel-Liste:
UID/GID/StateDirectoryMode, Protect*-Baseline (.NET-tauglich), SocketBindDeny, Egress-Klasse, shared media nur bewusst.
Kein netns, kein PrivateNetwork für SABnzbd.

### E. Reihenfolge (max. 6 Schritte)
KISS, Test vor Factory, VPN-oben früh, bestehende Identity/Kill-Switch-Arbeit nicht zerlegen.

### F. Nicht-Ziele
Was für diesen Stack Overengineering wäre.

## Format
- Kurze Aussagen, Tabellen wo sinnvoll
- Keine Wiederholung der schon finalen Identity-/Kill-Switch-Entscheidungen
- Unsicherheiten als [Annahme] markieren
- Am Ende: 1 Satz „Nächster konkreter Schritt“

Ziel: mediNix soll ein klarer, nativer, gut abgesicherter NixOS-Stack sein — nicht eine Mini-VM und nicht ein Haufen Container.

## Assistant:

> 8/22/2026 14:20:29

> Strukturierte Architektur-Entscheidungen und Testsequenz für nativen NixOS-Stack.
>
> - Strukturierte Architektur-Entscheidungen und Testsequenz für nativen NixOS-Stack.
> - Sharpened mediNix core architecture spec: boundary, app-config scope, program isolation, order
> - Presenting file(s)...
> - **Done**

Vier Punkte, die ich gegenüber den bisherigen Runden verschoben habe:

**„Wenig externe Abhängigkeiten" ist bei App-Config eine Frage der Auslese-Zeit, nicht des Ortes.** Drei Stufen: was die App bei jedem Start neu liest (Env/CLI) gehört vollständig in den Core; was sie aus einer Datei liest und zurückschreibt, braucht genau *einen* Eigentümer — Nix-generiert **und** app-beschreibbar zerstört die Rollback-Eigenschaft; was in einer SQLite-DB liegt (Arr-Indexer, Jellyfin-Bibliotheken), gehört per Default nicht in den Core, sondern in ein Bootstrap-only-Opt-in.

**`flake.lock` als Untergrenze hat eine Konsequenz, die man leicht übersieht:** App-Auto-Updater gehören aus, und zwar im Core. Nix hat die Version gepinnt, der Selbst-Updater hebt genau diesen Pin auf. Das ist keine Geschmacksfrage, sondern folgt direkt aus dem Lock — und begründet, warum diese eine App-Einstellung Core-Config ist.

**Der Kill-Switch ist keine innere Schale.** Er hängt an `networking.nftables.enable`, einem Host-Singleton. UID-Vergabe ist Core, Regelerzeugung ist Core-als-Daten, Regel-*Laden* ist Host. Das ist der Grund, warum Assertion 1 und 2 in C.3 stehen müssen.

**Assertion 2 verdient besondere Aufmerksamkeit:** Der Kernel nutzt `max(conf/all/rp_filter, conf/<iface>/rp_filter)`. Solange `all` auf 1 steht, ist jede Per-Interface-Ausnahme wirkungslos. Wenn das dein aktueller Debug-Fall ist, macht diese eine Assertion ihn dauerhaft unmöglich.

Bei Schritt 1 in der Reihenfolge steckt eine Annahme drin, die du prüfen musst: Ich gehe davon aus, dass mindestens eine der drei Direktiven noch im SABnzbd-Profil steht. Falls nicht, ist die Reihenfolge trotzdem richtig — dann geht es direkt zu `src` in der Policy-Route und `rp_filter` auf `all`.

> File: [/mnt/user-data/outputs/mediNix-Core-Empfehlung.md](https://claude.ai/api/organizations/1bf68e4d-4589-4229-97d3-b02ff6d570ca/conversations/7036d919-266d-4721-9010-658151f83d1a/wiggle/download-file?path=%2Fmnt%2Fuser-data%2Foutputs%2FmediNix-Core-Empfehlung.md)

## User:

> 8/22/2026 14:32:43

> File: 

Kannst du das weoter ausarbeiten? Bzwm auf den punkt bri gen und präzisieren? 
---

## Assistant:

> 8/22/2026 14:36:06

> Systematisierte Checklisten-Kategorien mit automatisierten Tests und präzisen Kriterien.
>
> - Systematisierte Checklisten-Kategorien mit automatisierten Tests und präzisen Kriterien.
> - Sharpened, mechanically decidable mediNix review checklist
> - Presenting file(s)...
> - **Done**

Vier Änderungen gegenüber deiner Fassung, und eine davon ist die eigentliche Schärfung:

**Jeder Punkt bekommt eine Kategorie: [A] Assertion, [T] Test, [M] manuell.** Eine Checkbox, die eine Assertion sein könnte, ist technische Schuld — sie wird einmal abgehakt und danach nie wieder geprüft. Etwa die Hälfte deiner Punkte gehört nach [A] und verschwindet danach aus der Liste. Ziel des Reviews ist nicht, alle Haken zu setzen, sondern die [M]-Spalte kurz zu bekommen.

**Es fehlte eine ganze Klasse: Eval-Breaker.** Deine Liste beginnt bei Architektur, aber der teuerste Fehlertyp liegt darunter — doppelte Attributpfade, undefinierte `let`-Bezeichner, `cfg`-Scope-Verwechslung, `lib.mkIf` als Listenelement, Nix-Escapes in Unit-Namen. Das ist mit drei Kommandos vollständig erschlagen, und `nix-instantiate --parse` fängt dabei mehr als man denkt: doppelte Attributpfade wirft Nix bereits beim Parsen, nicht erst beim Evaluieren.

**Weichmacher raus.** „Wo sinnvoll", „soweit der Dienst es verträgt" machen einen Punkt unprüfbar. Jede Vorgabe ist jetzt Default plus namentliche Ausnahmeliste. Bei `RestrictNamespaces` und `SocketBindDeny` ist die Ausnahmeliste leer bzw. einelementig — das lässt sich prüfen, „soweit verträglich" nicht.

**Neu: Guardrail-Review (4.3).** Der teuerste Fehler ist nicht die fehlende Assertion, sondern die, die grün meldet, ohne zu prüfen — eine Tautologie, ein Vergleich gegen einen Wert, den das Enum gar nicht kennt. Deshalb: pro Assertion ein Negativtest, der sie zum Feuern bringen muss.

Zwei Präzisierungen an Einzelpunkten: Bei 1.3 ist für eine Unit `serviceConfig.SupplementaryGroups` das Wirksame, nicht `users.users.<n>.extraGroups` — deine Liste hat das vermischt. Und bei 2.3 habe ich einen Punkt ergänzt, den ich in ähnlichem Code schon gesehen habe: wenn die Factory `{ systemd.services.<n>; users.users.<n>; }` liefert und der Aufrufer nur `.systemd.services.<n>` selektiert, verschwindet der User lautlos, und die Unit läuft gegen einen Account, den es nicht gibt.

> File: [/mnt/user-data/outputs/mediNix-Review-Checkliste.md](https://claude.ai/api/organizations/1bf68e4d-4589-4229-97d3-b02ff6d570ca/conversations/7036d919-266d-4721-9010-658151f83d1a/wiggle/download-file?path=%2Fmnt%2Fuser-data%2Foutputs%2FmediNix-Review-Checkliste.md)

## User:

> 8/22/2026 14:47:21

> File: 

Was hälst du davon?

## Assistant:

> 8/22/2026 14:49:11

> Analysierte Dokumentation und deckte interne Widersprüche auf.
>
> - Analysierte Dokumentation und deckte interne Widersprüche auf.
> - **Done**

Mechanisch ist das Dokument korrekt, und die Schlussempfehlung — nicht flächendeckend, für die Arrs `SocketBindDeny` statt Activation — teile ich. Es hat aber einen Selbstwiderspruch, unterschätzt den einen Fall, in dem sich Activation für euch wirklich lohnt, und lässt zwei Fallen aus, die ihr garantiert treten würdet.

## Der Widerspruch

Abschnitt 2 zeigt Jellyfin als Musterbeispiel für „Unix-Socket + Caddy". Abschnitt 3 zählt Jellyfin unter den „klassischen bind-selbst-Diensten" auf, für die Activation nicht funktioniert. Beides steht zwei Bildschirme auseinander.

Das ist nicht nur kosmetisch: Wenn du eine `jellyfin.socket` anlegst, die Jellyfin nicht bedient, entsteht die schlimmste Variante — systemd akzeptiert die Verbindung, startet den Dienst, übergibt den FD, Jellyfin ignoriert ihn und bindet stattdessen seinen eigenen Port. Caddy hängt an einem Socket, an dem niemand liest. Kein Fehler, kein Log, nur Timeouts. Nimm für das Unix-Socket-Beispiel einen Dienst, für den es belegt ist, oder markiere es explizit als „nur wenn die App es kann".

## Was das Dokument untergewichtet

**Unix-Sockets lösen euer flaches-Loopback-Problem.** Das ist der eigentliche Gewinn und kommt im Text gar nicht vor. Aktuell erreicht jede UID jeden Loopback-Port — deshalb die offene Frage, ob ein konfinierter Dienst über einen anderen Loopback-Dienst mit Fetch-Primitiv ins WAN relayen kann. Bei TCP brauchst du dafür `skuid` + `dport` in der Output-Chain. Bei Unix-Sockets erledigen es Dateirechte: Mode `0660`, Owner Dienst-User, Gruppe = Proxy-Gruppe. SABnzbds UID kann Prowlarrs Socket dann schlicht nicht öffnen. Das ist KISS-konform und braucht keine einzige zusätzliche nft-Regel — deutlich besser als das, was ich dir vorher als Lösung skizziert hatte.

**`SocketBindDeny` wird bei Activation stärker, nicht schwächer.** Die Tabelle in Abschnitt 4 stellt es als Einschränkung dar („Deny betrifft den Service-Prozess"). Genau das ist der Vorteil: der Bind passiert in systemds Cgroup, nicht in der des Dienstes. Bei echter Activation kannst du also `SocketBindDeny = [ "any" ]` **ohne jedes `SocketBindAllow`** setzen — der Dienst kann dann überhaupt keinen Listening-Socket mehr öffnen. Das ist strikt stärker als eine Portfreigabe.

**Der eine Fall, wo es sich für euch klar lohnt, fehlt: Caddy auf :80/:443.** Ihr hattet genau dort den Konflikt zwischen `PrivateUsers` und `AmbientCapabilities=CAP_NET_BIND_SERVICE`. Mit einer Socket-Unit bindet systemd als root, und Caddy läuft mit leerem Bounding- *und* Ambient-Set. Die Capability verschwindet aus der Unit statt sorgfältig konfiguriert zu werden. Abschnitt 5 Pattern D deutet das an, sagt aber nicht, dass es die Capability *ersetzt*.

[Zu verifizieren] Caddy unterstützt seit ~2.8 `bind fd/N` bzw. `fd@name` zusammen mit `FileDescriptorName=` in der Socket-Unit — das müsstest du am gepinnten Rev gegenprüfen, bevor du darauf baust. Die KISS-Alternative ohne Activation wäre `net.ipv4.ip_unprivileged_port_start = 0`, was als Host-Singleton sauber in `recommended.sysctl` passt.

## Zwei fehlende Fallen

**`RuntimeDirectory` am falschen Unit.** Abschnitt 4 sagt, Socket-Pfade über `RuntimeDirectory` zu steuern — aber die Socket-Unit bindet, *bevor* der Service startet. Steht `RuntimeDirectory` am Service, existiert `/run/medinix` beim Bind noch nicht, und beim Stoppen des Services wird das Verzeichnis samt Socket-Datei gelöscht, während die Socket-Unit weiter lauscht. `RuntimeDirectory` gehört an die Socket-Unit, oder du nimmst `tmpfiles` plus `RuntimeDirectoryPreserve = "yes"`.

**Socket-Unit plus `wantedBy = [ "multi-user.target" ]` am Service.** Das ist der praktische Klassiker: die Socket-Unit hält den Port, der Service startet beim Boot ohnehin und bindet selbst — `EADDRINUSE`. Abschnitt 7 nennt „Port-Konflikt" als Symptom, aber nicht diese Ursache. Wer Activation will, muss `wantedBy` am Service entfernen. Wer `wantedBy` behält, braucht keine Socket-Unit.

## Ein Detail beim Kill-Switch, das halb stimmt

„Activation ändert die UID-Zuordnung nicht" gilt für `Accept=no`. Bei `Accept=yes` nicht: `sk_uid` wird bei der Socket-Erzeugung aus den Credentials des erzeugenden Prozesses gesetzt. Ein von systemd (root) erzeugter und per FD übergebener Verbindungs-Socket trägt `skuid 0` — auch wenn der Worker unter 5410 läuft. `meta skuid 5410` greift dann nicht, das Paket wird nicht markiert und geht über die Main-Tabelle raus.

Praktisch trifft euch das nicht, weil `Accept=yes` hier nirgends passt. Aber es ist ein guter Grund, es als harte Regel zu formulieren: **für den konfinierten Dienst keine Socket-Activation, in keiner Variante.** Ein Mechanismus, dessen Zusammenspiel mit `skuid` von einem Unit-Flag abhängt, hat in einem fail-closed-Pfad nichts zu suchen.

## Boundary-Anmerkung

`SocketGroup = "caddy"` ist bei `hostIntegration.reverseProxy = external` ein Host-Fakt — genau dasselbe Problem wie die ACME-Zertifikatsgruppe. Der Wert muss aus der effektiv laufenden Proxy-Unit abgeleitet werden, nicht literal stehen, sonst kann der Proxy den Socket nach einem Moduswechsel nicht mehr öffnen.

## Fazit

Die Empfehlung stimmt, die Begründung ist zu schwach. Ich würde sie so zuspitzen:

| Einsatz | Urteil |
|---|---|
| Arrs, SABnzbd, Jellyfin: TCP-Activation | **Nein** — kein sauberer `sd_listen_fds`-Pfad, `SocketBindDeny/Allow` reicht |
| Konfinierter Dienst (SABnzbd): Activation jeder Art | **Nein, hart** — `skuid`-Semantik hängt sonst an einem Unit-Flag |
| Caddy `:80`/`:443` | **Prüfen** — ersetzt `CAP_NET_BIND_SERVICE` vollständig; Alternative `ip_unprivileged_port_start` via `recommended.sysctl` |
| Unix-Socket Caddy ↔ Backend, wo die App Unix kann | **Ja** — löst nebenbei das flache Loopback-Problem über Dateirechte statt über nft |

Der noch nicht genannte Nebeneffekt: Socket-Units überleben Service-Restarts. Verbindungen werden während eines `nixos-rebuild switch` gequeued statt abgelehnt — das zahlt direkt auf euren „Invariante hält über switch"-Test ein.

## User:

> 8/22/2026 18:11:38

> File: 

> File: 

**East-West bei euch = Verkehr *zwischen* den Diensten auf demselben Host**

Nicht Internet↔Stack (North-South), sondern z.B. SABnzbd → Prowlarr, Sonarr → SABnzbd, Jellyfin → nichts Externes über einen anderen lokalen Dienst.

---

### Das konkrete Problem bei mediNix

Aktuell typisch:

```text
Alle Backends auf 127.0.0.1:<Port>
nft/firewall: Loopback oft pauschal erlaubt
→ Jede UID kann jeden lokalen Port ansprechen
```

Dann gilt:

- Kill-Switch sperrt **WAN-Egress** von UID 5410  
- UID 5410 kann trotzdem `127.0.0.1:5310` (Prowlarr) o.Ä. nutzen  
- Bietet dieser Dienst ein Fetch/Proxy-Primitiv → **Relay am Tunnel vorbei** (East-West-Umgehung)

Das ist die „flache Loopback“-Lücke aus den Reviews — bewusst dokumentiert, noch nicht gebaut.

---

### Was East-West-Segmentierung hier heißen soll (KISS)

Nicht: VLANs, mehrere Netns, Service-Mesh.  
Sondern: **Wer darf wen auf Loopback (oder Unix-Socket) erreichen?**

| Quelle | Ziel | Soll |
|--------|------|------|
| Caddy | Arrs, Jellyfin, SABnzbd UI, … | erlaubt (Ingress) |
| Sonarr/Radarr | SABnzbd, Prowlarr | erlaubt (Stack-intern nötig) |
| SABnzbd (5410) | nur was er wirklich braucht (oft wenig) | eng |
| Jellyfin | meist keine Arr-APIs | oft nichts |
| SABnzbd | „irgendein“ lokaler Dienst mit Outbound | **nein** |

---

### Drei gangbare Mittel (nativ)

**1. nftables `skuid` + `dport` (TCP Loopback)**

```nft
# Pseudologik Output-Chain
meta skuid 5410 ip daddr 127.0.0.1 tcp dport { 5310 } accept   # nur wenn wirklich nötig
meta skuid 5410 ip daddr 127.0.0.0/8 drop
# andere UIDs: bestehende Policy
```

- Passt zu eurer skuid-Welt  
- Kein netns  
- Muss in der **gleichen** Denkweise wie der Kill-Switch gepflegt werden (Registry: wer darf welche lokalen Ports)

**2. Unix-Sockets + Dateirechte**

```text
Socket Mode 0660, Owner = Dienst, Group = caddy (oder medinix-proxy)
```

- SABnzbd-UID kann Prowlarr-Socket nicht öffnen, wenn er nicht in der Gruppe ist  
- Löst East-West elegant **ohne** nft — aber nur wo Apps Unix wirklich können  
- Bei euch: Arrs/SABnzbd meist **nicht** → vorerst begrenzt nutzbar

**3. Gar nicht exposen / nicht binden**

- Dienst hat keine API, die andere brauchen → kein Port für sie  
- `SocketBindDeny` ändert East-West allein nicht, begrenzt nur *eigenes* Lauschen

---

### Was ihr **nicht** brauchen solltet

| Ansatz | Warum nicht (jetzt) |
|--------|---------------------|
| netns pro Dienst | Kill-Switch/skuid, Komplexität, schon verworfen |
| Micro-VLANs / mehrere Bridges | Overkill Homelab-Single-Host |
| mTLS zwischen allen Arrs | Wartungsmonster |
| `PrivateNetwork=true` | zerbricht euer Modell |
| Vollmatrix „jeder gegen jeden“ in nft | pflegeintensiv, fehleranfällig |

---

### Einordnung in eure Reihenfolge

East-West ist **echte** Härtung gegen Lateral Movement nach RCE — aber:

1. Erst North-South + Kill-Switch **wirksam** (VPN-oben + fail-closed)  
2. Dann Identity/Bind getestet  
3. **Dann** East-West für die eine kritische UID (SABnzbd), nicht für alle

KISS-Start:

```text
Nur UID 5410:
  Loopback nur zu explizit erlaubten dports
  sonst drop
Rest der Stack-UIDs:
  vorerst flach (oder nur dokumentieren)
```

Später: Registry-Feld `localAllowPorts = [ 5310 ]` o.Ä., Regeln generieren.

---

### Kurz

| Frage | Antwort |
|-------|---------|
| Was ist East-West hier? | Dienst↔Dienst auf dem Host (vor allem Loopback) |
| Hauptloch? | Konfinierte UID nutzt lokalen Helfer als WAN-Relay |
| Bestes Mittel bei euch? | `skuid` + `dport` auf 127.0.0.0/8; Unix-Rechte wo möglich |
| Jetzt bauen? | Nein — nach VPN-oben + Tests; bis dahin dokumentierte Grenze |
| Ziel | Wenige erlaubte Paare, kein volles Mesh |

Wenn du willst, als Nächstes eine **minimale Erlaubtliste** nur für SABnzbd (welche lokalen Ports er wirklich braucht) — als Vorstufe zur Registry, ohne das ganze Netz umzubauen.
---
**Nein — noch nicht.**  
Architektonisch seid ihr **klar und weitgehend durchdacht**. Operativ und beweisbar seid ihr **noch nicht rundum abgesichert**.

### Was steht (Konzept / Entscheidung)

| Bereich | Status |
|--------|--------|
| Identity (Port = UID × 10, GID 5000, setgid/UMask) | entschieden |
| Programm-gegen-Programm (State 0700, shared media bewusst) | modelliert |
| Kill-Switch-Design (skuid + Policy-Routing + Drop) | klar, netns/eBPF verworfen |
| Boundary (additiv, publish-don’t-apply, Umgebungs-Assertions) | klar |
| Härtungs-Baseline (.NET-tauglich) | klar |
| Review-System ([A]/[T]/[M], Stufe 0) | klar |
| Caddy dünn, Rest native NixOS | klar |
| KISS, kein Container/VM-Theater | klar |

Das ist ein **tragfähiges Soll** — kein Flickenteppich mehr.

### Was fehlt für „rundum abgesichert“

| Lücke | Warum es zählt |
|-------|----------------|
| **VPN-oben noch kaputt** | Fail-closed ja, erwünschter Tunnel-Pfad nein → Stack nicht produktionsdicht |
| **Identity/Binds nicht per Test bewiesen** | Registry sagt UID/Port — Prozess und `ss` müssen das bestätigen |
| **Umgebungs-Assertions oft noch nicht im Code** | Sonst bleibt `external` Hoffnung |
| **`no-host-takeover` / `hostile-minimal`** | Grenze ist sonst Behauptung |
| **Härtungs-Factory + SocketBindDeny flächendeckend** | Noch nicht durchgezogen |
| **East-West / Loopback-Relay** | bewusst offen dokumentiert |
| **Secrets-Vertrag** | Bedarf vs. Lieferung noch dünn |
| **Invarianten über `nixos-rebuild switch`** | Fail-closed im Ruhezustand ≠ während des Switchs |

Ohne die ersten Punkte der Liste habt ihr ein **gutes Papier**, kein **nachgewiesenes System**.

### Ehrliche Einordnung

```text
Konzept / Architektur:     ~85–90 %  (stimmig, KISS, NixOS-nativ)
Umsetzung / Code:          deutlich darunter
Empirischer Beweis:        Fail-closed ja, Rest nein
„Rundum abgesichert“:      noch nein
```

„Rundum“ hieße mindestens:

1. VPN-oben **und** fail-closed grün  
2. Pro Kern-Dienst: UID + nur Registry-Port (Test)  
3. Boundary-Checks grün  
4. .NET-Arrs laufen unter der Härtung  
5. `flake.lock` als Untergrenze, Stufe 0 grün  

### Nächster sinnvoller Schnitt (nicht alles auf einmal)

1. VPN-oben fixen (drei Direktiven / `src` / `rp_filter` auf **all**)  
2. Minimales Test-Gate (UID, Bind, ein Arr + SABnzbd)  
3. Umgebungs-Assertions + `no-host-takeover`  
4. Dann Factory / SocketBindDeny flächendeckend  

---

**Kurz:**  
Ihr habt das **richtige Zielbild** und die **richtige Absicherungs-Logik**.  
Ein rundum abgesichertes System ist das erst, wenn die kritischen Pfade **laufen und getestet** sind — nicht wenn die Checkliste nur auf dem Papier steht.
---
**Unterm Strich: Für dich fast nichts Pflicht — und dein Eindruck stimmt.**

Die meisten deiner Apps (Sonarr, Radarr, SABnzbd, Prowlarr, Seerr, …) sind **klassische TCP-Selbstbinder**. Die öffnen den Port selbst. Echte Socket-Activation (`sd_listen_fds`) können sie in der Regel **nicht**. Deshalb:

### Was du davon hast

| Thema | Gewinn für mediNix |
|--------|---------------------|
| TCP-Activation für Arrs/SABnzbd/Jellyfin | **Keiner** — weglassen |
| `SocketBindDeny` + `SocketBindAllow` | **Der eigentliche Gewinn** — Bind wird erzwungen, App darf nur den Registry-Port |
| Socket-Activation für SABnzbd | **Nein, hart** — kann mit `skuid`/Kill-Switch kollidieren |
| Unix-Socket Caddy → Backend | **Nur wo die App Unix wirklich kann** — sonst Timeout-Falle ohne Log |
| Caddy auf :80/:443 per Socket-Unit | **Optional prüfen** — spart CAP_NET_BIND_SERVICE; Alternative: `ip_unprivileged_port_start` auf dem Host |
| Flaches Loopback (UID erreicht jeden 127.0.0.1-Port) | Bleibt vorerst; Unix-Sockets wären eine Lösung, aber nur mit Unix-fähigen Apps |

### Praktische Linie (KISS)

```text
Arrs / SABnzbd / Jellyfin / …
  → kein .socket
  → normaler Service
  → SocketBindDeny = ["any"]
  → SocketBindAllow = nur Registry-Port (TCP)

Caddy
  → bleibt TCP-Proxy (oder später optional Socket für :80/:443)
  → Backends weiter über 127.0.0.1:PORT
  → kein Zwang zu Unix, solange die Apps kein Unix sprechen

Kill-Switch / SABnzbd
  → keinerlei Socket-Activation
```

### Eine Sache, die du nicht brauchst

Du musst **nicht** auf Unix-Sockets oder Activation umstellen, nur weil es „moderner“ klingt.  
Dein Stack ist TCP-loopback + Reverse-Proxy — das ist normal und passt zu NixOS.

Der Review-Text ist vor allem eine **Warnung vor Fehlern**, falls jemand Activation doch einbaut (Jellyfin-Socket ohne App-Support, RuntimeDirectory an der falschen Unit, Accept=yes + skuid, wantedBy + Socket gleichzeitig).

---

**Fazit:**  
Ja — fast alles bei dir ist TCP.  
**Mitnehmen:** `SocketBindDeny/Allow` für die TCP-Dienste.  
**Nicht mitnehmen:** flächendeckende Socket-Activation.  
**Später optional:** Caddy-Privileged-Ports oder Unix nur dort, wo die App es belegt kann.

Damit bleibt ihr KISS und verliert nichts am Kill-Switch oder an der Identity-Architektur.

## Assistant:

> 8/22/2026 18:16:09

> Analysierte Reverse-Path-Filtering, nftables-Mechanik und Socket-Activation-Fallstricke.
>
> - Verifizierend technische Details vor Synthese zusammenführen.
> - Searching available tools: Context7 documentation library
> - Resolve Context7 Library ID
> - Query Documentation
> - Verifizierend, dass SocketBindDeny nur bind() betrifft, nicht connect().
> - Resolve Context7 Library ID
> - Query Documentation
> - Resolve Context7 Library ID
> - Query Documentation
> - Verifizierte Caddy-Dokumentation und wählte zuverlässigere Unix-Socket-Alternative.
> - Check NixOS nftables module at pinned rev
> - Read nftables service definition
> - Analysierte nftables-Konfiguration und Reload-Verhalten auf Sicherheitslücken.
> - Check flushRuleset default and firewall chains
> - Analysierte NixOS-Firewall-Architektur und bestätigte Killswitch-Unabhängigkeit.
> - Inspect rpfilter chain and checkReversePath default
> - Analysierte Reverse-Path-Filtering, nftables-Mechanik und Socket-Activation-Fallstricke.
> - Doc-checked review of protocols, socket activation, east-west and readiness for mediNix-Core
> - Presenting file(s)...
> - **Done**

Der Doku-Check hat zwei Aussagen aus den letzten Runden gekippt — beide meine.

**`SocketBindDeny/Allow` erzwingt nicht die Bind-Adresse.** In `src/bpf/socket-bind.bpf.c` lesen die Match-Funktionen nur Family, Protokoll und Port. Der BPF-Kontext enthält `user_ip4`, aber keine Regel wertet ihn aus. `SocketBindAllow = "ipv4:tcp:5410"` erlaubt also `0.0.0.0:5410` genauso wie `127.0.0.1:5410`. Meine frühere Formulierung („bindet die App auf `0.0.0.0`, bekommt sie `EPERM`") war falsch. Was die Direktive wirklich leistet: Port-Disziplin — die App kann keinen fremden und keinen Zusatzport öffnen. Die Adresse prüfen weiterhin nur Firewall-Default-Deny und der `ss`-Test. Ebenfalls bestätigt: nur `cgroup/bind4`/`bind6` gehookt, also kein Effekt auf `AF_UNIX` und keiner auf `connect()` — das flache Loopback bleibt davon unberührt.

**Der wahrscheinlichere VPN-Bug ist `networking.firewall.checkReversePath`, nicht der Sysctl.** Am gepinnten Rev erzeugt `firewall-nftables.nix` eine eigene Chain:

```nft
chain rpfilter { type filter hook prerouting priority mangle + 10; policy drop;
  fib saddr . mark . iif oif exists accept
```

Default ist `true` = strict (`firewall.nix:208`), und der nftables-Backend setzt `net.ipv4.conf.*.rp_filter` überhaupt nicht. Wer nur am Sysctl dreht, ändert nichts. Der Lookup enthält `mark` — eingehende Pakete tragen aber keinen fwmark, der wird erst im Output-Hook gesetzt. Rückverkehr über `wg0` löst also in der Main-Tabelle auf, `oif` ≠ `iif`, policy drop. Der Handshake kommt durch (Rückroute zum Peer geht über `eth0`), die Nutzlast nicht. Das erklärt „fail-closed bewiesen, VPN-oben kaputt" vollständig, ohne dass am Kill-Switch etwas defekt sein muss.

Zwei kleinere Korrekturen: `route`-Chains laufen laut nftables-Wiki auch in `inet`, die v4/v6-Trennung der Mark-Chain ist also unnötig. Und `nftables.service` hat `reloadIfChanged` plus einen atomaren `nft -f` — die Switch-Invariante ist besser als angenommen; die offene Lücke ist `ExecStop`, das die Tabellen löscht.

Zum East-West-Vorschlag eine Verschärfung: SABnzbd braucht vermutlich gar keinen ausgehenden Loopback-Kontakt, die Arrs rufen ihn auf. Der KISS-Start ist damit keine kurze Allowlist, sondern eine **leere** plus `drop` — und die Zeile kostet nichts, wenn die Kill-Chain für den VPN-Fix ohnehin angefasst wird.

Nicht belegen konnte ich Caddys `bind fd/` — in den abgerufenen Doku-Abschnitten taucht nur `bind unix//…` und `bind <host>` auf. Socket-Activation für Caddy bleibt bis zur Verifikation am Rev unbestätigt.

> File: [/mnt/user-data/outputs/mediNix-Doku-Check-Runde.md](https://claude.ai/api/organizations/1bf68e4d-4589-4229-97d3-b02ff6d570ca/conversations/7036d919-266d-4721-9010-658151f83d1a/wiggle/download-file?path=%2Fmnt%2Fuser-data%2Foutputs%2FmediNix-Doku-Check-Runde.md)

## User:

> 8/22/2026 20:21:26

> File: 

## Assistant:

> 8/22/2026 20:25:35

> Architected VPN kill-switch observability and unified service confinement invariants.
>
> - Refining bind enforcement classification for service testing.
> - Query Documentation
> - Investigated capability namespacing behavior with privileged port binding mechanics.
> - Query Documentation
> - Evaluating undocumented network scheme fallback options.
> - Query Documentation
> - Architected VPN kill-switch observability and unified service confinement invariants.
> - Final architecture decision round for mediNix-Core: decisions, measurement plan, invariants, boundary rules
> - Presenting file(s)...
> - **Done**

Die wichtigste Entscheidung in der Tabelle steht auf Platz 1 und war in deiner Liste offener Punkte gar nicht enthalten: **`counter` an jeder Regel der Kill-Chain**, als dauerhafte Eigenschaft, nicht als Debug-Hilfe. Ohne Zähler lassen sich die drei Ursachenhypothesen, die diese Runden produziert haben, nicht unterscheiden — bleibt der Mark-Counter bei null, ist es cgroup-BPF; zählt er und `accept` zählt mit, liegt das Problem auf dem Rückweg; zählt `drop`, stimmen Mark oder Route nicht. Ein selbstbeschreibender Core muss zur Laufzeit sagen können, welche seiner Regeln greift.

Zwei Entscheidungen fallen dadurch zusammen, was ich vorher getrennt behandelt hatte: **Das pauschale Loopback-Accept für den konfinierten UID entfällt.** Damit ist das East-West-Loch geschlossen *und* der glibc-Fallback auf `127.0.0.1` bei leerer `resolv.conf` wird gedroppt statt am Tunnel vorbeigeleitet. Aus einem Leck wird ein lauter Fehler — eine Änderung, zwei offene Punkte.

Beim rpfilter habe ich meine Empfehlung der letzten Runde verschärft: nicht `checkReversePath = "loose"`, sondern `extraReversePathFilterRules` mit einer `iifname <vpn-if> accept`-Zeile. Die generierte Chain endet auf `jump rpfilter-allow`, und genau dieser Chain-Inhalt kommt aus der Option — das ist die vorgesehene Ausnahmestelle. `"loose"` entfernt `. iif` für alle Interfaces; die gezielte Regel nur für den Tunnel.

Zwei Punkte konnte ich nicht abschließend klären und habe sie entsprechend markiert: Caddys `fd/` taucht in der `conventions`-Doku nicht auf (gelistet sind `tcp`, `tcp6`, `udp`, `unix`) — die Caps-Lösung bleibt, mit `ip_unprivileged_port_start` als sauberer Host-Alternative, weil dieser Sysctl netns-scoped ist und gar keine Capability braucht. Und ob das Reroute die Quelladresse neu wählt, ist Kernel-Verhalten, das ich nicht belegen konnte — deshalb steht `src` auf „nach Messung", mit `ip route get … mark …` als Entscheidungskriterium.

Zur Boundary ist eine Kategorie dazugekommen: `recommended.firewall`. `checkReversePath` ist weder Sysctl noch nft-Tabelle, hängt aber direkt am Kill-Switch. Ohne eigenes Feld lebt dieses Wissen in der Prosa — und die Lehre dieser Runde ist genau, dass ein Fremdnutzer es sonst als „VPN kaputt" neu erlebt.

> File: [/mnt/user-data/outputs/mediNix-Architektur-Abschluss.md](https://claude.ai/api/organizations/1bf68e4d-4589-4229-97d3-b02ff6d570ca/conversations/7036d919-266d-4721-9010-658151f83d1a/wiggle/download-file?path=%2Fmnt%2Fuser-data%2Foutputs%2FmediNix-Architektur-Abschluss.md)

Powered by Claude Exporter (https://www.ai-chat-exporter.net)
