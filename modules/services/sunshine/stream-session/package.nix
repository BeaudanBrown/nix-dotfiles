{
  mkDerivation,
  lib,
  base,
  aeson,
  bytestring,
  text,
  directory,
  filepath,
  process,
  unix,
  network,
  async,
}:
mkDerivation {
  pname = "stream-session";
  version = "0.1.0.0";
  src = lib.cleanSource ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    base
    aeson
    bytestring
    text
    directory
    filepath
    process
    unix
    network
    async
  ];
  executableHaskellDepends = [ base ];
  testHaskellDepends = [
    base
    aeson
    bytestring
    directory
    filepath
    process
    unix
    network
    async
  ];
  doCheck = true;
  license = lib.licenses.mit;
  mainProgram = "stream-session";
}
