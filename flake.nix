{
  description = "mediNix-core — Portable NixOS Media Stack Module";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url  = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      overlay = _: _: { };  # Zukünftige Pakete hier
      # Registry als JSON für Build-Zeit-Embedding (CLI-Tool)
      registryJson = builtins.toJSON (import ./lib/registry.nix { lib = nixpkgs.lib; }).services;


    in
    {
      # Das Hauptprodukt: importierbar als nixosModules.default
      nixosModules.default = import ./default.nix;
      nixosModules.mediNix = import ./default.nix;  # Alias für Abwärtskompatibilität

      overlays.default = overlay;
    }
    // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = nixpkgs.lib;

        # ── Prüfkonfiguration: evaluiert mediNIX-core ohne echte Hardware ──
        # (Die Ratsche: jeder attribute-missing / Typ-Fehler bricht nix flake check)
        nixosConfigurations.check = lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.default
            {
              grapefruitMedia.enable = true;
              boot.loader.grub.enable = false;
              fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
              system.stateVersion = "24.11";
            }
          ];
        };

        # Dezimalrahmen-Enforcer (ADR-0000): Projektziffer 5, 3-stellige Ordner,
        # keine Duplikate. Nix-native Variante (kein bash grep).
        decimalFrameworkCheck =
          let
            entries    = builtins.readDir ./.;
            isModule   = name: type: type == "directory" && builtins.match "^[0-9]{2}-.*" name != null;
            folders    = builtins.attrNames (lib.filterAttrs isModule entries);
            number     = name: lib.toInt (builtins.head (builtins.match "^([0-9]{2})-.*" name));
            numbers    = map number folders;
            violations = lib.filter (v: v != null) (
              map (name:
                let
                  num     = number name;
                  project = num / 10;
                  problems = lib.concatStringsSep ", " (
                    lib.optional (project != 5) "fuehrende Ziffer ${toString project} != 5"
                  );
                in
                if problems == "" then null else "${name}: ${problems}"
              ) folders
            );
            errors = violations
              ++ lib.optional (lib.length numbers != lib.length (lib.unique numbers)) "doppelte Nummern in den Modulordnern";
          in
          if errors == [ ] then
            pkgs.runCommand "decimal-framework-ok" { } "echo 'ADR-0000 Dezimalrahmen eingehalten' > $out"
          else
            throw ("ADR-0000 (Dezimalrahmen) verletzt:\n  " + lib.concatStringsSep "\n  " errors);

        mkCheck = name: deps: script:
          pkgs.runCommand "check-${name}" { nativeBuildInputs = deps pkgs; } ''
            cd ${self}
            ${script}
            touch $out
          '';
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
                  grapefruitMedia.enable = true;
                  grapefruitMedia.usenet-confinement.enable = true;
                  grapefruitMedia.sabnzbd.enable = true;
                  # Intentionally DO NOT provide grapefruitMedia.vpn.interface
                  boot.loader.grub.enable = false;
                  fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
                  system.stateVersion = "24.11";
                }
              ];
            };
            evalResult = builtins.tryEval testConfig.config.system.build.toplevel.outPath;
          in
          if evalResult.success then
            throw "Negative Test Failed: usenet-confinement enabled without VPN interface should fail to evaluate, but it succeeded!"
          else
            pkgs.runCommand "negative-vpn-ok" {} "echo 'Negative test passed: Fail-Closed assertion triggered' > $out";

        checks.mediNix-smoke = (lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.default
            ./lib/smoke-test.nix
            {
              grapefruitMedia.enable = true;
              boot.loader.grub.enable = false;
              fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
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
          buildInputs = [ pkgs.mkdocs pkgs.python3Packages.mkdocs-material ];
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
