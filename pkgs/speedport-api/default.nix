# ---
# id: "speedport-api"
# title: "Speedport-API (Python) - WAN-IP ueber Telekom-Router"
# domain: 51
# status: active
# complexity: 1
# last_reviewed: 2026-10-26
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
  build-system = with python312Packages; [ setuptools ];
  propagatedBuildInputs = with python312Packages; [ aiohttp pycryptodome ];
  doCheck = false;
}
