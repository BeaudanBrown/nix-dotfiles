{
  config,
  ...
}:
{
  programs.git = {
    enable = true;
    config = {
      user = {
        name = config.hostSpec.userFullName;
        email = config.hostSpec.email;
        defaultBranch = "main";
      };
      alias = {
        lg = "log --all --graph --decorate --oneline";
      };
    };
  };
}
