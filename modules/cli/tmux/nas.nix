{
  pkgs,
  ...
}:
{
  imports = [ ./shared-server.nix ];

  environment.systemPackages = [
    pkgs.xclip
  ];
}
