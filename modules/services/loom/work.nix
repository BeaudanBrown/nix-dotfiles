{ inputs, ... }:
{
  environment.systemPackages = [
    inputs.loom.packages.x86_64-linux.loom-cli
  ];
}
