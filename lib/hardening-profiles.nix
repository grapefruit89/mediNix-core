# ---
# id: "hardening-profiles"
# title: "Systemd hardening profiles"
# domain: 50
# last_reviewed: 2026-09-02
# adr: ADR-5050
# ---
# Bind policy (SocketBind*) is independent from egress policy (IPAddress*).
# 526 marks packets by UID and drops anything not leaving via the VPN iface.
# IPAddressDeny=any with only loopback allow runs in cgroup eBPF *before*
# routing — that vetoes NNTP even when the killswitch is perfect.
# RestrictAddressFamilies lives on `base`. Do not drop AF_NETLINK on network
# units (resolve, wg, nft helpers). Scripts get AF_UNIX only.
{ lib }:

rec {
  networkPolicy.loopback = {
    IPAddressDeny = [ "any" ];
    IPAddressAllow = [ "127.0.0.1" "::1" ];
    SocketBindDeny = [ "any" ];
    SocketBindAllow = [ "127.0.0.1" "::1" ];
  };
  # Connect anywhere; still bind only localhost. 526 is the WAN choke.
  networkPolicy.internet = {
    IPAddressDeny = [ "any" ];
    IPAddressAllow = [ "127.0.0.1" "::1" "0.0.0.0/0" "::/0" ];
    SocketBindDeny = [ "any" ];
    SocketBindAllow = [ "127.0.0.1" "::1" ];
  };
  networkPolicy.proxy = {
    SocketBindAllow = [ "any" ];
  };

  base = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    UMask = lib.mkDefault "0027";
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectProc = "invisible";
    ProcSubset = "pid";
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    SystemCallFilter = [ "@system-service" ];
    SystemCallErrorNumber = "EPERM";
    SystemCallArchitectures = [ "native" ];
    ProtectClock = true;
    ProtectHostname = true;
    RemoveIPC = true;
    OOMScoreAdjust = 500;
    RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
    PrivateUsers = true;
    CapabilityBoundingSet = [ "" ];
    AmbientCapabilities = [ "" ];
    Restart = "on-failure";
    RestartSec = "5s";
    InaccessiblePaths = [
      "/root"
      "/home"
      "/boot"
      "/etc/shadow"
      "/etc/ssh"
      "/run/secrets"
    ];
  };

  dotnet = base // {
    MemoryDenyWriteExecute = false;
    PrivateDevices = true;
    UMask = lib.mkDefault "0002";
  } // networkPolicy.internet;

  # VA-API /dev/dri lives in the host user namespace. PrivateUsers would
  # hide the render node from the jellyfin uid even with DeviceAllow.
  dotnet-gpu = dotnet // {
    PrivateDevices = false;
    PrivateUsers = false;
  } // networkPolicy.internet;

  # SABnzbd: bind 127.0.0.1, talk to NNTP anywhere. Path is 526, not eBPF deny.
  python = base // {
    MemoryDenyWriteExecute = true;
    PrivateDevices = true;
  } // networkPolicy.internet;

  nodejs = base // {
    MemoryDenyWriteExecute = false;
    PrivateDevices = true;
  } // networkPolicy.internet;

  network = base // {
    MemoryDenyWriteExecute = true;
    PrivateDevices = true;
    PrivateUsers = false;
    AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
    CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
    OOMScoreAdjust = -500;
  } // networkPolicy.proxy;

  client = base // {
    MemoryDenyWriteExecute = true;
    PrivateDevices = true;
    PrivateNetwork = false;
  };

  script = base // {
    MemoryDenyWriteExecute = true;
    PrivateDevices = true;
    PrivateNetwork = true;
    RestrictAddressFamilies = [ "AF_UNIX" ];
  } // networkPolicy.loopback;
}
