{
config,
...
}:
{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    config = {
      whitelist = {
        prefix = [
          "${config.home.homeDirectory}/documents"
          "${config.home.homeDirectory}/monash"
          "${config.home.homeDirectory}/collab"
        ];
      };
    };
  };
}
