{ ... }:
{
  programs.zathura = {
    enable = true;
    mappings = {
      "J" = "zoom out";
      "K" = "zoom in";
    };
    options = {
      selection-clipboard = "clipboard";
    };
  };
}
