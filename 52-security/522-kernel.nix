# ---
# id: "522-kernel"
# title: "Kernel sysctl & Parameter Hardening (Network, Memory, FS, Media-Safe)"
# domain: 52
# folder: 52-security
# status: active
# complexity: 3
# last_reviewed: 2026-08-18
# links:
#   adr: ADR-5200
#   skill: nixos-context7-gate
# context7:
#   - query: "boot.kernel.sysctl rp_filter bpf_jit_harden kptr_restrict inotify example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "boot.kernel.sysctl.<key> = value; applied at runtime"
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
in
lib.mkIf cfg.enable {
  # Kernel hardening (Context7 verified: boot.kernel.sysctl.<key> Syntax)
  # Only relevant, homelab-safe values — no over-hardening that breaks media services.

  boot.kernel.sysctl = {
    # ── 1. Network Layer Hardening (IPv4 & IPv6) ──────────────────────────

    # Reverse Path Filtering — Loose (2) mode.
    # Strict mode (1) breaks asymmetric routing and WireGuard VPN policy routing (Killswitch).
    # Loose mode validates source IP reachability via any interface, preventing spoofing
    # while allowing multi-interface and VPN killswitch routing to function seamlessly.
    "net.ipv4.conf.all.rp_filter" = 2;
    "net.ipv4.conf.default.rp_filter" = 2;

    # TCP SYN Cookies — Generates cryptographic cookies when SYN backlog overflows.
    # Protects Caddy reverse proxy and exposed media ports from SYN flood DoS attacks.
    # Safe: Activates only under flood conditions without impacting normal connections.
    "net.ipv4.tcp_syncookies" = 1;

    # TCP TIME-WAIT Protection (RFC 1337) — Drops RST packets for sockets in TIME-WAIT.
    # Prevents connection reset injection / assassination hazards during connection teardown.
    # Safe: Fully compatible with high-concurrency HTTP/HTTPS streaming and API traffic.
    "net.ipv4.tcp_rfc1337" = 1;

    # Reject ICMP Redirects (IPv4 & IPv6) — Prevents rogue hosts on the local network
    # from poisoning routing tables via MITM redirection. Safe for media servers using static/DHCP gateways.
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;

    # Disable Sending ICMP Redirects — Host is a dedicated media server, not a gateway/router.
    # Prevents topology disclosure and redirect amplification abuse.
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;

    # Reject IP Source Routing (IPv4 & IPv6) — Disallows packets specifying explicit routing hops.
    # Obsolete mechanism used in IP spoofing. Safe: Modern networks never legitimately use source routing.
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;

    # Ignore ICMP Broadcast Echoes — Prevents participation in Smurf / broadcast amplification attacks.
    # Safe: Standard unicast ICMP ping to the server functions normally.
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;

    # Ignore Bogus ICMP Error Responses — Drops malformed ICMP error packets to prevent log flooding.
    # Safe: Legitimate ICMP error messages are processed normally.
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    # Log Martian Packets — Logs packets with impossible/spoofed source addresses to the kernel ring buffer.
    # Safe: Diagnostic aid for detecting spoofing and network misconfigurations with zero traffic disruption.
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;

    # ── 2. Memory & Kernel Self-Protection ─────────────────────────────────

    # Disable Unprivileged BPF — Prevents unprivileged users from loading BPF programs into kernel space.
    # Closes a major vector for local privilege escalation and speculative execution side channels.
    # Safe: Root and systemd retain full BPF capability (used by WireGuard killswitch cgroup hooks).
    "kernel.unprivileged_bpf_disabled" = 1;

    # BPF JIT Constant Blinding — Hardens BPF JIT compiler against JIT-spraying and speculative attacks.
    # Value 2 enables blinding for all programs (including root-loaded BPF programs).
    "net.core.bpf_jit_harden" = 2;

    # Kernel Pointer Restriction (kptr_restrict = 2) — Masks kernel memory addresses in /proc and sysfs.
    # Prevents kernel address leakage required for Return-Oriented Programming (ROP) exploit chains.
    # Safe: Root utilities with CAP_SYSLOG retain access when needed.
    "kernel.kptr_restrict" = 2;

    # Restrict dmesg Access (dmesg_restrict = 1) — Restricts kernel ring buffer access to users with CAP_SYSLOG.
    # Prevents unprivileged services from inspecting kernel logs, device enumerations, or memory layouts.
    # Safe: System logs remain accessible via journalctl for administrative users.
    "kernel.dmesg_restrict" = 1;

    # Yama LSM Ptrace Scope (ptrace_scope = 1) — Restricts ptrace attachment to direct child processes.
    # Prevents compromised unprivileged services from injecting code into other processes under the same UID.
    # Safe: Media services do not ptrace peer services, while debugging tools can trace child processes.
    "kernel.yama.ptrace_scope" = 1;

    # Disable Runtime Kexec (kexec_load_disabled = 1) — Disallows runtime replacement of the active kernel.
    # Closes persistence vectors for kernel-level rootkits across warm reboots.
    # Safe: Homelab servers perform clean reboots via systemd/firmware.
    "kernel.kexec_load_disabled" = 1;

    # Restrict Performance Events (perf_event_paranoid = 2) — Disallows unprivileged access to performance counters.
    # Mitigates hardware side-channel timing attacks (e.g. CPU branch prediction leaks).
    # Safe: Media playback and hardware transcoding do not require unprivileged perf counters.
    "kernel.perf_event_paranoid" = 2;

    # Full ASLR (randomize_va_space = 2) — Enforces full Address Space Layout Randomization.
    # Randomizes stack, VDSO, mmap memory mappings, and heap/brk allocations against memory corruption.
    # Safe: Standard across modern Linux distributions; fully compatible with all services.
    "kernel.randomize_va_space" = 2;

    # ── 3. Filesystem Hardening & Race Condition Defenses ──────────────────

    # Protected Symlinks & Hardlinks — Disallows following symlinks in sticky world-writable directories (/tmp)
    # unless owned by the follower or directory owner; disallows creating hardlinks to unowned files.
    # Mitigates Time-of-Check to Time-of-Use (TOCTOU) symlink hijacking and privilege escalation attacks.
    # Safe: Services operate in isolated StateDirectories or systemd PrivateTmp mounts.
    "fs.protected_symlinks" = 1;
    "fs.protected_hardlinks" = 1;

    # Protected FIFOs & Regular Files — Restricts opening FIFOs and regular files in sticky directories
    # to file owners, preventing data injection and spoofing in shared temporary paths.
    # Safe: Unprivileged services use private temporary directories.
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;

    # Disable SUID Core Dumps — Prevents setuid/setgid binaries and processes with changed privileges from dumping core.
    # Prevents memory-resident credentials and private keys from leaking into readable core dump files.
    # Safe: Production services log errors via stderr/journald without requiring SUID core dumps.
    "fs.suid_dumpable" = 0;

    # ── 4. Homelab Media-Server Scaling & Stability ────────────────────────

    # Scale Inotify Watchers & Instances — Increases table limits for kernel filesystem event notifications.
    # Essential for Jellyfin, Navidrome, Audiobookshelf, Sonarr, Radarr, Lidarr, and Readarr to monitor
    # extensive media libraries without crashing with "ENOSPC: System limit for number of file watchers reached".
    # Safe: Consumes negligible memory (~1 KB per watcher) while guaranteeing rock-solid filesystem monitoring.
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 8192;

    # System File Descriptors Capacity — Increases maximum open file descriptors across all processes.
    # Accommodates high-throughput parallel Usenet downloads (SABnzbd), concurrent media stream chunking,
    # and reverse proxy connections without running out of file handles.
    # Safe: Dynamic allocation ensures resources are consumed only as needed.
    "fs.file-max" = 2097152;
  };

  # ── 5. Kernel Boot Parameters ──────────────────────────────────────────
  # Safe, low-overhead kernel exploit mitigations applied at boot time.
  boot.kernelParams = [
    # Page Allocator Randomization — Randomizes page allocator freelists, disrupting heap exploit layouts.
    # Safe: Negligible performance impact, fully compatible with GPU/DRM memory management.
    "page_alloc.shuffle=1"

    # Disable Slab Merging — Prevents merging of slab caches with similar sizes, containing heap overflows
    # to their specific object type and mitigating cross-cache exploitation.
    # Safe: Standard in security-hardened kernels with zero impact on media workloads.
    "slab_nomerge"

    # Zero Memory on Allocation — Fills allocated kernel heap and page memory with zeroes.
    # Eliminates uninitialized memory disclosure vulnerabilities and information leaks.
    # Safe: Hardware memory initialization is fast on modern x86_64 CPUs.
    "init_on_alloc=1"

    # Zero Memory on Free — Zeroes memory pages upon deallocation to mitigate use-after-free exploits.
    # Safe: Clean memory hygiene with negligible overhead for media streaming workloads.
    "init_on_free=1"

    # Disable Legacy Vsyscall Mapping — Removes the obsolete fixed-address vsyscall page (used in ROP gadgets)
    # in favor of modern VDSO. Safe: All modern Linux binaries and NixOS glibc use VDSO.
    "vsyscall=none"
  ];

  # ── 6. Blacklisted Kernel Modules ──────────────────────────────────────
  # Attack surface reduction: disables automatic loading of obsolete or rarely used network protocols
  # and ancient filesystems with extensive histories of local privilege escalation vulnerabilities.
  # Safe: None of these are used by modern media services, Web, DNS, mDNS, or WireGuard.
  # NOTE: Optical media drivers (cdrom, sr_mod, udf) and squashfs are intentionally NOT blacklisted
  # to preserve full compatibility with ISO image mounting, DVD/Blu-ray rips, and container tools.
  boot.blacklistedKernelModules = [
    # Obsolete transport and legacy network protocols
    "dccp"      # Datagram Congestion Control Protocol — obsolete transport, attack surface reduction
    "sctp"      # Stream Control Transmission Protocol — telecom protocol, not used in media servers
    "rds"       # Reliable Datagram Sockets — Oracle cluster protocol, attack surface reduction
    "tipc"      # Transparent Inter-Process Communication — cluster protocol, attack surface reduction
    "ax25"      # Amateur Radio AX.25 — obsolete amateur radio protocol
    "netrom"    # Amateur Radio NET/ROM — obsolete amateur radio protocol
    "rose"      # Amateur Radio X.25 PLP — obsolete amateur radio protocol
    "appletalk" # AppleTalk — obsolete legacy Apple network protocol
    "ipx"       # Novell IPX — obsolete legacy NetWare protocol
    "decnet"    # DECnet — obsolete legacy Digital Equipment protocol
    "econet"    # Acorn Econet — obsolete legacy Acorn network protocol

    # Legacy obsolete filesystems (vulnerable to malformed superblock LPE exploits)
    "cramfs"    # Compressed ROM filesystem — obsolete legacy embedded format
    "freevxfs"  # Veritas filesystem — obsolete proprietary Unix format
    "jffs2"     # Journalling Flash File System — obsolete raw NOR/NAND flash format
    "hfs"       # Hierarchical File System — ancient legacy Mac OS format (pre-HFS+)
    "hfsplus"   # HFS+ filesystem — legacy Mac OS X format, not used for modern media
  ];
}
