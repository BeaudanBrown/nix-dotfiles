{ lib, ... }:
{
  imports = lib.custom.importRecursive ./.;
}
