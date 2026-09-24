{
  description = "mediNix-core — Portable NixOS Media Stack Module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      overlay = _: _: { }; # Zukünftige Pakete hier
      # Registry als JSON für Build-Zeit-Embedding (CLI-Tool)
      registryJson = builtins.toJSON (import ./lib/registry.nix { inherit (nixpkgs) lib; }).services;

    in
    {
      # Das Hauptprodukt: importierbar als nixosModules.default
      nixosModules.default = import ./default.nix;
      nixosModules.mediNix = import ./default.nix; # Alias für Abwärtskompatibilität

      overlays.default = overlay;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (nixpkgs) lib;

        # ── Prüfkonfiguration: evaluiert mediNIX-core ohne echte Hardware ──
        # (Die Ratsche: jeder attribute-missing / Typ-Fehler bricht nix flake check)
        nixosConfigurations.check = lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.default
            {
              medinix.enable = true;
              # Fail-closed: landing (default on) + ingress need a real trust
              # boundary, so trustedCidrs is mandatory.
              medinix.ingress.trustedCidrs = [
                "10.0.0.0/8"
                "192.168.0.0/16"
              ];
              boot.loader.grub.enable = false;
              fileSystems."/" = {
                device = "none";
                fsType = "tmpfs";
              };
              system.stateVersion = "24.11";
            }
          ];
        };

        # Dezimalrahmen-Enforcer (ADR-0000): Projektziffer 5, 3-stellige Ordner,
        # keine Duplikate. Nix-native Variante (kein bash grep).
        decimalFrameworkCheck =
          let
            entries = builtins.readDir ./.;
            isModule = name: type: type == "directory" && builtins.match "^[0-9]{2}-.*" name != null;
            folders = builtins.attrNames (lib.filterAttrs isModule entries);
            number = name: lib.toInt (builtins.head (builtins.match "^([0-9]{2})-.*" name));
            numbers = map number folders;
            violations = lib.filter (v: v != null) (
              map (
                name:
                let
                  num = number name;
                  project = num / 10;
                  problems = lib.concatStringsSep ", " (
                    lib.optional (project != 5) "fuehrende Ziffer ${toString project} != 5"
                  );
                in
                if problems == "" then null else "${name}: ${problems}"
              ) folders
            );
            errors =
              violations
              ++ lib.optional (
                lib.length numbers != lib.length (lib.unique numbers)
              ) "doppelte Nummern in den Modulordnern";
          in
          if errors == [ ] then
            pkgs.runCommand "decimal-framework-ok" { } "echo 'ADR-0000 Dezimalrahmen eingehalten' > $out"
          else
            throw ("ADR-0000 (Dezimalrahmen) verletzt:\n  " + lib.concatStringsSep "\n  " errors);

        mkCheck =
          name: deps: script:
          pkgs.runCommand "check-${name}" { nativeBuildInputs = deps pkgs; } ''
            cd ${self}
            ${script}
            touch $out
          '';

        baseModules = extra: [
          self.nixosModules.default
          {
            medinix.enable = true;
            boot.loader.grub.enable = false;
            fileSystems."/" = {
              device = "none";
              fsType = "tmpfs";
            };
            system.stateVersion = "24.11";
            # Stack packages (e.g. unrar via sabnzbd) are unfree; check configs
            # only need to evaluate, not to be redistributed.
            nixpkgs.config.allowUnfree = true;
          }
          extra
        ];

        # Negative test WITH reason: the specific assertion (matched by a message
        # substring) must be present AND evaluate to false. Guards against a test
        # that goes green for the wrong cause (e.g. a broken option, not the
        # security invariant under test).
        expectAssertion =
          name: msgNeedle: extra:
          let
            asrt =
              (lib.nixosSystem {
                inherit system;
                modules = baseModules extra;
              }).config.assertions;
            hit = lib.findFirst (a: lib.hasInfix msgNeedle a.message) null asrt;
          in
          if hit == null then
            throw "Negative test ${name}: assertion containing '${msgNeedle}' not found."
          else if hit.assertion then
            throw "Negative test ${name}: assertion '${msgNeedle}' evaluated true (not enforced)."
          else
            pkgs.runCommand "negative-${name}-ok" { } "echo 'ok: ${name} fired for the right reason' > $out";
      in
      {
        # mediNIX Health CLI (Build-Zeit aus Registry generiert)
        packages.medinix = pkgs.callPackage ./lib/cli.nix {
          inherit lib registryJson;
        };

        # Declarative API provisioning for the media stack (from old repo)
        packages.arr-provision = pkgs.callPackage ./lib/arr-provision/default.nix { };

        # ── Ratsche: evaluiert das gesamte Modul mit allen Optionen ─────────
        # Fängt jeden attribute-missing / Typ-Fehler sofort (z.B. falscher
        # Registry-Key, falscher Options-Pfad) — vor dem ersten Deploy.
        checks.nixos-check = nixosConfigurations.check.config.system.build.toplevel;

        # Smoke-Test: Navidrome Unit + Port-Isomorphie (Aufgabe 12 vervollständigt)

        # Negative Test: usenet-confinement without VPN interface must fail
        checks.mediNix-negative-vpn =
          let
            testConfig = lib.nixosSystem {
              inherit system;
              modules = [
                self.nixosModules.default
                {
                  medinix.enable = true;
                  medinix.ingress.trustedCidrs = [
                    "10.0.0.0/8"
                    "192.168.0.0/16"
                  ];
                  medinix.usenet-confinement.enable = true;
                  medinix.sabnzbd.enable = true;
                  # Keep R16 (IPv6) quiet so the missing VPN interface is the
                  # assertion under test.
                  services.vpnKillSwitch.ipv6 = true;
                  # Intentionally DO NOT provide medinix.vpn.interface
                  boot.loader.grub.enable = false;
                  fileSystems."/" = {
                    device = "none";
                    fsType = "tmpfs";
                  };
                  system.stateVersion = "24.11";
                }
              ];
            };
            evalResult = builtins.tryEval testConfig.config.system.build.toplevel.outPath;
          in
          if evalResult.success then
            throw "Negative Test Failed: usenet-confinement enabled without VPN interface should fail to evaluate, but it succeeded!"
          else
            pkgs.runCommand "negative-vpn-ok" { }
              "echo 'Negative test passed: Fail-Closed assertion triggered' > $out";

        # ── Batch C: firewall ownership + emergency allowlist (C1–C6) ──────
        checks.mediNix-negative-emergency-empty =
          expectAssertion "emergency-empty" "empty allowedServices"
            {
              medinix.security.emergencyUser.enable = true;
            };
        checks.mediNix-negative-emergency-unknown = expectAssertion "emergency-unknown" "unknown service" {
          medinix.security.emergencyUser.enable = true;
          medinix.security.emergencyUser.allowedServices = [ "does-not-exist" ];
        };
        checks.mediNix-negative-token-shared = expectAssertion "token-shared" "SEPARATE Cloudflare" {
          medinix.ingress.tls.acmeHost = "example.com";
          medinix.ingress.tls.acmeCredential = "/var/lib/credstore.encrypted/same.cred";
          medinix.dns.ddns.enable = true;
          medinix.dns.ddns.cloudflareTokenCredential = "/var/lib/credstore.encrypted/same.cred";
        };
        # F3: tls.acmeHost must EVALUATE (regression: the former
        # certs.<name>.environment option does not exist in nixpkgs).
        checks.mediNix-acme-positive =
          let
            c =
              (lib.nixosSystem {
                inherit system;
                modules = baseModules {
                  medinix.domain = "example.com";
                  medinix.ingress.trustedCidrs = [ "10.0.0.0/8" ];
                  medinix.authProxyPresent = true;
                  medinix.ingress.tls.acmeHost = "example.com";
                  medinix.ingress.tls.acmeCredential = "/var/lib/credstore.encrypted/cf-acme.cred";
                  medinix.seerr.enable = true;
                };
              }).config;
            cert = c.security.acme.certs."example.com";
          in
          pkgs.runCommand "acme-positive-ok" { } ''
            test "${cert.domain}" = "example.com" || { echo "FAIL: acme cert not rendered"; exit 1; }
            echo "ok: tls.acmeHost evaluates and renders a cert" > $out
          '';
        # 513: the DDNS prune target is the canonical {service}.${cfg.domain},
        # NEVER {service}.${zone}. Regression: domain=home.example.com,
        # zone=example.com, service=seerr => prune seerr.home.example.com,
        # never seerr.example.com.
        checks.mediNix-ddns-prune-fqdn =
          let
            c =
              (lib.nixosSystem {
                inherit system;
                modules = baseModules {
                  medinix.domain = "home.example.com";
                  medinix.ingress.trustedCidrs = [ "10.0.0.0/8" ];
                  medinix.dns.mode = "standalone";
                  medinix.dns.ddns.enable = true;
                  medinix.dns.ddns.zone = "example.com";
                  medinix.dns.ddns.cloudflareTokenCredential = "/var/lib/credstore.encrypted/cf-ddns.cred";
                  medinix.seerr.enable = true;
                };
              }).config;
            script = pkgs.writeText "ddns-script" c.systemd.services.cloudflare-ddns.script;
          in
          pkgs.runCommand "ddns-prune-fqdn-ok"
            {
              nativeBuildInputs = [
                pkgs.gnugrep
                pkgs.coreutils
              ];
            }
            ''
              grep -q 'seerr.home.example.com' ${script} || {
                echo "FAIL: canonical FQDN seerr.home.example.com missing in prune payload"; exit 1;
              }
              if grep -q 'seerr.example.com' ${script}; then
                echo "FAIL: zone-derived name seerr.example.com present in prune payload"; exit 1;
              fi
              echo "ok: DDNS prunes the canonical FQDN, not the zone-derived name" > $out
            '';
        # R7: forward_auth must strip client-supplied identity headers BEFORE
        # copying the trusted ones (header-spoofing regression, checked on the
        # actually rendered Caddyfile).
        checks.mediNix-ingress-header-strip =
          let
            c =
              (lib.nixosSystem {
                inherit system;
                modules = baseModules {
                  medinix.ingress.trustedCidrs = [
                    "10.0.0.0/8"
                    "192.168.0.0/16"
                  ];
                  medinix.ingress.auth.mode = "forward-auth";
                  medinix.ingress.auth.forwardAuthUpstream = "http://127.0.0.1:9999";
                  medinix.authProxyPresent = true;
                  medinix.seerr.enable = true; # public vhost → renders forward_auth
                };
              }).config;
            caddyfile = pkgs.writeText "demo.Caddyfile" c.environment.etc."caddy-media/Caddyfile".text;
          in
          pkgs.runCommand "ingress-header-strip-ok"
            {
              nativeBuildInputs = [
                pkgs.gnugrep
                pkgs.coreutils
              ];
            }
            ''
              f=${caddyfile}
              grep -q 'forward_auth' "$f" || { echo "FAIL: no forward_auth rendered"; exit 1; }
              # F1: the strip MUST be request_header (response-only 'header' does
              # not protect the upstream against client-supplied identity headers).
              grep -q 'request_header' "$f" || { echo "FAIL: strip is not request_header"; exit 1; }
              req=$(grep -n 'request_header' "$f" | head -1 | cut -d: -f1)
              strip=$(grep -n -- '-Remote-User' "$f" | head -1 | cut -d: -f1)
              fa=$(grep -n 'forward_auth' "$f" | head -1 | cut -d: -f1)
              [ -n "$req" ] && [ -n "$strip" ] && [ -n "$fa" ] || { echo "FAIL: missing block"; exit 1; }
              [ "$req" -lt "$strip" ] && [ "$strip" -lt "$fa" ] \
                || { echo "FAIL: order request_header($req) < strip($strip) < forward_auth($fa) violated"; exit 1; }
              echo "ok: identity headers stripped on the REQUEST before forward_auth" > $out
            '';

        # R15: a uid mismatch between registry and instance must fail — the
        # nftables `skuid` would otherwise target the wrong process.
        checks.mediNix-negative-uid-chain = expectAssertion "uid-chain" "R15 identity chain broken" {
          medinix.ingress.trustedCidrs = [
            "10.0.0.0/8"
            "192.168.0.0/16"
          ];
          medinix.vpn.enable = true;
          medinix.usenet-confinement.enable = true;
          medinix.sabnzbd.enable = true;
          services.vpnKillSwitch.ipv6 = true;
          services.vpnKillSwitch.instances.sabnzbd = lib.mkForce {
            enable = true;
            uid = 1;
          };
        };
        # R16: killswitch active + IPv6 enabled on the host + ipv6 = false
        # must fail (no unfiltered IPv6 escape).
        checks.mediNix-negative-vpn-ipv6 = expectAssertion "vpn-ipv6" "R16 fail-open IPv6" {
          medinix.ingress.trustedCidrs = [
            "10.0.0.0/8"
            "192.168.0.0/16"
          ];
          medinix.vpn.enable = true;
          medinix.usenet-confinement.enable = true;
          medinix.sabnzbd.enable = true;
        };
        # F4: landing enabled + empty trustedCidrs must fail (landing must not
        # bypass the CIDR trust boundary).
        checks.mediNix-negative-landing-cidrs = expectAssertion "landing-cidrs" "trustedCidrs is empty" {
          medinix.ingress.landing.enable = true;
        };
        # F5: forward-auth without an explicit upstream must fail (Pocket-ID is
        # an OIDC OP, not a forward-auth proxy).
        checks.mediNix-negative-forward-auth-upstream =
          expectAssertion "forward-auth-upstream" "explicit forward-auth"
            {
              medinix.ingress.auth.mode = "forward-auth";
            };
        # F6: the acmeHost cert must cover the domain (else TLS breaks runtime).
        checks.mediNix-negative-acme-domain = expectAssertion "acme-domain" "does not cover" {
          medinix.domain = "other.net";
          medinix.ingress.tls.acmeHost = "example.com";
          medinix.ingress.tls.acmeCredential = "/var/lib/credstore.encrypted/cf-acme.cred";
        };
        # F2 regression: *arr's AUTH__METHOD must follow the RESOLVED vhost
        # exposure — External only behind forward_auth (public), never on
        # internal (where 511 renders no forward_auth).
        checks.mediNix-arr-auth-method =
          let
            common = {
              medinix.ingress.trustedCidrs = [
                "10.0.0.0/8"
                "192.168.0.0/16"
              ];
              medinix.ingress.auth.mode = "forward-auth";
              medinix.ingress.auth.forwardAuthUpstream = "http://127.0.0.1:4180";
              medinix.authProxyPresent = true;
              medinix.sonarr.enable = true;
            };
            authOf =
              extra:
              (lib.nixosSystem {
                inherit system;
                modules = baseModules common ++ [ extra ];
              }).config.systemd.services.sonarr.environment.SONARR__AUTH__METHOD;
            internal = authOf { };
            public = authOf { medinix.ingress.vhosts."sonarr".accessGroup = lib.mkForce "public"; };
          in
          pkgs.runCommand "arr-auth-method-ok" { } ''
            test "${internal}" = "Forms" || { echo "FAIL: internal sonarr AUTH__METHOD=${internal} (want Forms)"; exit 1; }
            test "${public}" = "External" || { echo "FAIL: public sonarr AUTH__METHOD=${public} (want External)"; exit 1; }
            echo "ok: arr auth method follows the resolved vhost exposure" > $out
          '';

        # H12b: standalone mode must own caddy-media ONLY. A phantom
        # systemd.services.caddy (511 set OOMScoreAdjust on the unit path with
        # mkIf on the value) must never materialize; global mode keeps it.
        checks.mediNix-caddy-single-owner =
          let
            cfgOf =
              extra:
              (lib.nixosSystem {
                inherit system;
                modules = baseModules (
                  {
                    medinix.ingress.trustedCidrs = [ "10.0.0.0/8" ];
                  }
                  // extra
                );
              }).config;
            standalone = cfgOf { medinix.ingress.mode = "standalone"; };
            global = cfgOf {
              medinix.ingress.mode = "global";
              services.caddy.enable = true;
            };
          in
          if standalone.systemd.services ? caddy then
            throw "H12b: standalone materialized a phantom systemd.services.caddy."
          else if !(standalone.systemd.services ? caddy-media) then
            throw "H12b: standalone is missing the caddy-media unit."
          else if !(global.systemd.services ? caddy) then
            throw "H12b: global mode is missing the systemd.services.caddy unit."
          else if global.systemd.services.caddy.serviceConfig.OOMScoreAdjust != -900 then
            throw "H12b: global caddy unit lost its OOMScoreAdjust."
          else
            pkgs.runCommand "caddy-single-owner-ok" { } ''
              echo 'ok: standalone => caddy-media only; global => caddy (+OOMScoreAdjust)' > $out
            '';

        # H28: mediNix-owned InaccessiblePaths must be existence-tolerant
        # ("-" prefix, systemd.exec). Without it a missing path (/run/secrets,
        # or a foreign /var/lib/<svc> before its first run) aborts the unit with
        # 226/NAMESPACE at mount-namespace setup.
        checks.mediNix-inaccessible-paths-optional =
          let
            c =
              (lib.nixosSystem {
                inherit system;
                modules = baseModules {
                  medinix.ingress.trustedCidrs = [ "10.0.0.0/8" ];
                  medinix.sabnzbd.enable = true;
                  medinix.jellyfin.enable = true;
                  medinix.audiobookshelf.enable = true;
                  medinix.navidrome.enable = true;
                };
              }).config;
            watched = [
              "caddy-media"
              "sabnzbd"
              "jellyfin"
              "audiobookshelf"
              "navidrome"
            ];
            entries = lib.flatten (
              map (n: c.systemd.services.${n}.serviceConfig.InaccessiblePaths or [ ]) watched
            );
            bad = lib.filter (e: !(lib.hasPrefix "-" e)) entries;
          in
          if bad == [ ] then
            pkgs.runCommand "inaccessible-paths-optional-ok" { } ''
              echo 'ok: all mediNix InaccessiblePaths are existence-tolerant (- prefix)' > $out
            ''
          else
            throw "H28: InaccessiblePaths without '-' prefix (aborts unit when path is missing): ${toString bad}";

        checks.mediNix-firewall-managed =
          let
            c =
              (lib.nixosSystem {
                inherit system;
                modules = baseModules { medinix.hostIntegration.firewall = "managed"; };
              }).config;
          in
          if c.networking.firewall.enable then
            pkgs.runCommand "firewall-managed-ok" { } "echo 'ok: firewall=managed enables the firewall' > $out"
          else
            throw "C1 failed: hostIntegration.firewall = managed did not enable networking.firewall.enable.";

        checks.mediNix-smoke =
          (lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.default
              ./lib/smoke-test.nix
              {
                medinix.enable = true;
                boot.loader.grub.enable = false;
                fileSystems."/" = {
                  device = "none";
                  fsType = "tmpfs";
                };
                system.stateVersion = "24.11";
              }
            ];
          }).config.system.build.toplevel;

        # ── Dezimalrahmen-Enforcer (Priorität 1, neben der Ratsche) ─────────
        checks.decimal-framework = decimalFrameworkCheck;

        # ── Linting (Priorität 2): kopiert aus devNIX mkCheck-Pattern ───────
        checks.nixfmt-check = mkCheck "nixfmt" (pkgs: [ pkgs.nixfmt-rfc-style ]) ''
          nixfmt --check $(find . -name '*.nix' -not -path './.git/*') \
            || { echo ""; echo "Nicht formatiert. Beheben mit:  nix fmt"; exit 1; }
        '';

        checks.statix-check = mkCheck "statix" (pkgs: [ pkgs.statix ]) ''
          statix check . \
            || { echo ""; echo "Beheben mit:  statix fix ."; exit 1; }
        '';

        checks.deadnix-check = mkCheck "deadnix" (pkgs: [ pkgs.deadnix ]) ''
          deadnix --fail . \
            || { echo ""; echo "Beheben mit:  deadnix --edit ."; exit 1; }
        '';

        # ── Formatter + devShell (Priorität 3) ──────────────────────────────
        formatter = pkgs.nixfmt-rfc-style;

        # Knowledge Base Build
        packages.docs = pkgs.stdenv.mkDerivation {
          name = "medinix-docs";
          src = ./.;
          buildInputs = [
            pkgs.mkdocs
            pkgs.python3Packages.mkdocs-material
          ];
          buildPhase = ''
            cd docs
            mkdocs build --site-dir ../site
            cd ..
          '';
          installPhase = ''
            mkdir -p $out
            cp -r site/* $out/
          '';
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nixfmt-rfc-style
            statix
            deadnix
            nix-tree
            jq
            mkdocs
            python3Packages.mkdocs-material
          ];
          shellHook = ''
            echo "Run 'cd docs && mkdocs serve' to view the knowledge base."
          '';
        };
      }
    );
}
