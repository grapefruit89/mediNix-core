# ---
# id: "arr-provision"
# title: "arr-provision — Vereinheitlichte CLI fuer deklarative *arr/Seerr-API-Provisionierung"
# domain: 50
# folder: "packages/arr-provision"
# status: active
# kind: package
# complexity: 3
# last_reviewed: 2026-11-26
# links:
#   adr: ADR-0010
# tags: ["media", "arr", "provisioning"]
# ---
{
  lib,
  python3,
  stdenv,
}:

let
  arrRoot = lib.cleanSource ./.;

  legacyEntrypoints = [
    "arr-sync-keys"
    "arr-sync-settings"
    "arr-sync-download-clients"
    "arr-sync-prowlarr"
    "arr-sync-locale"
    "arr-sync-profiles"
    "arr-sync-jellyfin"
    "arr-sync-seerr"
  ];
in
stdenv.mkDerivation {
  pname = "arr-provision";
  version = "2.0.0";
  src = arrRoot;

  nativeBuildInputs = [ python3 ];
  doCheck = true;

  checkPhase = ''
    runHook preCheck
    PYTHONPATH="$PWD" ${python3}/bin/python3 -m unittest discover -s tests -q
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    pkgDir="$out/lib/arr-provision"
    mkdir -p "$out/bin" "$pkgDir"
    cp -r arr_provision "$pkgDir/"

    cat > "$out/bin/arr-provision" <<EOF
    #!${stdenv.shell}
    export PYTHONPATH="$pkgDir\''${PYTHONPATH:+:\$PYTHONPATH}"
    exec -a "\$0" ${python3}/bin/python3 -m arr_provision "\$@"
    EOF
    chmod 0755 "$out/bin/arr-provision"

    # Abwaertskompatible BusyBox-Symlinks (cli.py wertet argv[0] aus)
    for alias in ${lib.concatStringsSep " " legacyEntrypoints}; do
      ln -s arr-provision "$out/bin/$alias"
    done
    runHook postInstall
  '';

  passthru.tests = stdenv.mkDerivation {
    pname = "arr-provision-tests";
    version = "2.0.0";
    src = arrRoot;
    nativeBuildInputs = [ python3 ];
    dontConfigure = true;
    installPhase = ''
      PYTHONPATH="$PWD" ${python3}/bin/python3 -m unittest discover -s tests -q
      mkdir -p "$out"
      touch "$out/pass"
    '';
  };

  meta = {
    description = "Unified event-driven API provisioning for the mediNix media stack";
    mainProgram = "arr-provision";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
