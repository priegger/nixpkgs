{ stdenv, buildPythonPackage, fetchFromGitHub, fetchpatch
, sqlite, isPyPy }:

buildPythonPackage rec {
  pname = "apsw";
  version = "3.31.1-r1";

  disabled = isPyPy;

  src = fetchFromGitHub {
    owner = "rogerbinns";
    repo = "apsw";
    rev = version;
    sha256 = "0gd56sy3741paqvdf2qqhqszg2k5sx6bdywgl19bk9rglxj8sfbv";
  };

  buildInputs = [ sqlite ];

  meta = with stdenv.lib; {
    description = "A Python wrapper for the SQLite embedded relational database engine";
    homepage = "https://github.com/rogerbinns/apsw";
    license = licenses.zlib;
  };
}
