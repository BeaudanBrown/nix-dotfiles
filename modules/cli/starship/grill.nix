{ ... }:
{
  # grill: orange theme (#ff6b35)
  hm.programs.starship.settings = {
    username = {
      style_user = "fg:#ff6b35";
      format = "[$user]($style)[@](fg:#ff6b35)";
    };
    hostname.style = "fg:#ff6b35";
    character = {
      success_symbol = "[❯](bold #ff6b35)";
      error_symbol = "[❯](bold red)";
      vimcmd_symbol = "[❮](bold #ff6b35)";
    };
  };
}
