{ pkgs, inputs }:

pkgs.testers.runNixOSTest {
  name = "medinix-smoke-test";
  nodes.server =
    { pkgs, ... }:
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
        secrets.cloudflareEnvFile = pkgs.writeText "cf.env" "CF_DNS_API_TOKEN=fake";
        jellyfin.adminPasswordFile = pkgs.writeText "jf-admin.cred" "pass123";
        manifest.seerr.allowUnauthenticated = true;
        seerr.enable = true;
        jellyfin.enable = true;
      };
      # Headless test runner overrides
      boot.loader.grub.enable = false;
      fileSystems."/tmp/media" = {
        device = "none";
        fsType = "tmpfs";
      };
    };
  testScript = ''
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
  '';
}
