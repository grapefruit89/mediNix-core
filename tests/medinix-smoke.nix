{ pkgs, inputs }:

let
  testPkgs = import pkgs.path {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };
in
testPkgs.testers.runNixOSTest {
  name = "medinix-smoke-test";
  nodes.server =
    { pkgs, lib, ... }:
    {
      imports = [ inputs.self.nixosModules.default ];
      medinix = {
        enable = true;
        host.domain = "example.com";
        ingress.trustedCidrs = [
          "10.0.0.0/8"
          "192.168.0.0/16"
        ];
        storage.mediaRoot = "/tmp/media";
        storage.downloadDir = "/tmp/downloads";
        secrets.cloudflareEnvFile = pkgs.writeText "cf.env" "CF_DNS_API_TOKEN=fake";
        jellyfin.adminPasswordFile = pkgs.writeText "jf-admin.cred" "pass123";
        manifest.seerr.allowUnauthenticated = true;
        seerr.enable = true;
        jellyfin.enable = true;

        # VPN Confinement & SABnzbd Deadswitch
        vpn.interface = "wg0";
        vpn.dnsServers = [ "10.64.0.1" ];
        usenet-confinement.enable = true;
        sabnzbd.enable = true;
      };

      networking.interfaces.wg0.virtual = true;
      networking.nftables.enable = true;
      services.vpnKillSwitch.vpnInterface = "wg0";
      services.vpnKillSwitch.dnsServers = [ "10.64.0.1" ];
      services.vpnKillSwitch.ipv6 = true;

      environment.systemPackages = [ pkgs.curl ];

      # Headless test runner overrides
      boot.loader.grub.enable = false;
      fileSystems."/tmp/media" = {
        device = "none";
        fsType = "tmpfs";
      };
      fileSystems."/tmp/downloads" = {
        device = "none";
        fsType = "tmpfs";
      };
    };
  testScript = ''
    machine = server

    server.wait_for_unit("multi-user.target")
    server.wait_for_unit("jellyfin.service")
    server.wait_for_unit("seerr.service")

    # Mathematische Dezimal-Ports verifizieren (Jellyfin: 5510, Seerr: 5610)
    server.wait_for_open_port(5510)
    server.wait_for_open_port(5610)

    # API & Identitaet verifizieren
    server.succeed("curl -s -f http://127.0.0.1:5610/api/v1/status")
    uid = server.succeed("id -u jellyfin").strip()
    assert uid == "5510", f"Invariante verletzt: UID ist {uid}"

    # VPN-Deadswitch Szenario für SABnzbd & wg0
    machine.wait_for_unit("sabnzbd.service")
    machine.succeed("systemctl is-active sabnzbd.service")
    machine.fail("su -s /bin/sh sabnzbd -c 'curl --interface eth0 --connect-timeout 2 http://1.1.1.1'")
    machine.execute("ip link set dev wg0 down")
    machine.wait_until_fails("systemctl is-active sabnzbd.service")
  '';
}
