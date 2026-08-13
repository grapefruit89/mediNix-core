# ---
# id: "590-registry"
# title: "Zentrale Fehler-Registry (Invarianten + Assertion-Errors)"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-13
# links:
#   adr: ADR-0000 (Dezimalrahmen-Verfassung)
# ---
{ lib }:

let
  invariants = {
    "INV-01" = {
      what = "Port = ServiceNumber × 10. Verletzung bedeutet Dezimalrahmen-Bruch.";
      expected = "Port entspricht dem Dezimalrahmen";
      found = "Abweichender Port konfiguriert";
      fix = "Dezimalrahmen einhalten (Port = ServiceNumber * 10)";
      ref = "ADR-0000";
    };
    "INV-02" = {
      what = "Alle Dienste binden auf 127.0.0.1. Niemals 0.0.0.0 im WAN.";
      expected = "127.0.0.1 Binding via Environment-Variablen";
      found = "0.0.0.0 WAN Binding möglich";
      fix = "LocalNetworkAddresses auf 127.0.0.1 setzen";
      ref = "ADR-0000";
    };
    "INV-03" = {
      what = "GID 5000 = media. Kein Dienst nutzt eine andere Media-GID.";
      expected = "GID 5000 (media)";
      found = "Abweichende GID konfiguriert";
      fix = "Group=media (5000) erzwingen";
      ref = "ADR-0000";
    };
    "INV-05" = {
      what = "Kein Secret liegt im Nix-Store (/nix/store/).";
      expected = "wgConf Pfad außerhalb des Stores";
      found = "/nix/store/ Prefix";
      fix = "Pfade auf /var/lib oder sops-nix umstellen";
      ref = "ADR-0000";
    };
    "INV-06" = {
      what = "stream-Dienste sind niemals ohne TLS WAN-erreichbar.";
      expected = "tls.mode != off";
      found = "tls.mode = off im WAN";
      fix = "TLS aktivieren oder Dienst vom WAN nehmen";
      ref = "ADR-0000";
    };
    "INV-07" = {
      what = "Kein Dienst mit /dev/dri-Bedarf hat PrivateDevices = true.";
      expected = "PrivateDevices = false";
      found = "PrivateDevices = true blockiert GPU";
      fix = "PrivateDevices für diesen Service deaktivieren";
      ref = "ADR-0000";
    };
    "INV-SECRET" = {
      what = "Kein Secret landet im Nix-Store. Alle Pfade via .cred-Dateien (TPM).";
      expected = "Alle Secrets via LoadCredential geladen";
      found = "Secret-Pfad beginnt mit /nix/store/";
      fix = "systemd LoadCredential nutzen";
      ref = "ADR-0000";
    };
    "INV-VPN-01" = {
      what = "usenet-confinement.enable erfordert vpn.interface.";
      expected = "vpn.interface gesetzt";
      found = "vpn.interface ist leer";
      fix = "Host: WireGuard anlegen und grapefruitMedia.vpn.interface setzen.";
      ref = "ADR-0000";
    };
    "INV-VPN-02" = {
      what = "vpn.dns existiert nicht — nur vpn.dnsServers. Phantom-Option verhindern.";
      expected = "vpn.dnsServers verwenden";
      found = "vpn.dns ist definiert";
      fix = "Option auf vpn.dnsServers umbenennen";
      ref = "ADR-0000";
    };
    "INV-VPN-03" = {
      what = "usenet-confinement aktiv → mindestens ein betroffener Dienst muss enable sein.";
      expected = "sabnzbd oder prowlarr aktiviert";
      found = "Kein Usenet-Dienst aktiv";
      fix = "Dienste aktivieren oder usenet-confinement ausschalten";
      ref = "ADR-0000";
    };
    "INV-VPN-04" = {
      what = "vpn.dnsServers Einträge müssen syntaktisch IPs sein (IPv4 oder IPv6).";
      expected = "IPv4 oder IPv6 Format";
      found = "Möglicher Hostname";
      fix = "Nur IP-Adressen eintragen";
      ref = "ADR-0000";
    };
    "[POLICY]-INV-VPN-05" = {
      what = "POLICY: keine Public-Resolver (1.1.1.1/8.8.8.8/9.9.9.9/208.67.222.222) in der Sandbox.";
      expected = "VPN-interne oder lokale (127.0.0.1) Resolver";
      found = "Public-Resolver konfiguriert";
      fix = "Public DNS aus vpn.dnsServers entfernen";
      ref = "ADR-0000";
    };
    "INV-TLS-02" = {
      what = "acmeHost gesetzt → TLS-Direktive muss in global UND standalone Caddy-Mode erscheinen.";
      expected = "TLS in beiden Scopes";
      found = "Fehlende TLS-Direktive";
      fix = "Beide konfigurieren";
      ref = "ADR-0000";
    };
    "INV-UMASK-01" = {
      what = "dotnet-Profil-Dienste müssen UMask=0002 haben (Arr braucht Gruppen-Schreibrecht).";
      expected = "UMask=0002";
      found = "Falsche oder fehlende UMask";
      fix = "systemd.services.<name>.serviceConfig.UMask = \"0002\" setzen";
      ref = "ADR-0000";
    };
    "INV-TECH-01" = {
      what = "Docker ist verboten. mediNix-core nutzt systemd-native.";
      expected = "virtualisation.docker.enable = false";
      found = "Docker aktiviert";
      fix = "Auf systemd-native umbauen";
      ref = "NO-CONTAINERS.md";
    };
    "INV-TECH-02" = {
      what = "Podman ist verboten. Gleicher Grund wie INV-TECH-01.";
      expected = "virtualisation.podman.enable = false";
      found = "Podman aktiviert";
      fix = "Auf systemd-native umbauen";
      ref = "NO-CONTAINERS.md";
    };
    "INV-TECH-03" = {
      what = "cron ist verboten. Nutze systemd.timers.";
      expected = "services.cron.enable = false";
      found = "cron aktiviert";
      fix = "systemd.timers verwenden";
      ref = "NO-CONTAINERS.md";
    };
    "INV-INGRESS-01" = {
      what = "Kein manueller Caddy-vHost außerhalb der Registry erlaubt.";
      expected = "Jeder vHost hat caddyClass != none in der Registry";
      found = "Manueller vHost konfiguriert";
      fix = "Dienst in lib/registry.nix eintragen";
      ref = "ADR-0000";
    };
  };

  errors = {
    "VPN-001" = {
      what = "vpn.interface ist leer — kein UID-Routing möglich.";
      expected = "Interface-Name gesetzt";
      found = "vpn.interface ist leer";
      fix = "grapefruitMedia.vpn.interface konfigurieren";
      ref = "5410";
    };
    "VPN-002" = {
      what = "vpn.dnsServers ist leer — DNS-Leak durch Host-Resolver möglich.";
      expected = "Mindestens ein DNS-Server gesetzt";
      found = "Leere Liste für vpn.dnsServers";
      fix = "grapefruitMedia.vpn.dnsServers konfigurieren";
      ref = "5410";
    };
    "VPN-003" = {
      what = "usenet-confinement aktiv aber weder sabnzbd noch prowlarr enabled.";
      expected = "Mindestens sabnzbd oder prowlarr aktiviert";
      found = "Kein Usenet-Dienst aktiv";
      fix = "Dienste aktivieren oder usenet-confinement ausschalten";
      ref = "5410";
    };
    "VPN-005" = {
      what = "vpn.wgConf liegt im Nix-Store — private Key ist world-readable.";
      expected = "wgConf außerhalb des Stores";
      found = "/nix/store/ Prefix";
      fix = "wgConf-Pfad auf einen State-Ordner setzen";
      ref = "5410";
    };
    "TLS-001" = {
      what = "tls.acmeHost und tls.certFile beide gesetzt — nur eines erlaubt.";
      expected = "Nur eine TLS-Quelle";
      found = "Beide Quellen konfiguriert";
      fix = "acmeHost oder certFile entfernen";
      ref = "5111";
    };
    "TLS-002" = {
      what = "tls.mode = custom aber certFile oder keyFile fehlt.";
      expected = "Beide Dateien definiert";
      found = "Eine oder beide fehlen";
      fix = "tls.certFile und tls.keyFile setzen";
      ref = "5111";
    };
    "TLS-003" = {
      what = "stream-Dienste aktiv aber tls.mode = off — kein TLS für WAN.";
      expected = "tls.mode != off";
      found = "tls.mode = off";
      fix = "TLS aktivieren oder Dienste lokal begrenzen";
      ref = "5111";
    };
    "AUTH-001" = {
      what = "ingress.auth.mode = forward-auth aber authProxyPresent = false.";
      expected = "authProxyPresent = true";
      found = "authProxyPresent = false";
      fix = "Authentifizierungs-Dienst aktivieren";
      ref = "5120";
    };
    "DNS-001" = {
      what = "DDNS aktiv aber kein Token konfiguriert.";
      expected = "ddns.token gesetzt";
      found = "Token ist null";
      fix = "Token via sops-nix konfigurieren";
      ref = "5130";
    };
    "SEC-001" = {
      what = "CrowdSec aktiv aber enrollKeyFile fehlt.";
      expected = "enrollKeyFile gesetzt";
      found = "Kein Keyfile definiert";
      fix = "grapefruitMedia.observability.crowdsec.enrollKeyFile konfigurieren";
      ref = "5820";
    };
    "SEC-002" = {
      what = "networking.firewall.enable = false — nftables-Regeln greifen nicht.";
      expected = "networking.firewall.enable = true";
      found = "Firewall ist deaktiviert";
      fix = "Firewall einschalten";
      ref = "5200";
    };
    "STORE-001" = {
      what = "storage.mediaRoot ist leer.";
      expected = "Gültiger Pfad";
      found = "Leerer Pfad";
      fix = "storage.mediaRoot konfigurieren";
      ref = "5010";
    };
    "STORE-002" = {
      what = "storage.metadataDir liegt auf HDD — SSD empfohlen.";
      expected = "Pfad auf SSD";
      found = "Möglicher HDD-Pfad";
      fix = "Auf schnellen Speicher verschieben";
      ref = "5010";
    };
  };

  formatMessage = prefix: code: data:
    "[mediNix-core/${prefix}/${code}] ${data.what}\n" +
    "  Erwartet: ${data.expected}\n" +
    "  Gefunden: ${data.found}\n" +
    "  Fix: ${data.fix}\n" +
    "  Ref: ${data.ref}";

  mkInvariant = code: condition: {
    assertion = condition;
    message = formatMessage "INVARIANTE" code invariants.${code};
  };

  mkError = code: condition: {
    assertion = condition;
    message = formatMessage "CODE" code errors.${code};
  };

  mkErrorDoc = code: condition: adr: {
    assertion = condition;
    # Für mkErrorDoc überschreiben wir das ref-Feld der Registry mit dem übergebenen ADR-Link
    message = formatMessage "CODE" code (errors.${code} // { ref = "ADR-${adr}"; });
  };
in
{
  inherit invariants errors mkInvariant mkError mkErrorDoc;
}
