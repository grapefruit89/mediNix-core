# ---
# id: "527-vpn-interface"
# title: "Flake-managed WireGuard Interface (52-security, Dienst 527)"
# domain: 52
# folder: 52-security
# status: active
# complexity: 3
# last_reviewed: 2026-08-18
# links:
#   adr: ADR-5410, ADR-5270
# ---
# Erstellt das WireGuard-Interface wenn vpn.enable = true && vpn.useExistingInterface = false.
# Setzt grapefruitMedia.vpn.interface + vpn.dnsServers automatisch (für Killswitch-Compat).
# Der Private Key kommt ausschließlich via systemd-credentials (LoadCredentialEncrypted).
# Flake-first: Host liefert nur den physischen Credential-Pfad.
{ config, lib, ... }:

let
  cfg    = config.grapefruitMedia;
  vpn    = cfg.vpn;
  ifName = vpn.interfaceName;
  # Credential-Pfad zur Laufzeit (nach LoadCredentialEncrypted)
  credMount = "/run/credentials/wireguard-${ifName}.service/wg-private-key";
in
lib.mkIf (cfg.enable && vpn.enable && !vpn.useExistingInterface) {

  # vpn.interface + dnsServers automatisch setzen (Killswitch + Guardrail-Compat)
  # lib.mkDefault: Host kann überschreiben falls nötig
  grapefruitMedia.vpn.interface  = lib.mkDefault ifName;
  grapefruitMedia.vpn.dnsServers = lib.mkDefault vpn.dns;

  # WireGuard Interface (NixOS-nativ, kein wg-quick, kein Docker)
  networking.wireguard.interfaces.${ifName} = {
    ips            = vpn.address;
    privateKeyFile = credMount;
    dns            = vpn.dns;

    peers = lib.optional (vpn.peer.publicKey != "") {
      publicKey           = vpn.peer.publicKey;
      endpoint            = vpn.peer.endpoint;
      allowedIPs          = vpn.peer.allowedIPs;
      persistentKeepalive = vpn.peer.persistentKeepalive;
    };
  };

  # Private Key via systemd-credentials (LoadCredentialEncrypted)
  # Muss in der wireguard-Unit selbst deklariert sein, damit das Credential
  # vor dem Interface-Start unter credMount verfügbar ist.
  systemd.services."wireguard-${ifName}" =
    lib.mkIf (vpn.privateKeyCredentialPath != null) {
      serviceConfig.LoadCredentialEncrypted = [
        "wg-private-key:${vpn.privateKeyCredentialPath}"
      ];
    };
}
