# ---
# id: "526-systemd-credentials"
# title: "Secrets via systemd LoadCredential (fail-closed, native)"
# domain: 50
# folder: 52-security
# status: draft
# complexity: 2
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-20-security.md
#   modules:
#     - path: Nix Files/modules/20-security.nix
# provides: []
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ''
# nixpkgs_attr: ''
# state_dir: '/var/lib/mediNix/secrets'
# uds_socket: false
# systemd_hardened: true
# ---
# 52-security/526-systemd-credentials.nix — Secrets via systemd LoadCredential (fail-closed)
# Source: mediNix vector store (chat history), pattern-score 0.69
# VERIFY systemd LoadCredential option via Context7 / nixos.org before deploy
{ lib, config, ... }:

# Pattern: secret files (NOT env values, NOT args) injected via systemd
# $CREDENTIALS_DIRECTORY. Safer than EnvironmentFile (isolated per-service dir).
# Prefer over sops for mediNix (no extra tooling, native systemd).
#
# Usage in a service module:
#   systemd.services.<svc>.serviceConfig = {
#     LoadCredential = [ "api_key:/var/lib/mediNix/secrets/<svc>/api_key" ];
#     # file MUST be 0600 root:root, not in /proc/<pid>/environ
#   };
#
# ⚠️ VERIFY: systemd.services.<name>.serviceConfig.LoadCredential supported by
#   your systemd (>=247, NixOS 24.11 ships 255+). Context7: "systemd LoadCredential"
# ⚠️ VERIFY: nixos option path `systemd.services.<name>.serviceConfig.LoadCredential`
#   resolves (it is a freeform passthrough, not a typed option).
let
  cfg = config.grapefruitMedia.secrets;
in
{
  options.grapefruitMedia.secrets = {
    enable = lib.mkEnableOption "systemd-credentials secret pattern";
    storeDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/mediNix/secrets";
      description = "Root for secret files (0600 root:root).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enforce permission baseline for secret store.
    system.activationScripts.mediNixSecretsDir = lib.stringAfter [ "users" ] ''
      mkdir -p ${cfg.storeDir}
      chmod 0700 ${cfg.storeDir}
    '';
  };
}
