{
  ...
}:
{
  programs.git = {
    enable = true;
    config = {
      user = {
        name = "Beaudan Brown";
        email = "beaudan.brown@gmail.com";
      };
      alias = {
        lg = "log --all --graph --decorate --oneline";
      };
    };
  };
}
