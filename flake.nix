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

      # ── devNIX-Pattern: mkCheck (CI wird rot, nie der Baum) ───────────────
      # Helper: lässt ein Werkzeug über dem Repo laufen. --check/--fail ändert
      # nichts, meldet nur. Übernommen aus grapefruit89/devNIX (ADR-8000).
      mkCheck =
        name: deps: script:
        nixpkgs.lib.mapAttrs' (_: system:
          let pkgs = nixpkgs.legacyPackages.${system}; in
          pkgs.runCommand "check-${name}" { nativeBuildInputs = deps pkgs; } ''
            cd ${self}
            ${script}
            touch $out
          ''
        );
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
            isModule   = name: type: type == "directory" && builtins.match "^[0-9]{3}-.*" name != null;
            folders    = builtins.attrNames (lib.filterAttrs isModule entries);
            number     = name: lib.toInt (builtins.head (builtins.match "^([0-9]{3})-.*" name));
            numbers    = map number folders;
            violations = lib.filter (v: v != null) (
              map (name:
                let
                  num     = number name;
                  project = num / 100;
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
      in
      {
        # mediNIX Health CLI (Build-Zeit aus Registry generiert)
        packages.medinix = pkgs.callPackage ./packages/mediNix-cli {
          inherit lib registryJson;
        };

        # ── Ratsche: evaluiert das gesamte Modul mit allen Optionen ─────────
        # Fängt jeden attribute-missing / Typ-Fehler sofort (z.B. falscher
        # Registry-Key, falscher Options-Pfad) — BEVOR es auf q958 deployed wird.
        checks.nixos-check = nixosConfigurations.check.config.system.build.toplevel;

        # Smoke-Test: Navidrome Unit + Port-Isomorphie (Aufgabe 12 vervollständigt)
        checks.mediNix-smoke = (lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.default
            ./tests/smoke-test.nix
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
        checks.nixfmt-check = (mkCheck "nixfmt" (pkgs: [ pkgs.nixfmt-rfc-style ]) ''
          nixfmt --check $(find . -name '*.nix' -not -path './.git/*') \
            || { echo ""; echo "Nicht formatiert. Beheben mit:  nix fmt"; exit 1; }
        '') .${system};

        checks.statix-check = (mkCheck "statix" (pkgs: [ pkgs.statix ]) ''
          statix check . \
            || { echo ""; echo "Beheben mit:  statix fix ."; exit 1; }
        '') .${system};

        checks.deadnix-check = (mkCheck "deadnix" (pkgs: [ pkgs.deadnix ]) ''
          deadnix --fail . \
            || { echo ""; echo "Beheben mit:  deadnix --edit ."; exit 1; }
        '') .${system};

        # ── Formatter + devShell (Priorität 3) ──────────────────────────────
        formatter = pkgs.nixfmt-rfc-style;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nixfmt-rfc-style  # nix fmt
            statix            # statix check .
            deadnix           # deadnix --fail .
            nix-tree          # Dependency-Visualizer
            jq
          ];
        };
      }
    );
}
