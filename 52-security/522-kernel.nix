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
lib.mkIf cfg.enable {
  # Kernel hardening (Context7 verified: boot.kernel.sysctl.<key> Syntax)
  # Only relevant, homelab-safe values — no over-hardening that breaks services.
  boot.kernel.sysctl = {
    # Reverse Path Filtering — Loose (2) for VPN Killswitch Policy-Routing
    "net.ipv4.conf.all.rp_filter" = 2;
    "net.ipv4.conf.default.rp_filter" = 2;

    # BPF JIT Hardening — prevents BPF-JIT speculation
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;

    # Kernel Pointer Restriction — no KPtr leaks in dmesg/proc
    "kernel.kptr_restrict" = 2;

    # Dmesg only for root (Defence-in-Depth, replaces security.protectKernelLogs)
    "kernel.dmesg_restrict" = 1;
  };
}
