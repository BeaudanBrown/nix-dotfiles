{ configLib, ... }:
{
  programs.oh-my-posh = {
    enable = true;
    enableZshIntegration = true;
    settings = builtins.fromJSON (
      builtins.unsafeDiscardStringContext (
        builtins.readFile
        (configLib.relativeToRoot "./extraConfig/oh-my-posh/oh-my-posh.json")
        )
      );
  };
}
