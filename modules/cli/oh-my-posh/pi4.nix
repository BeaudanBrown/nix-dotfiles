{ ... }:
{
  hm.programs.oh-my-posh = {
    enable = false; # Disabled in favor of starship
    settings = builtins.fromJSON (
      builtins.unsafeDiscardStringContext (builtins.readFile ./config/oh-my-posh-pi4.json)
    );
    enableZshIntegration = true;
  };
}
