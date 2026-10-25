{ lib
, buildPythonPackage
, fetchPypi
, aiohttp
, pycryptodome
}:

buildPythonPackage rec {
  pname = "speedport-api";
  version = "0.6.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = lib.fakeSha256;
  };

  propagatedBuildInputs = [
    aiohttp
    pycryptodome
  ];

  doCheck = false;

  pythonImportsCheck = [ "speedport" ];

  meta = with lib; {
    description = "Async Python library and CLI to control Telekom Speedport Smart 4 routers";
    homepage = "https://github.com/Andre0512/speedport-api";
    license = licenses.mit;
    maintainers = [ ];
  };
}
