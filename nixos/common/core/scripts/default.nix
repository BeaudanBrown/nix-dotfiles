{ configLib, ... }:
{
  imports = (configLib.scanPaths ./.);
}
