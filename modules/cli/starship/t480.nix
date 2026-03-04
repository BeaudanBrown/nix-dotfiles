{ ... }:
{
  # t480: magenta theme (same as laptop)
  hm.primary.programs.starship.settings = {
    username = {
      style_user = "fg:magenta";
      format = "[$user]($style)[@](fg:magenta)";
    };
    hostname.style = "fg:magenta";
    # character = {
    #   success_symbol = "[❯](bold magenta)";
    #   error_symbol = "[❯](bold red)";
    # };
  };
}
