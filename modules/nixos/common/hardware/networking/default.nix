{
  pkgs,
  config,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    networkmanager-openconnect
    networkmanagerapplet
    openconnect
  ];
  users.users.${config.hostSpec.username}.extraGroups = [ "networkmanager" ];
  networking = {
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    networkmanager = {
      enable = true;
      plugins = [
        pkgs.networkmanager-openconnect
      ];
    };
  };
}
