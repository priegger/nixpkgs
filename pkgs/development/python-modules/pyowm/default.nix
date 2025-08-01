{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  geojson,
  pysocks,
  pythonOlder,
  requests,
  setuptools,
  pytestCheckHook,
}:

buildPythonPackage rec {
  pname = "pyowm";
  version = "3.3.0";
  pyproject = true;

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "csparpa";
    repo = "pyowm";
    tag = version;
    hash = "sha256-cSOhm3aDksLBChZzgw1gjUjLQkElR2/xGFMOb9K9RME=";
  };

  pythonRelaxDeps = [ "geojson" ];

  build-system = [ setuptools ];

  dependencies = [
    geojson
    pysocks
    requests
    setuptools
  ];

  nativeCheckInputs = [ pytestCheckHook ];

  # Run only tests which don't require network access
  enabledTestPaths = [ "tests/unit" ];

  pythonImportsCheck = [ "pyowm" ];

  meta = with lib; {
    description = "Python wrapper around the OpenWeatherMap web API";
    homepage = "https://pyowm.readthedocs.io/";
    changelog = "https://github.com/csparpa/pyowm/releases/tag/${version}";
    license = licenses.mit;
    maintainers = with maintainers; [ fab ];
  };
}
