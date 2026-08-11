# ---
# id: "524-kernel-hardening"
# title: "Kernel Hardening (sysctl lockdown knobs)"
# domain: 50
# folder: 52-security
# status: active
# complexity: 3
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-0000
# provides: []
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# 52-security/524-kernel-hardening.nix — Kernel Hardening (sysctl)
{ lib, pkgs, config, ... }:

{
  # Kernel hardening via sysctl
  boot.kernel.sysctl = {
    # Disable kernel module loading after boot (optional, strict)
    "kernel.modules_disabled" = 0;  # Set to 1 for strict lockdown

    # Restrict dmesg access
    "kernel.dmesg_restrict" = 1;

    # Disable magic SysRq (optional)
    "kernel.sysrq" = 0;

    # Prevent kernel pointer leaks
    "kernel.kptr_restrict" = 2;

    # Restrict ptrace scope (no process inspection across UIDs)
    "kernel.yama.ptrace_scope" = 2;

    # Disable core dumps
    "fs.suid_dumpable" = 0;
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;

    # BPF restriction (vector-store gap: "BPF restrictions" for threat model).
    # Block unprivileged BPF JIT spray / Spectre-class gadget chains.
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
    "kernel.bpf_stats_enabled" = 0;
  };
}
