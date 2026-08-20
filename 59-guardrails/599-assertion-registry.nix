# ---
# id: "590-registry"
# title: "Central Error Registry (Invariants + Assertion Errors)"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-13
# links:
#   adr: ADR-0000 (Dezimalrahmen Constitution)
# ---
{ lib, ... }@args:

let
  invariants = {
    "INV-01" = {
      what = "Port = ServiceNumber × 10. Violation means Dezimalrahmen breach.";
      expected = "Port matches Dezimalrahmen";
      found = "Deviating port configured";
      fix = "Comply with Dezimalrahmen (Port = ServiceNumber * 10)";
      ref = "ADR-0000";
    };
    "INV-02" = {
      what = "All services bind to 127.0.0.1. Never 0.0.0.0 on WAN.";
      expected = "127.0.0.1 Binding via Environment variables";
      found = "0.0.0.0 WAN Binding possible";
      fix = "Set LocalNetworkAddresses to 127.0.0.1";
      ref = "ADR-0000";
    };
    "INV-03" = {
      what = "GID 5000 = media. No service uses a different media GID.";
      expected = "GID 5000 (media)";
      found = "Deviating GID configured";
      fix = "Enforce Group=media (5000)";
      ref = "ADR-0000";
    };
    "INV-05" = {
      what = "No secret resides in the Nix store (/nix/store/).";
      expected = "wgConf path outside of the store";
      found = "/nix/store/ Prefix";
      fix = "Change paths to /var/lib or sops-nix";
      ref = "ADR-0000";
    };
    "INV-06" = {
      what = "stream services are never reachable on WAN without TLS.";
      expected = "tls.mode != off";
      found = "tls.mode = off on WAN";
      fix = "Enable TLS or remove service from WAN";
      ref = "ADR-0000";
    };
    "INV-07" = {
      what = "No service requiring /dev/dri has PrivateDevices = true.";
      expected = "PrivateDevices = false";
      found = "PrivateDevices = true blocks GPU";
      fix = "Disable PrivateDevices for this service";
      ref = "ADR-0000";
    };
    "INV-SECRET" = {
      what = "No secret lands in the Nix store. All paths via .cred files (TPM).";
      expected = "All secrets loaded via LoadCredential";
      found = "Secret path begins with /nix/store/";
      fix = "Use systemd LoadCredential";
      ref = "ADR-0000";
    };
    "INV-VPN-02" = {
      what = "vpn.dns does not exist — only vpn.dnsServers. Prevent phantom option.";
      expected = "Use vpn.dnsServers";
      found = "vpn.dns is defined";
      fix = "Rename option to vpn.dnsServers";
      ref = "ADR-0000";
    };
    "INV-VPN-04" = {
      what = "vpn.dnsServers entries must syntactically be IPs (IPv4 or IPv6).";
      expected = "IPv4 or IPv6 Format";
      found = "Possible hostname";
      fix = "Only enter IP addresses";
      ref = "ADR-0000";
    };
    "INV-TLS-02" = {
      what = "acmeHost set → TLS directive must appear in both global AND standalone Caddy mode.";
      expected = "TLS in both scopes";
      found = "Missing TLS directive";
      fix = "Configure both";
      ref = "ADR-0000";
    };
    "INV-UMASK-01" = {
      what = "dotnet profile services must have UMask=0002 (Arr needs group write permission).";
      expected = "UMask=0002";
      found = "Incorrect or missing UMask";
      fix = "Set systemd.services.<name>.serviceConfig.UMask = \"0002\"";
      ref = "ADR-0000";
    };
    "INV-TECH-01" = {
      what = "Docker is forbidden. mediNix-core uses systemd-native.";
      expected = "virtualisation.docker.enable = false";
      found = "Docker enabled";
      fix = "Refactor to systemd-native";
      ref = "NO-CONTAINERS.md";
    };
    "INV-TECH-02" = {
      what = "Podman is forbidden. Same reason as INV-TECH-01.";
      expected = "virtualisation.podman.enable = false";
      found = "Podman enabled";
      fix = "Refactor to systemd-native";
      ref = "NO-CONTAINERS.md";
    };
    "INV-TECH-03" = {
      what = "cron is forbidden. Use systemd.timers.";
      expected = "services.cron.enable = false";
      found = "cron enabled";
      fix = "Use systemd.timers";
      ref = "NO-CONTAINERS.md";
    };
    "INV-TECH-04" = {
      what = "iptables is forbidden. Use nftables exclusively.";
      expected = "networking.firewall.package = pkgs.nftables";
      found = "iptables active";
      fix = "Disable iptables or explicitly enable nftables backend";
      ref = "NO-CONTAINERS.md";
    };
    "INV-TECH-05" = {
      what = "sops-nix is forbidden. Use systemd LoadCredential instead.";
      expected = "sops = {} (empty or unused)";
      found = "sops-nix usage detected";
      fix = "Migrate to systemd LoadCredential Encrypted";
      ref = "NO-CONTAINERS.md";
    };
    "INV-DNS-01" = {
      what = "Encrypted DNS (DoT) must be active to prevent leaks.";
      expected = "dnsovertls = true or opportunistic";
      found = "DoT is off or missing";
      fix = "Enable services.resolved.dnsovertls";
      ref = "ADR-0000";
    };
    "INV-FW-01" = {
      what = "NFTables firewall must be active (for VPN UID kill switch).";
      expected = "networking.nftables.enable = true";
      found = "Firewall off";
      fix = "Enable nftables";
      ref = "ADR-0000";
    };
    "INV-STG-01" = {
      what = "No backend path may reside in the Nix store.";
      expected = "All backend paths outside of /nix/store";
      found = "Backend path begins with /nix/store/";
      fix = "Create physical mounts as host fileSystems (e.g., /mnt/ssd)";
      ref = "ADR-5710";
    };
    "INV-STG-02" = {
      what = "storage.mediaRoot must not reside in the Nix store.";
      expected = "mediaRoot outside of /nix/store";
      found = "mediaRoot begins with /nix/store/";
      fix = "Set storage.mediaRoot to a state path (e.g., /data)";
      ref = "ADR-5710";
    };
  };

  errors = {
    "VPN-001" = {
      what = "vpn.interface is empty — no UID routing possible.";
      expected = "Interface name set";
      found = "vpn.interface is empty";
      fix = "Configure grapefruitMedia.vpn.interface";
      ref = "5410";
    };
    "VPN-002" = {
      what = "vpn.dnsServers is empty — DNS leak through host resolver possible.";
      expected = "At least one DNS server set";
      found = "Empty list for vpn.dnsServers";
      fix = "Configure grapefruitMedia.vpn.dnsServers";
      ref = "5410";
    };
    "VPN-003" = {
      what = "usenet-confinement active but neither sabnzbd nor prowlarr enabled.";
      expected = "At least sabnzbd or prowlarr enabled";
      found = "No Usenet service active";
      fix = "Enable services or turn off usenet-confinement";
      ref = "5410";
    };
    "VPN-005" = {
      what = "vpn.wgConf resides in the Nix store — private key is world-readable.";
      expected = "wgConf outside of the store";
      found = "/nix/store/ Prefix";
      fix = "Set wgConf path to a state folder";
      ref = "5410";
    };
    "VPN-006" = {
      what = "POLICY: DNS Allowlist for the sandbox (only local or VPN-internal resolvers).";
      expected = "IPs starting with 10.x, 127.x or fd (IPv6)";
      found = "Disallowed (Public) resolver configured";
      fix = "Use only allowed DNS networks or extend policy in 599-cross-domain.nix";
      ref = "5410";
    };
    "TLS-001" = {
      what = "tls.acmeHost and tls.certFile both set — only one allowed.";
      expected = "Only one TLS source";
      found = "Both sources configured";
      fix = "Remove acmeHost or certFile";
      ref = "5111";
    };
    "TLS-002" = {
      what = "tls.mode = custom but certFile or keyFile is missing.";
      expected = "Both files defined";
      found = "One or both missing";
      fix = "Set tls.certFile and tls.keyFile";
      ref = "5111";
    };
    "TLS-003" = {
      what = "stream services active but tls.mode = off — no TLS for WAN.";
      expected = "tls.mode != off";
      found = "tls.mode = off";
      fix = "Enable TLS or restrict services locally";
      ref = "5111";
    };
    "AUTH-001" = {
      what = "ingress.auth.mode = forward-auth but authProxyPresent = false.";
      expected = "authProxyPresent = true";
      found = "authProxyPresent = false";
      fix = "Enable authentication service";
      ref = "5120";
    };
    "DNS-001" = {
      what = "DDNS active but no token configured.";
      expected = "ddns.token set";
      found = "Token is null";
      fix = "Configure token via sops-nix";
      ref = "5130";
    };
    "SEC-001" = {
      what = "CrowdSec active but enrollKeyFile missing.";
      expected = "enrollKeyFile set";
      found = "No Keyfile defined";
      fix = "Configure grapefruitMedia.observability.crowdsec.enrollKeyFile";
      ref = "5820";
    };
    "SEC-002" = {
      what = "networking.firewall.enable = false — nftables rules do not apply.";
      expected = "networking.firewall.enable = true";
      found = "Firewall is deactivated";
      fix = "Turn on firewall";
      ref = "5200";
    };
    "STORE-001" = {
      what = "storage.mediaRoot is empty.";
      expected = "Valid path";
      found = "Empty path";
      fix = "Configure storage.mediaRoot";
      ref = "5010";
    };
    "STORE-002" = {
      what = "storage.metadataDir lies on HDD — SSD recommended.";
      expected = "Path on SSD";
      found = "Possible HDD path";
      fix = "Move to fast storage";
      ref = "5010";
    };
    "STORE-003" = {
      what = "sqlite.backupDir must not reside in the Nix store.";
      expected = "Backup outside of /nix/store";
      found = "Path begins with /nix/store/";
      fix = "Use a path in /var/lib or sops-nix";
      ref = "5720";
    };
    "STG-001" = {
      what = "storage.backends.cold set but storage.backends.hot missing.";
      expected = "hot must be set if cold is set";
      found = "cold without hot — no meaningful tiering possible";
      fix = "Set grapefruitMedia.storage.backends.hot = \"/mnt/ssd\"";
      ref = "5710";
    };
    "STG-002" = {
      what = "VPN enabled but vpn.peer.publicKey is empty.";
      expected = "publicKey set";
      found = "publicKey is empty string";
      fix = "Set grapefruitMedia.vpn.peer.publicKey";
      ref = "5260";
    };
    "STG-003" = {
      what = "VPN enabled but vpn.address is empty — interface would have no IP.";
      expected = "At least one CIDR address in vpn.address";
      found = "vpn.address = []";
      fix = "Set grapefruitMedia.vpn.address = [ \"10.64.0.2/32\" ]";
      ref = "5260";
    };
    "STG-004" = {
      what = "VPN enabled but vpn.privateKeyCredentialPath missing.";
      expected = "Path to .cred file set";
      found = "vpn.privateKeyCredentialPath = null";
      fix = "Encrypt credential: systemd-creds encrypt --with-key=tpm2+host keyfile out.cred";
      ref = "5260";
    };
    "STG-005" = {
      what = "vpn.useExistingInterface = true but vpn.interface is empty.";
      expected = "vpn.interface set (e.g. \"wg0\")";
      found = "vpn.interface is empty string";
      fix = "Set grapefruitMedia.vpn.interface = \"wg0\" (Legacy mode)";
      ref = "5260";
    };
    "ACME-001" = {
      what = "acmeHost set but no Cloudflare token configured.";
      expected = "tls.acmeCredential or dns.ddns.cloudflareTokenCredential set";
      found = "All token sources are null";
      fix = "Set grapefruitMedia.ingress.tls.acmeCredential = \"/var/lib/credstore.encrypted/cf-acme.cred\"";
      ref = "5140";
    };
  };

  formatMessage = prefix: code: data:
    "[mediNix-core/${prefix}/${code}] ${data.what}\n" +
    "  Expected: ${data.expected}\n" +
    "  Found: ${data.found}\n" +
    "  Fix: ${data.fix}\n" +
    "  Ref: ${data.ref}";

  mkInvariant = code: condition: {
    assertion = condition;
    message = formatMessage "INVARIANT" code invariants.${code};
  };

  mkError = code: condition: {
    assertion = condition;
    message = formatMessage "CODE" code errors.${code};
  };

  mkErrorDoc = code: condition: adr: {
    assertion = condition;
    # For mkErrorDoc we overwrite the ref field of the registry with the passed ADR link
    message = formatMessage "CODE" code (errors.${code} // { ref = "ADR-${adr}"; });
  };
in
if args ? config then
  { }
else
  {
    inherit invariants errors mkInvariant mkError mkErrorDoc;
  }
