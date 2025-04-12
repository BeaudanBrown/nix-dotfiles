{
  config,
  pkgs,
  ...
}:
{
  users.users.${config.hostSpec.username} = {
    isNormalUser = true;
    home = "/home/${config.hostSpec.username}";
    extraGroups = [ "wheel" ];
    group = "users";
    shell = pkgs.zsh;
    uid = 1000;
  };
}
