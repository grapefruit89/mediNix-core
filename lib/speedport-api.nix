# ---
# id: "speedport-api"
# title: "Speedport-API (Python) - WAN-IP ueber Telekom-Router"
# domain: 50
# folder: "lib"
# status: active
# complexity: 1
# last_reviewed: 2026-11-03
# links:
#   adr: ADR-513
# ---
{ lib, python312Packages, fetchPypi }:
python312Packages.buildPythonPackage rec {
  pname = "speedport-api";
  version = "0.6.0";
  pyproject = true;
  src = fetchPypi {
    inherit pname version;
    hash = "sha256-QVewcFQeSfhSNHE++jEVI9ZWTew5hfl9Un47//oIx6c=";
  };
  build-system = [ python312Packages.setuptools ];
  propagatedBuildInputs = [ python312Packages.aiohttp python312Packages.pycryptodome ];
  doCheck = false;
}
