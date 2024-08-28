{ ... }:
{
  programs.git = {
    enable = true;
    aliases = {
      lg = "log --all --graph --decorate --oneline";
    };
  };
}
