{ ... }:
{
  hm.programs.oh-my-posh = {
    enable = true;
    settings = builtins.fromJSON (
      builtins.unsafeDiscardStringContext (builtins.readFile ./config/oh-my-posh-pi4.json)
    );
    enableZshIntegration = true;
  };
}
