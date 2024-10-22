{ configLib, ... }:
{
  imports = (configLib.scanPaths ./.) ++
  (map configLib.relativeToRoot [
    "home/common/core"
  ]);
}

