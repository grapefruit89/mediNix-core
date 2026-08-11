# ---
# id: "522-kernel"
# title: "Kernel sysctl Hardening (rp_filter, bpf_jit_harden, kptr_restrict)"
# domain: 52
# folder: 52-security
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5200
#   skill: nixos-context7-gate
# context7:
#   - query: "boot.kernel.sysctl rp_filter bpf_jit_harden kptr_restrict example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "boot.kernel.sysctl.<key> = value; applied at runtime"
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
in
{
  # Kernel-Härtung (Context7-verifiziert: boot.kernel.sysctl.<key> Syntax)
  # Nur relevante, homelab-sichere Werte — kein Over-Hardening das Dienste bricht.
  boot.kernel.sysctl = {
    # Reverse Path Filtering — verhindert IP-Spoofing
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;

    # BPF JIT Hardening — verhindert BPF-JIT-Spekulation
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;

    # Kernel Pointer Restriction — keine KPtr-Leaks in dmesg/proc
    "kernel.kptr_restrict" = 2;

    # Dmesg nur für root (Defence-in-Depth, ersetzt security.protectKernelLogs)
    "kernel.dmesg_restrict" = 1;
  };
}
