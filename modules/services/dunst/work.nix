{ ... }:
{
  hm.primary.services.dunst = {
    enable = true;
    settings = {
      ghostty-desktop-entry = {
        desktop_entry = "com.mitchellh.ghostty";
        skip_display = true;
        history_ignore = true;
      };

      ghostty-appname = {
        appname = "Ghostty";
        skip_display = true;
        history_ignore = true;
      };
    };
  };
}
