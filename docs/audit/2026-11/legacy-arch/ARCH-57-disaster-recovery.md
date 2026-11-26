---
id: "ARCH-57-disaster-recovery"
title: "ARCH 5700 disaster recovery"
domain: 57
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - disaster-recovery
  - storage
links:
  adr: ""
  repo-harvest: ""
---
# Architecture: Disaster Recovery & QR-Unlock (NMS v4.2)

## 1. User Layer (KISS)
Dieses Dokument beschreibt dein Sicherheitsnetz für den absoluten Ernstfall. Wenn dein Server auf fremder Hardware oder in einem unbekannten Netzwerk startet und der automatische Login fehlschlägt, zeigt er einen QR-Code auf dem Bildschirm. Du musst diesen nur mit deinem Handy scannen, um eine sichere Verbindung (SSH) herzustellen und das Passwort aus deinem Passwortmanager einzugeben. So kommst du immer an deine Daten, egal wo du bist.

## 2. Technical Layer (Aviation-Grade)

### Der Disaster-Recovery Workflow
1.  **Trigger:** Der DNA-Check (MAC-Fingerprint) oder die TPM-Validierung schlagen fehl.
2.  **Aktivierung:** Der Dienst `nms-emergency-ui.service` startet in der `initrd`.
3.  **Visualisierung:** Nutzung von `qrencode`, um die SSH-Verbindungsdaten als ANSI-Text auf dem TTY1 auszugeben.
4.  **Handoff:** Der Nutzer verbindet sich via Smartphone-SSH (Port 2222) und nutzt `systemd-tty-ask-password-agent`, um die LUKS-Passphrase sicher zu übermitteln.

### Implementierung: Emergency-UI (Nix-Snippet)
```nix
systemd.services."nms-emergency-ui" = {
  description = "NMS Emergency Unlock UI";
  wantedBy = [ "initrd.target" ];
  conditionPathExists = "!/run/network-is-home"; # Nur bei fehlgeschlagenem DNA-Check
  serviceConfig.ExecStart = pkgs.writeShellScript "show-qr" ''
    echo "--- NMS v4.2 DISASTER RECOVERY ---"
    ${pkgs.qrencode}/bin/qrencode -t ANSIUTF8 "ssh -p 2222 root@$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
    echo "1. Scanne den Code oder verbinde dich manuell via SSH (Port 2222)."
    echo "2. Gib die Passphrase ein, um den Bootvorgang fortzusetzen."
  '';
};
```

### Netzwerk-Resilienz
Um den SSH-Zugriff zu garantieren, lädt die `initrd` universelle Netzwerktreiber (`e1000e`, `r8169`, `usbnet`) und konfiguriert eine statische IP oder Fallback-DHCP, bevor das Emergency-UI erscheint.

## 3. Reasoning Layer (History)

### [ADR-007] QR-Code based Remote Unlock
*   **Status:** Entschieden (März 2026).
*   **Kontext:** Physische Tastaturen sind an Servern oft nicht vorhanden. Die Eingabe von komplexen 64-Zeichen Passphrasen am TTY ist fehleranfällig und ein massiver operativer Reibungspunkt (Toil).
*   **Entscheidung:** Einführung eines QR-Code-basierten Handoffs an das Smartphone.
*   **Vorteile:** Sicherheit durch Public-Key-Auth (Smartphone-Key in Secure Enclave) + Passphrase-Eingabe über eine vertraute UI (Handy-Tastatur).
*   **Konsequenzen:** Erfordert `qrencode` in der `initrd`. Das Risiko eines Metadaten-Leaks (IP-Adresse im QR-Code) wird als gering eingestuft, da der Zugriff physischen Zugang zum Monitor erfordert.

---
**Sources:**
*   `/home/Knowledge-Pipeline/raw/_duplikate/Gemini-Stadtbibliothek Troisdorf_ Bürgergeld-Mitgliedschaft.md`
*   `/home/Knowledge-Pipeline/raw/_duplikate/NMS_v4.2_SOVEREIGN_IDENTITY_AUDIT.md`
