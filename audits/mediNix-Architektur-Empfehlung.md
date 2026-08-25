# mediNix — Architektur-Empfehlung: Flake/Host-Grenze, Kernel-Policy, Fundament-Pfeiler

---

## A. Flake/Host-Trennungsmodell

### A.1 Die Grenze ist keine Options-Grenze, sondern eine Fakten-Grenze

Die übliche Formulierung („Host-spezifisches gehört in den Host") ist zu weich, weil sie sich nicht prüfen lässt. Die harte Regel lautet:

> **Der portable Kern darf keine Aussage über die Maschine treffen, auf der er läuft.**

Konkret: keine Interface-Namen, keine Blockgeräte, keine IP-Bereiche, keine Domainnamen, keine Pfade außerhalb `/var/lib/<unit>` und `/run/<unit>`, keine Annahme über GPU, Netzwerk-Backend (networkd vs. NM), Firewall-Backend, Init-in-initrd, Bootloader oder Dateisystem-Layout.

Alles davon betritt den Kern durch genau eine Tür: `medinix.host.*`, mit Default `null` und einer Assertion, die feuert, sobald ein Feature das braucht, was nicht geliefert wurde.

```nix
options.medinix.host = {
  vpn.interface = mkOption {
    type = types.nullOr types.str; default = null;
    description = ''
      Name des vom Host bereitgestellten WireGuard-Interfaces.
      mediNix legt dieses Interface NICHT an und konfiguriert es nicht.
    '';
  };
  storage.stagingDir  = mkOption { type = types.nullOr types.path; default = null; };
  storage.libraryDir  = mkOption { type = types.nullOr types.path; default = null; };
  render.device       = mkOption { type = types.nullOr types.path; default = null; };
  credentials         = mkOption { type = types.attrsOf types.path; default = {}; };
};
```

Zwei Eigenschaften dieser Tür sind nicht verhandelbar:

1. **`default = null`, niemals ein plausibler Beispielwert.** Ein Default wie `"wg0"` oder `/data/library` ist eine Aussage über die Maschine. Er lässt Fremdnutzer glauben, es sei konfiguriert, und verwandelt einen Konfigurationsfehler in stillen Fehlbetrieb — bei einem Kill-Switch in ein Leck, bei einem Mover in ein vollgeschriebenes Root-Dateisystem.
2. **Die Assertion sitzt am Verbraucher, nicht am Anbieter.** `medinix.services.sabnzbd.enable → medinix.host.vpn.interface != null`. Nicht umgekehrt. Sonst zwingt man Nutzer, die nur Jellyfin wollen, ein VPN zu deklarieren.

### A.2 Additiv schreiben, Singletons nur behaupten

Der Kern schreibt in fremde Option-Namespaces. Das ist unvermeidlich (systemd-Units, User, nft-Tabellen). Entscheidend ist die **Arity** des Ziels:

| Klasse | Beispiele | Regel |
|---|---|---|
| **Additiv, eigener Schlüssel** | `systemd.services.<unsere-unit>`, `users.users.<unsere-uid>`, `networking.nftables.tables.medinix_*`, `systemd.tmpfiles.rules`, `security.acme.certs.<host>` | **Erlaubt.** Kollisionsfrei, weil der Schlüssel uns gehört. Bei Deaktivierung verschwindet der Eintrag restlos. |
| **Singleton, host-eigen** | `networking.nftables.enable`, `networking.firewall.enable`, `boot.kernel.sysctl.*`, `boot.initrd.*`, `boot.kernelParams`, `security.sudo.extraConfig`, `services.caddy.enable`, `hardware.graphics.enable` | **Verboten im Kern.** Stattdessen: Assertion oder Warning. |
| **Additiv, aber fremder Schlüssel** | `services.caddy.virtualHosts.<apex-domain>`, `networking.firewall.allowedTCPPorts` | **Nur hinter explizitem Opt-in.** Der Host kann denselben Schlüssel bereits belegen. |

Der Satz „mediNix ist additiv" ist genau dann wahr, wenn kein Modul in Spalte 2 schreibt. Das ist grep-bar und damit ein Check, kein Vorsatz.

`networking.nftables.enable = true` im Kern ist der prominenteste Fall: es kippt das Firewall-Backend des gesamten Hosts. Auf einer iptables-Maschine ersetzt es stillschweigend deren komplettes Regelwerk. Ein Kill-Switch, der zur Installation die Host-Firewall austauscht, ist kein additives Modul.

### A.3 Publish-don't-apply: das zentrale Muster

Das löst den scheinbaren Widerspruch zwischen „Security gehört in den Kern" und „der Kern darf nichts Globales anfassen". Der Kern **veröffentlicht Empfehlungen als Daten**, der Host **wendet sie an**:

```nix
# Kern — read-only Ausgabe, kein Effekt
options.medinix.recommended = {
  sysctl        = mkOption { type = types.attrsOf types.anything; readOnly = true; };
  nftables      = mkOption { type = types.attrsOf types.anything; readOnly = true; };
  mountOptions  = mkOption { type = types.attrsOf (types.listOf types.str); readOnly = true; };
};

config.medinix.recommended = {
  sysctl = { "kernel.kptr_restrict" = 2; /* ... */ };
  nftables.medinix_egress = { family = "inet"; content = /* ... */; };
  mountOptions.staging = [ "noexec" "nosuid" "nodev" ];
};
```

```nix
# Host-Bridge (q958) — eine Zeile pro Ebene, bewusst und sichtbar
{ config, lib, ... }: {
  boot.kernel.sysctl = config.medinix.recommended.sysctl;
  networking.nftables.enable = true;
  networking.nftables.tables = config.medinix.recommended.nftables;
  fileSystems."/srv/staging".options = config.medinix.recommended.mountOptions.staging ++ [ "defaults" ];
}
```

Vorteile, die keine Alternative bietet:

- Der Kern ist **inert**. Ein Fremdnutzer, der nur `medinix.services.jellyfin.enable = true` setzt, bekommt keine einzige globale Änderung.
- Die Empfehlungen sind **inspizierbar** (`nix eval .#…config.medinix.recommended.sysctl`) und diffbar, bevor man sie anwendet.
- Der Host kann **teilweise** übernehmen (`sysctl // { "kernel.yama.ptrace_scope" = mkForce 0; }`), ohne den Kern zu forken.
- Empfehlungen können **abhängig von aktivierten Diensten** generiert werden — die nft-Egress-Sets kennen die UIDs der wirklich aktiven Dienste.

### A.4 Prioritäts-Disziplin: wie der Host tief eingreifen kann, ohne zu forken

Drei Regeln, die zusammen die Fork-Rate gegen Null treiben:

1. **`mkForce` ist im portablen Kern verboten.** Ausnahmslos. `mkForce` in einem Bibliotheksmodul nimmt dem Host die letzte Übersteuerungsmöglichkeit; danach bleibt nur noch Patchen. Wenn ein Wert wirklich unveränderlich sein muss, gehört er in eine Assertion, nicht in `mkForce`.
2. **Zwei Prioritätsstufen, dokumentiert:** sicherheitskritische Invarianten als normale Definition (Prio 100), alles Übrige als `mkDefault` (Prio 1000). Faustregel: kann ein Fremdhost das plausibel anders wollen, ohne dass mediNix unsicher wird? Dann `mkDefault`.
3. **Skalare zu Listen machen, wo systemd es erlaubt.** `unitOption` konkateniert Listen und verlangt bei Skalaren `mergeEqualOption` — also einen Eval-Abbruch bei Abweichung. Deshalb:

```nix
# schlecht: kollidiert hart mit jeder Host-Ergänzung
SystemCallFilter      = "@system-service";
CapabilityBoundingSet = "";
# gut: additiv, Host kann ergänzen ohne Konflikt
SystemCallFilter      = [ "@system-service" "~@privileged" "~@resources" ];
CapabilityBoundingSet = [ "" ];
RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
```

Zusätzlich zwei explizite Fluchtluken als Optionen, damit der Host nicht in `systemd.services.*` greifen muss:

```nix
medinix.hardening.profiles.<name>          # ganzes Profil ersetzbar
medinix.hardening.extraServiceConfig.<unit> # punktuelle Ergänzung
```

### A.5 Die Falle, die den meisten Schaden anrichtet: Profile in Upstream-Units mergen

Ein Härtungsprofil ist eine Sammlung von **Skalaren** (`Restart`, `RestartSec`, `SystemCallFilter`, `AmbientCapabilities`, `ProtectSystem`, …). Ein nixpkgs-Servicemodul setzt dieselben Skalare mit eigenen Werten. Beide Definitionen treffen sich in `systemd.services.<n>.serviceConfig` und werden per `mergeEqualOption` verglichen — abweichende Werte sind ein **Eval-Fehler**, kein Merge.

Daraus folgt eine architektonische Zweiteilung, die im Modul-Layout sichtbar sein sollte:

| | Eigene Unit (`ExecStart` von uns) | Upstream-Modul (`services.<x>.enable = true`) |
|---|---|---|
| Härtung | volles Profil, alle Skalare | **Overlay-Profil**: nur Keys, die Upstream *nicht* setzt, plus `mkDefault`, plus additive Listen |
| Identität | `users.users.<n>` von uns | Upstream-Optionen (`services.<x>.user/group/stateDir`) — **nie** per `serviceConfig`-Override |
| Regel | wir besitzen die Unit | wir besitzen sie nicht und tun auch nicht so |

Praktisch: gegen ein Upstream-Modul niemals `User`, `Group`, `StateDirectory`, `ExecStart`, `Restart` in `serviceConfig` schreiben. Diese Werte kommen aus den Modul-Optionen, sonst gibt es einen Konflikt, den keine Übersteuerung mehr auflöst.

### A.6 Wie man verhindert, dass Security die Portabilität frisst

Drei prüfbare Regeln:

1. **Publish-don't-apply** für alles Globale (A.3).
2. **Keine ungetestete Härtung.** Jede Härtungsmaßnahme braucht einen VM-Test, der beweist, dass der Dienst danach noch funktioniert (siehe C.2). Ungetestete Härtung ist der Hauptgrund, warum Leute Flakes forken: der Dienst geht nicht, die Ursache ist unsichtbar, das Modul fliegt raus.
3. **Zwei Eval-Checks als Grenzwächter:**

```nix
checks.hostile-minimal = (nixosSystem {
  modules = [ self.nixosModules.default {
    medinix.enable = true;             # alles an, nichts vom Host geliefert
    medinix.services.sabnzbd.enable = true;
    # KEIN medinix.host.*, KEIN networking, KEIN fileSystems
  } ];
}).config.system.build.toplevel;
# Erwartung: sauberer Assertion-Text, kein "undefined variable", kein "attribute missing"

checks.no-host-takeover = assertNoGlobalWrites {
  # medinix.enable = true, hostIntegration = "external"
  # danach: networking.nftables.enable == false
  #         boot.kernel.sysctl == {}
  #         boot.initrd.luks.devices == {}
  #         config.services.caddy.enable == false
};
```

Der zweite Check ist der eigentliche Grenzstein. Er macht „additiv" von einer Behauptung zu einer Eigenschaft.

### A.7 Tri-State statt Bool für Host-Ressourcen

Für jede Ressource, die theoretisch beide Seiten besitzen könnten, ein Enum statt eines Bools:

```nix
medinix.hostIntegration.<resource> = mkOption {
  type = types.enum [ "external" "managed" "off" ];
  default = "external";
};
```

- `external` (Default): Host besitzt es, mediNix prüft nur per Assertion, dass es passend konfiguriert ist.
- `managed`: mediNix richtet es ein — nur nach expliziter Entscheidung, nie per Default.
- `off`: Feature aus, keine Prüfung.

Ressourcen, die dieses Muster brauchen: `firewall`, `nftables`, `reverseProxy`, `dns`, `storage`, `sysctl`. Damit gibt es einen echten Standalone-Pfad (`profiles.standalone` setzt alles auf `managed`), ohne dass der Default je einen fremden Host übernimmt.

---

## B. Kernel- & Namespace-Policy

### B.0 Bedrohungsmodell zuerst, sonst wird es Theater

Realistische Angriffspfade für diesen Stack, nach Wahrscheinlichkeit:

1. **RCE in einer Web-App hinter dem Reverse-Proxy** (.NET-Arr, Node-Frontend, Python-Downloader). Ergebnis: Code als Service-User.
2. **Bösartiger Archivinhalt** trifft `unrar`, `par2`, `7z`, `ffmpeg` beim Entpacken/Transcodieren. Ergebnis: Code als Downloader-User, ausgelöst ohne jede Netzwerkexposition.
3. **Egress-Leak** des Downloaders (IP-Preisgabe, Phone-Home).
4. Lateral Movement zwischen Diensten über die geteilte media-Gruppe und über Loopback.

Nicht im Modell: Kernel-LPE durch einen zielgerichteten Angreifer, Evil-Maid, DMA-Angriffe. Daraus folgt die Wertung: **Blast-Radius eines kompromittierten Service-Users** ≫ **laterale Bewegung** ≫ **Kernel-Angriffsfläche**. Fast der gesamte Gewinn liegt per-Unit, nicht in `boot.kernel.sysctl`.

### B.1 Was in den portablen Kern gehört (per-Unit)

**Baseline für jede eigene Unit** — sicher für .NET, Node, Python, Go, Shell:

```nix
{
  NoNewPrivileges         = true;
  PrivateTmp              = true;
  PrivateMounts           = true;
  ProtectSystem           = "strict";
  ProtectHome             = true;
  ProtectProc             = "invisible";
  ProcSubset              = "pid";
  ProtectClock            = true;
  ProtectHostname         = true;
  ProtectKernelTunables   = true;
  ProtectKernelModules    = true;
  ProtectKernelLogs       = true;
  ProtectControlGroups    = true;
  RestrictNamespaces      = true;      # ← die eigentliche Antwort auf "userns"
  RestrictRealtime        = true;
  RestrictSUIDSGID        = true;
  LockPersonality         = true;
  RemoveIPC               = true;
  SystemCallArchitectures = "native";
  SystemCallFilter        = [ "@system-service" "~@privileged" "~@resources" "~@obsolete" ];
  SystemCallErrorNumber   = "EPERM";
  CapabilityBoundingSet   = [ "" ];
  AmbientCapabilities     = [ "" ];
  RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
  UMask                   = "0002";
}
```

Begründungen für die nicht-offensichtlichen Punkte:

- **`RestrictNamespaces = true` statt systemweitem userns-Verbot.** Das ist der Kern der Antwort auf `kernel.unprivileged_userns_clone`. Per-Unit, portabel, ohne jede Host-Wirkung — und es deckt genau die Angriffsfläche ab, die man abdecken will (der kompromittierte Service-User kann kein userns aufmachen, um an CAP_SYS_ADMIN im Namespace zu kommen). Ein systemweites `user.max_user_namespaces = 0` erreicht dasselbe für diese Dienste, zerlegt aber gleichzeitig die Nix-Build-Sandbox, `DynamicUser=`, `PrivateUsers=` und `nixos-rebuild build-vm`. Für einen öffentlichen Flake ist das ein Rückschritt, kein Fortschritt — deshalb gehört es **nicht** in den Kern, auch nicht als Empfehlung ohne dicken Warnhinweis.
- **`AF_NETLINK` bleibt drin.** .NET ruft beim Start `NetworkInterface.GetAllNetworkInterfaces()` und braucht dafür Netlink; Streichen führt zu schwer diagnostizierbaren Startfehlern. Wer es entfernt, hardened die Arrs kaputt.
- **`SystemCallErrorNumber = "EPERM"` statt Default-SIGSYS.** Python und .NET probieren Syscalls testweise; SIGSYS killt den Prozess stillschweigend, EPERM lässt ihn den Fehlerpfad nehmen. Bei .NET-Diensten ist das der Unterschied zwischen „läuft" und „stirbt nach 200 ms ohne Log".
- **`SystemCallFilter` als Liste mit `~`-Denies** statt handgeschriebener Allowlist. Eine eigene Allowlist bricht bei jedem glibc-/Runtime-Update still. `@system-service` wird von systemd gepflegt.

**`PrivateUsers` gehört auf `false` — im ganzen Stack.** Das ist eine bewusste, begründete Abweichung von der „mehr ist besser"-Intuition:

- Es bricht `AmbientCapabilities` für privilegierte Ports: Capabilities wirken nur im eigenen User-Namespace, die Netzwerk-Namespace gehört aber dem initialen. Ein Reverse-Proxy mit `PrivateUsers=true` + `CAP_NET_BIND_SERVICE` kann `:443` nicht binden.
- Es bricht Supplementary-Groups auf Geräte: `render`/`video` für `/dev/dri` erscheinen im Namespace als `nogroup` — VA-API-Transcoding fällt aus.
- Es interagiert schlecht mit der geteilten GID 5000 auf Dateien, die außerhalb des Namespaces liegen.
- Der Gewinn ist gering, wenn der Dienst ohnehin `CapabilityBoundingSet = [""]`, eine dedizierte UID und `NoNewPrivileges` hat.

**Filesystem-Confinement über Mount-Namespaces, nicht über Landlock:**

```nix
ReadWritePaths      = [ stateDir ];                       # nur der eigene State
BindReadOnlyPaths   = [ "${libraryDir}:${libraryDir}" ];  # Mediathek lesend
TemporaryFileSystem = [ "/tmp:noexec,nosuid,nodev,size=512M" ];
StateDirectoryMode  = "0700";                             # NICHT 0750 — s. C.4
```

`ProtectSystem=strict` + explizite `ReadWritePaths` ist deklarativ, portabel und in der Wirkung gleichwertig zu Landlock — bei diesem Bedrohungsmodell. Landlock hat keine native systemd-Direktive und bräuchte einen Wrapper oder App-Support; der Zusatznutzen gegenüber Mount-Namespaces ist hier real Null. Siehe E.

### B.2 Bind-Erzwingung: `SocketBindDeny` ist der unterschätzte Hebel

Ein wiederkehrendes Problem in Media-Stacks: die Nix-Konfiguration sagt `127.0.0.1:5510`, die App ignoriert es (weil der Wert über eine XML/INI/DB-Konfiguration geht, die zur Laufzeit überschrieben wird) und lauscht auf `0.0.0.0:8096`. Der Reverse-Proxy proxyt ins Leere, und der Dienst hängt gleichzeitig ungeschützt am LAN.

Konfiguration ist hier eine Bitte. `SocketBindDeny`/`SocketBindAllow` (systemd ≥ 249, cgroup-BPF) ist eine Durchsetzung:

```nix
SocketBindDeny  = [ "any" ];
SocketBindAllow = [ "ipv4:tcp:${toString port}" "ipv6:tcp:${toString port}" ];
```

Bindet die App auf `0.0.0.0`, bekommt sie `EPERM` und scheitert **laut** statt still falsch zu laufen. Das gehört in den portablen Kern: es ist per-Unit, braucht keine Host-Fakten, und defaultet für Fremdnutzer sicher — der Dienst kann nur den Port binden, den die Registry ihm zuweist.

Ergänzend, für Dienste ohne Egress-Bedarf (Musik-/Buchserver ohne Metadaten-Scraping):

```nix
SocketBindDeny = [ "any" ];  # + IPAddressDeny nur, wenn wirklich kein Egress nötig
```

### B.3 Die Egress-Filter-Falle — und vermutlich die Ursache des kaputten VPN-oben-Pfades

Drei systemd-Direktiven sehen aus wie Netzwerk-Policy, greifen aber **unterhalb** von Routing und fwmark an. Sie sind mit Policy-Routing nicht kombinierbar:

| Direktive | Mechanismus | Interaktion mit Policy-Routing |
|---|---|---|
| `IPAddressDeny` / `IPAddressAllow` | cgroup-eBPF, Filter auf Ziel-**Adresse** beim Socket-Call | Wirkt **unabhängig vom Routing**. `IPAddressDeny=any` + nur Loopback erlaubt ⇒ der Dienst erreicht keinen externen Host, egal wie korrekt die Route durch den Tunnel ist. |
| `RestrictNetworkInterfaces` | cgroup-eBPF auf Interface-Ebene | Der Socket ist bei Policy-Routing **nicht** an `wg0` gebunden — er wird dorthin geroutet. `RestrictNetworkInterfaces = [ "wg0" ]` blockiert deshalb genau den Pfad, den man erlauben wollte. |
| `PrivateNetwork` | eigener Netzwerk-Namespace | Die Host-nft-Regeln sehen den Traffic nie; `meta skuid` greift nicht; es gibt keine Route hinaus. Unvereinbar mit dem gewählten Kill-Switch-Design. |

**Alle drei müssen für den konfinierten Dienst aus sein.** Egress-Kontrolle macht ausschließlich nftables über `skuid` + Policy-Routing. Zwei Mechanismen für dieselbe Eigenschaft sind hier keine Verteidigung in der Tiefe, sondern ein garantierter Fehlbetrieb — und einer, der sich als „VPN-Pfad kaputt" tarnt, weil der Fail-closed-Pfad ja beweisbar funktioniert.

Wenn nach dem Entfernen dieser drei Direktiven der VPN-oben-Pfad noch klemmt, sind die nächsten drei Verdächtigen in dieser Reihenfolge:

1. **Source-Address-Selection.** `meta mark set` im `type route hook output` löst ein Reroute aus, aber die Quelladresse wird nur neu gewählt, wenn der Socket nicht bereits gebunden ist. Pakete verlassen `wg0` mit LAN-Quelladresse und werden von der Gegenstelle verworfen. Fix: die Default-Route in der Policy-Tabelle mit expliziter Quelle anlegen —
   `ip route replace default dev wg0 src <wg-adresse> table <N>`.
2. **`rp_filter`.** Strikte Reverse-Path-Filterung (`net.ipv4.conf.*.rp_filter = 1`) verwirft asymmetrisch geroutete Rückpakete — Policy-Routing ist per Definition asymmetrisch gegenüber der Main-Tabelle. Auf den beteiligten Interfaces `rp_filter = 2` (loose) setzen. Das ist eine **Host**-Einstellung und ein Musterfall für `medinix.recommended.sysctl`: der Kern kann sie nicht setzen, muss sie aber dokumentieren, sonst debuggt jeder Fremdnutzer dasselbe Problem neu.
3. **Regel-Reihenfolge und MTU.** Die `ip rule` muss vor dem ersten Paket existieren (`RemainAfterExit=true`, kein `ExecStop` — bereits korrekt). MTU/MSS: WireGuard-Overhead ohne `TCPMSS`-Clamping erzeugt genau das Bild „Handshake geht, Payload nicht" — ein `nft ... tcp flags syn tcp option maxseg size set rt mtu` in der Forward/Output-Chain schließt das aus.

### B.4 Was auf den Host gehört (`medinix.recommended.sysctl`, dort angewandt)

Wertvoll, geringes Bruchrisiko:

```nix
"kernel.kptr_restrict"          = 2;    # Kernel-Pointer nicht an Userspace
"kernel.dmesg_restrict"         = 1;
"kernel.kexec_load_disabled"    = 1;
"kernel.yama.ptrace_scope"      = 1;    # NICHT 2 oder 3 — bricht Debugger/Crash-Handler
"fs.protected_hardlinks"        = 1;
"fs.protected_symlinks"         = 1;
"fs.protected_fifos"            = 2;
"fs.protected_regular"          = 2;
"net.ipv4.conf.all.rp_filter"   = 2;    # loose — Voraussetzung für Policy-Routing
"net.ipv4.conf.default.rp_filter" = 2;
"net.ipv4.conf.all.accept_redirects"   = 0;
"net.ipv6.conf.all.accept_redirects"   = 0;
"net.ipv4.conf.all.accept_source_route" = 0;
```

`fs.protected_*` sind hier überdurchschnittlich wertvoll, weil mehrere Dienste über eine geteilte Gruppe in dieselben Verzeichnisse schreiben — genau das Szenario, für das die Symlink-/Hardlink-Schutzmechanismen gebaut wurden.

**Bewusst nicht empfohlen** (Begründung in E): `user.max_user_namespaces = 0`, `kernel.unprivileged_userns_clone = 0`, `kernel.modules_disabled = 1`, `net.ipv6.conf.all.disable_ipv6`, `kernel.lockdown`, `vm.*`-Tuning.

Zwei Host-Empfehlungen außerhalb von sysctl, mit hohem Nutzen pro Aufwand:

- **`noexec,nosuid,nodev` auf dem Staging-/Download-Mount.** Gegen Bedrohung Nr. 2 (bösartiges Archiv) ist das die wirksamste einzelne Maßnahme im ganzen Dokument — und sie kostet nichts. Gehört als `medinix.recommended.mountOptions`, weil der Kern das Dateisystem nicht kennt.
- **Warning, wenn `net.ipv4.ip_forward = 1`.** Der `skuid`-Kill-Switch hängt am `output`-Hook. Geforwardeter Traffic hat keinen Socket-UID und wird von der Regel nicht erfasst. Auf einem routenden Host ist das ein dokumentierbarer Rand des Modells — kein Loch, solange kein konfinierter Dienst Forwarding auslösen kann, aber der Nutzer sollte es wissen.

### B.5 .NET, Python, Node — Profile nach Runtime, nicht nach Dienst

Der einzige Unterschied, der eine Profil-Verzweigung rechtfertigt, ist die Runtime:

| Profil | `MemoryDenyWriteExecute` | Besonderheiten |
|---|---|---|
| `base` | `true` | Shell, Go-Binaries, statische Dienste |
| `jit` (.NET, Node, Java) | `false` | JIT braucht W+X-Übergänge. Kein Contortion-Versuch. |
| `jit-gpu` (Transcoding) | `false` | `PrivateDevices = false`, gezieltes `DeviceAllow`, `SupplementaryGroups`, **`PrivateUsers = false` zwingend** |
| `unpack` (Downloader) | `true` | `TemporaryFileSystem` mit `noexec`, `ReadWritePaths` nur Staging, **keine** IP-/Interface-Filter (B.3) |

`MemoryDenyWriteExecute = false` bei .NET ist kein Kompromiss, den man verstecken sollte. Der Ersatz-Hebel ist Filesystem- und Syscall-Confinement: ohne `@privileged`, ohne Capabilities, ohne Schreibrecht außerhalb des eigenen StateDir bringt ein W+X-Mapping dem Angreifer wenig, was er nicht ohnehin über den .NET-Interpreter hätte.

Die Profile gehören als **Option** in den Kern (`medinix.hardening.profiles.<name>`), nicht als privates `let`-Binding — sonst kann kein Host ein Profil anpassen, ohne zu forken.

### B.6 Was hier Theater ist

- Systemweites Deaktivieren von User-Namespaces — Kosten (Nix-Sandbox, systemd-Sandboxing) übersteigen den Nutzen deutlich, wenn `RestrictNamespaces=true` per Unit gesetzt ist.
- Handgeschriebene seccomp-Allowlists.
- `ProtectKernelTunables` & Co. auf Diensten, die ohnehin `CapabilityBoundingSet=[""]` haben — schadet nicht, ist aber bereits über die fehlenden Capabilities abgedeckt. Mitnehmen, aber nicht als Fortschritt verbuchen.
- `MemoryDenyWriteExecute` bei .NET erzwingen wollen.
- Landlock zusätzlich zu Mount-Namespaces.
- `PrivateUsers=true` flächendeckend.

---

## C. Die anderen Fundament-Pfeiler

### C.1 Modul-/Flake-Architektur

**Minimaler nächster Schritt:** Drei Ausgänge statt einem.

```nix
nixosModules.core      = ./modules;                    # inert, additiv, keine Globals
nixosModules.standalone = { imports = [ core ]; config = { /* hostIntegration = managed */ }; };
nixosModules.default   = nixosModules.core;            # sicherer Default
```

Plus **eine Invariante, die die Dendritizität prüfbar macht**: jede Moduldatei besteht auf oberster Ebene aus genau einem `mkIf` auf ihren eigenen Enable-Schalter. Kein Modul schreibt unbedingt. Das ist mit einem Eval-Check erzwingbar (Konfiguration mit `medinix.enable = false` muss identisch zur Konfiguration ohne mediNix sein) und macht das Versprechen „Datei löschen ⇒ Dienst verschwindet restlos" zu einer getesteten Eigenschaft.

**Portabel:** Modulcode, Registry, Profile, Assertions, `recommended.*`.
**Host:** Bridge-Modul, `medinix.host.*`-Werte, `hostIntegration = managed`-Entscheidungen.
**Verwässerungs-Falle:** Auto-Import per `readDir`. Er ist bequem, macht aber die Modulmenge von einem Verzeichnislisting abhängig — eine Backup-Datei, ein halbfertiges Modul, und das Verhalten ändert sich ohne Diff im Import-Graph. Wenn der Auto-Import bleibt, braucht er einen Check, der die tatsächlich importierte Dateiliste gegen die Registry abgleicht: jeder Registry-Eintrag hat ein Modul, jedes Modul einen Registry-Eintrag.

### C.2 systemd-Härtungs-Baseline

**Minimaler nächster Schritt — und der größte Einzelgewinn im ganzen Dokument: ein `nixosTest`, der den Standalone-Stack bootet und pro Dienst prüft:**

```python
machine.wait_for_unit("sabnzbd.service")
machine.succeed("ss -Hltn | grep -q '127.0.0.1:5410'")     # bindet er wirklich dort?
machine.fail("ss -Hltn | grep -q '0.0.0.0:5410'")           # und nirgends sonst?
machine.succeed("curl -sf http://127.0.0.1:5410/ >/dev/null")
machine.succeed("systemd-analyze security sabnzbd.service --threshold=4")
```

Härtung ohne diesen Test ist Blindflug: jede Verschärfung kann einen Dienst stillschweigend zerlegen, und die häufigste Fehlklasse (Konfiguration sagt X, App tut Y) ist statisch überhaupt nicht sichtbar. `systemd-analyze security --threshold` als Check macht Regressionen im Härtungsgrad zu Build-Fehlern.

**Portabel:** Profile als Optionen, `mkUnit`-Helper, VM-Tests.
**Host:** nichts — außer Profil-Übersteuerungen.
**Verwässerungs-Falle:** Profile in Upstream-Units mergen (A.5) und `mkForce` in Profilen.

### C.3 Netzwerk-Gesamtmodell

Aktuell existiert eine Egress-Regel für einen Dienst. Ein vollständiges Modell hat vier Ebenen:

1. **Ingress** — genau ein TLS-Terminator, alle App-Sockets ausschließlich Loopback, per `SocketBindDeny` erzwungen (B.2).
2. **East-West** — heute flach: Loopback ist überall Blanket-Accept. Das ist die stille Kill-Switch-Umgehung: ein konfinierter Dienst erreicht jeden anderen Loopback-Dienst, und wenn einer davon ein Fetch-Primitiv anbietet (Indexer-Proxy, Request-Portal), hat man einen WAN-Relay am Tunnel vorbei. Sauber lösbar über `skuid` + `dport` in der nft-Output-Chain: pro konfiniertem UID nur die Loopback-Ports freigeben, die er wirklich braucht.
3. **Egress** — die Verallgemeinerung des Kill-Switches. Statt einer Sonderregel eine **Egress-Klasse pro Dienst** in der Registry: `none` | `lan` | `internet` | `vpn`. Der Kill-Switch wird damit vom Spezialfall zur Instanz eines Modells. Downloader = `vpn`, Indexer/Metadaten = `internet`, Musikserver = `none`.
4. **Management** — SSH, Notifications, Backup: Host.

**Portabel:** Egress-Klassen in der Registry, generierte nft-Tabellen als `recommended.nftables`, `SocketBindDeny`-Erzwingung.
**Host:** `networking.nftables.enable`, Interface-Namen, LAN-CIDRs, ob überhaupt gefiltert wird.
**Verwässerungs-Falle:** konkrete Subnetze im Kern. Trust-CIDRs gehören als Host-Option; wenn der Kern einen Default braucht, dann RFC1918 + CGNAT als Menge, nie ein einzelnes `192.168.x.0/24`. Und: zwei getrennte Trust-Modelle (Proxy-Trust-CIDRs vs. Kill-Switch-LAN-Ausnahmen) müssen aus **einer** Quelle kommen, sonst driften sie auseinander.

### C.4 Secrets- & Trust-Modell

**Minimaler nächster Schritt:** ein Mechanismus, und die Erkenntnis, dass TPM-gesiegelte Credentials **host-gebundene Artefakte** sind. Sie können nicht im Flake liegen und nicht vom Flake erzeugt werden. Daraus die Grenze:

```nix
# Kern deklariert Bedarf — Namen, Format, Verbraucher
medinix.credentials = {
  usenet-server = { format = "KEY=value"; consumer = "sabnzbd"; };
  acme-dns-token = { format = "CF_DNS_API_TOKEN=<token>"; consumer = "acme"; };
};
# Host liefert Pfade
medinix.host.credentials.usenet-server = "/var/lib/credstore.encrypted/usenet.cred";
```

Zwei Regeln, die aus typischen Fehlern folgen:

- **Credential-Pfade sind `nullOr path` mit Default `null`.** Ein `types.str` mit einem plausiblen Default-Pfad führt dazu, dass `LoadCredentialEncrypted` unbedingt gesetzt wird — auf eine Datei, die nicht existiert und nicht verschlüsselt ist. Der Dienst startet nicht, und die Ursache steht nicht in der Nix-Konfiguration.
- **Runtime-Pfad ist `/run/credentials/<unit>.service/<id>`**, mit Suffix. Ohne `.service` ist das Verzeichnis leer, und der Fehler tritt erst zur Laufzeit auf.

**Trust-Modell — der Punkt, der meist übersehen wird:** GID 5000 ist eine Trust-Entscheidung. Sie bedeutet: jeder kompromittierte Dienst liest alles, was gruppenlesbar ist. Der Fehler ist, dieselbe Gruppe für **Mediendaten** und für **State-Verzeichnisse** zu verwenden — dann liest ein kompromittierter Musikserver die SQLite-Datenbank des Downloaders inklusive API-Keys und Usenet-Zugangsdaten. Die Trennung:

```nix
StateDirectoryMode = "0700";   # State: nur der Dienst selbst
# Mediendaten: setgid 2775, GID 5000 — geteilt, wie geplant
```

Das ändert nichts am Konzept der geteilten media-Gruppe, halbiert aber den lateralen Blast-Radius.

**Portabel:** Credential-Namen, Formate, Verbraucher-Kopplung, Assertions, Dateimodi.
**Host:** Pfade, TPM-Sealing, Rotation, Backup der `.cred`-Dateien.
**Verwässerungs-Falle:** Default-Pfade für Secrets im Kern; und ein zweiter Secret-Mechanismus „als Fallback" (Klartext-`EnvironmentFile`), der in der Praxis zum Hauptpfad wird.

---

## D. Reihenfolge

Der Kill-Switch bleibt bis Schritt 4 unangetastet — außer den drei Direktiven aus B.3, deren Entfernung ihn nicht schwächt, sondern erst funktionsfähig macht.

**1 — Grenzvertrag festschreiben** *(kein Laufzeitrisiko)*
`medinix.host.*` mit `null`-Defaults, `medinix.recommended.*` als `readOnly`, `hostIntegration`-Tri-State. Die zwei Eval-Checks aus A.6 (`hostile-minimal`, `no-host-takeover`). Ab hier ist „additiv" eine getestete Eigenschaft. Dieser Schritt schärft die Grenze, bevor irgendetwas anderes sie belasten kann.

**2 — Prioritäts- und Merge-Disziplin** *(entschärft latente Eval-Bomben)*
Alle `mkForce` aus dem Kern entfernen. Skalare zu Listen, wo systemd es erlaubt. Profile aufteilen in „eigene Unit" (voll) und „Upstream-Overlay" (nur additiv + `mkDefault`). Gegen Upstream-Module nie `User`/`Group`/`StateDirectory`/`ExecStart` per `serviceConfig`.

**3 — VM-Test-Harness** *(der größte Einzelgewinn)*
`nixosTest` bootet Standalone, prüft pro Dienst: Unit läuft, lauscht auf dem Registry-Port, lauscht **nur** dort, antwortet auf HTTP, `systemd-analyze security` unter Schwellwert. Danach `SocketBindDeny`/`SocketBindAllow` einführen — mit Test, der beweist, dass nichts kaputtgeht. Ab hier ist Härtung nicht mehr Blindflug.

**4 — VPN-oben-Pfad reparieren** *(jetzt reproduzierbar testbar)*
`IPAddressDeny`/`RestrictNetworkInterfaces`/`PrivateNetwork` aus dem Downloader-Profil. Dann in dieser Reihenfolge: Quelladresse (`src` in der Policy-Route), `rp_filter = 2`, MSS-Clamping. Der `nixosTest` aus Schritt 3 bekommt einen zweiten Knoten als WireGuard-Peer — Fail-closed **und** Fail-open werden damit beide zu Regressionstests statt zu manuellen Beweisen.

**5 — Egress-Klassen verallgemeinern**
Registry bekommt `egressClass` pro Dienst. Der Kill-Switch wird zur `vpn`-Instanz eines allgemeinen Modells. East-West-Regeln (`skuid` + `dport`) schließen die Loopback-Umgehung. Ausgabe als `recommended.nftables`; der Host schaltet nftables ein, nicht der Kern.

**6 — Kernel-/Mount-Empfehlungen veröffentlichen**
`recommended.sysctl` und `recommended.mountOptions` befüllen, in der Host-Bridge anwenden. `noexec,nosuid,nodev` auf Staging. Warning bei `ip_forward = 1`.

**7 — Secrets-Vertrag**
`medinix.credentials` als Bedarfsdeklaration, `medinix.host.credentials` als Lieferung, Assertion am Verbraucher. `StateDirectoryMode = "0700"` trennen von der geteilten Mediengruppe.

---

## E. Explizite Nicht-Ziele

| Nicht empfohlen | Begründung |
|---|---|
| **Systemweites Deaktivieren von User-Namespaces** (`user.max_user_namespaces = 0`, `unprivileged_userns_clone = 0`) | Zerlegt Nix-Build-Sandbox, `DynamicUser=`, `PrivateUsers=`, `build-vm`. `RestrictNamespaces=true` per Unit liefert für dieses Bedrohungsmodell denselben Schutz ohne Kollateralschaden — und ist portabel. |
| **Landlock** | Keine native systemd-Direktive; bräuchte Wrapper oder App-Support. `ProtectSystem=strict` + `ReadWritePaths` + `BindReadOnlyPaths` erreicht hier dasselbe, deklarativ und übersteuerbar. |
| **`PrivateUsers = true` flächendeckend** | Bricht privilegierte Ports, `/dev/dri`-Zugriff und Supplementary-Groups; geringer Zusatznutzen bei leerem `CapabilityBoundingSet`. |
| **Container/microvm/systemd-nspawn pro Dienst** | Ersetzt eine geprüfte systemd-Sandbox durch eine ungeprüfte Zusatzschicht, bricht die UID-basierte `skuid`-Markierung und widerspricht der bereits getroffenen netns-Entscheidung. |
| **Handgeschriebene seccomp-Allowlists** | Brechen still bei Runtime-Updates. `@system-service` + gezielte `~`-Denies sind gepflegt und diagnostizierbar. |
| **SELinux/AppArmor** | Auf NixOS kein gepflegter, policy-vollständiger Pfad. Aufwand geht vollständig in Policy-Debugging statt in Sicherheit. |
| **`kernel.lockdown`, IMA/EVM, dm-verity, Secure Boot** | Für einen Homelab-Media-Host außerhalb des Bedrohungsmodells; Lockdown bricht zusätzlich Out-of-Tree-Module (GPU-Treiber) — also genau das, was der Stack fürs Transcoding braucht. |
| **Full-Disk-Encryption im portablen Kern** | LUKS-Devicenamen, initrd-Implementierung und PCR-Policy sind Aussagen über die Maschine. Gehört ausschließlich in die Host-Bridge. |
| **L7-Plugins im Reverse-Proxy** (WAF, Rate-Limit, Geoblock, Bouncer) | Verlagert Policy in die TLS-Terminierung, macht das Proxy-Paket unreproduzierbar (`@latest`-Plugin-Pins) und dupliziert eine Entscheidung, die nftables sauberer trifft. Der Proxy bleibt flach. |
| **`MemoryDenyWriteExecute` bei .NET erzwingen** | Nicht erreichbar ohne den JIT zu deaktivieren. Ersatzhebel: Syscall- und Filesystem-Confinement. |
| **CIS-/DISA-Benchmark-Abarbeitung** | Optimiert auf einen Score, nicht auf dieses Bedrohungsmodell; erzeugt Härtungspunkte, die niemand testet. |
| **Metriken/Dashboards vor dem VM-Test** | Observability, die einen Dienst überwacht, dessen korrektes Verhalten nie definiert wurde, misst nur Rauschen. Erst der Test, der sagt, was „gesund" heißt. |
| **Zwei Secret-Mechanismen** | Ein Klartext-Fallback „für den Notfall" wird in der Praxis zum Hauptpfad und macht die TPM-Aussage unwahr. Einer, mit Assertion. |
