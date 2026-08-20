# mediNix-core Architectural Patterns

**Decimal Framework (XYZ-Matrix + Isomorphie)**  
Dreistellige Nummer als einzige Wahrheit: X = Projekt, Y = Domäne, Z = Programm/Instanz. Daraus werden Port (Nummer × 10), UID (Projekt × 1000 + Rest) und GID (Projekt × 1000) strikt abgeleitet.  
**Warum gut:** Erfüllt SSoT + Decimal Framework; macht Kollisionen mathematisch unmöglich und die Struktur selbstbeschreibend.  

**Dendritic Modularity / One-Entity (Drop & Forget)**  
Ein Programm existiert nur als eine logische Entität (Datei oder gleichnamiger Ordner). Löschen dieser Entität entfernt Basis, Ingress, Sandboxing und Assertions restlos.  
**Warum gut:** Erfüllt Dendritic Modularity; garantiert Locality und verhindert verstreute Reste.  

**Fractal Anchors (_0 / _1 / _2 / _9)**  
Die vier Anker (Fundament, Zugang, Sicherheit, Leitplanken) gelten auf Domänenebene und spiegeln sich als strukturierende Blöcke innerhalb jeder Service-Datei wider.  
**Warum gut:** Gibt der Architektur eine einheitliche, navigierbare Semantik.  

**Iron Zero Rule**  
Eine Null am Ende einer Nummer (…0) ist niemals ein Dienst, sondern ausschließlich organisatorisch (default.nix, Fundament, Scanner).  
**Warum gut:** Schützt die Isomorphie und hält die Domänen-Ordner strukturell sauber.  

**Service Factory + Registry Derivation**  
Eine zentrale Factory (mk-arr-service / mk-servarr) erzeugt aus dem Servicenamen automatisch User, Group, tmpfiles, systemd-Unit, Hardening und Credential-Injection, indem sie ausschließlich aus der SSoT-Registry liest.  
**Warum gut:** Garantiert Konsistenz und Anti-Drift; erfüllt SSoT und Fail-Closed Security.  

**Uniform Systemd Hardening (Fail-Closed)**  
Alle relevanten Dienste erhalten denselben harten Satz: ProtectSystem=strict, ProtectProc=invisible, PrivateTmp, NoNewPrivileges, SystemCallFilter (Blacklist kritischer Syscalls), RestrictAddressFamilies, ReadWritePaths nur für erlaubte Pfade.  
**Warum gut:** Erfüllt Fail-Closed Security; zentralisiert über die Factory, so dass keine Ausnahme vergessen werden kann.  

**Credential Flow via systemd-creds**  
mediNix erwartet nur Pfade zu bereits vorhandenen Credential-Dateien. Secrets werden per LoadCredentialEncrypted geladen und als Environment-Variable injiziert; Klartext landet nie im Nix-Store und nie global im RAM.  
**Warum gut:** Erfüllt Fail-Closed Security und Additive Host-Integration.  

**Seed-and-Persist (Opt-in State)**  
Config-Verzeichnisse werden persistent markiert. Ein preStart-Skript schreibt Basis-Einstellungen nur, wenn die Datei noch nicht existiert; danach übernimmt die GUI und die Änderungen überleben Reboots.  
**Warum gut:** Macht Impermanence praktikabel, ohne die Bedienbarkeit zu zerstören; hält den Zustand deklarativ und opt-in.  

**wait-for-API Precondition**  
Provisioning-Units besitzen einen ExecStartPre, der die API des Zieldienstes in einer Schleife pollt, bis HTTP 200 kommt, bevor das eigentliche Setup-Skript startet.  
**Warum gut:** Verhindert Race-Conditions beim Boot; macht den Start deterministisch und robust.  

**Additive Host-Integration / Configuration Merging**  
Module injizieren nur ihre eigenen Scrape-Configs, Endpoints oder Credentials in bestehende Host-Dienste (Prometheus, Gatus, systemd-creds). Sie überschreiben oder besitzen den Host-Dienst nicht.  
**Warum gut:** Erfüllt Additive Host-Integration und hält mediNix portabel.  

**Locality of Service Definition**  
Alles, was zu einem Dienst gehört (Core, Ingress, Security, Assertions), liegt in genau einer Datei bzw. einem Ordner. Keine verteilten Schnipsel in fremden Domänen.  
**Warum gut:** Verstärkt Dendritic Modularity und macht Änderungen und Löschungen atomar und nachvollziehbar.  
