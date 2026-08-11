# ---
# id: "596-security-assertions"
# title: "Global [SEC-*] Assertions (firewall/prod hardening guardrails)"
# domain: 50
# folder: 59-guardrails
# status: active
# complexity: 3
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-0000
# provides: []
# requires: ["593-no-password-auth", "523-nftables-hardening"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: "assertions"
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
{ config, lib, ... }:

let
  must = assertion: message: { inherit assertion message; };
  sshSettings = config.services.openssh.settings or { };
  hardened = config.grapefruitMedia.security.enable;
  production = config.grapefruitMedia.mode == "production";
in
{
  config.assertions =
    (lib.optionals hardened [
      (must (config.my.security.firewall.enable == true) "[SEC-NET-001] Firewall aktiv (nftables-Modul).")
      (must (config.networking.nftables.enable == true) "[SEC-NET-002] NFTables aktiv.")
    ])
    ++ (lib.optionals production [
      (must (sshSettings.PermitRootLogin == "no") "[SEC-SSH-002] No Root SSH.")
      (must (!(sshSettings.PasswordAuthentication or false)) "[SEC-SSH-003] Kein Passwort-SSH.")
    ]);
}