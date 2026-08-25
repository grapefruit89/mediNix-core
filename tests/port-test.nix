{ pkgs, ... }:

pkgs.nixosTest {
  name = "medinix-port-binding-test";

  nodes.machine = { config, lib, ... }: {
    imports = [
      ../default.nix
    ];
    
    medinix = {
      enable = true;
      hostIntegration.reverseProxy = "managed";
      hostIntegration.nftables = "managed";
      hostIntegration.storage = "managed";
      
      # Aktiviere alle Dienste, um sicherzustellen, dass sie binden
      jellyfin.enable = true;
      sabnzbd.enable = true;
      prowlarr.enable = true;
      audiobookshelf.enable = true;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    
    # Warte bis die Dienste laufen
    machine.wait_for_unit("jellyfin.service")
    machine.wait_for_unit("sabnzbd.service")
    machine.wait_for_unit("caddy.service")

    # Hole alle lauschenden TCP-Sockets
    # ss -tln outputs e.g.: LISTEN 0 128 127.0.0.1:8096 0.0.0.0:*
    sockets = machine.succeed("ss -tln | grep LISTEN")

    # Caddy darf auf 0.0.0.0 oder :: binden (Port 80/443).
    # Alle anderen MSSEN 127.0.0.1 oder ::1 sein.
    for line in sockets.strip().split("\n"):
        parts = line.split()
        local_address_port = parts[3]
        
        # Ignoriere sshd (Port 22)
        if ":22" in local_address_port:
            continue
            
        # Caddy proxy darf global binden
        if ":80" in local_address_port or ":443" in local_address_port:
            continue
            
        # Prfe, ob die Adresse lokal ist
        if not (local_address_port.startswith("127.0.0.1:") or local_address_port.startswith("[::1]:")):
            raise Exception(f"Sicherheitsleck! Ein Dienst bindet auf einem nicht-lokalen Interface: {line}")
            
    print("Port-Bindungs-Test erfolgreich! Alle Dienste sind im Loopback isoliert.")
  '';
}
