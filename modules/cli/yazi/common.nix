{ pkgs, ... }:
{
  hm.primary.programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      mgr = {
        show_hidden = true;
        sort_by = "mtime";
        sort_dir_first = true;
        sort_reverse = true;
      };
    };
  };

  # Runtime dependencies for Yazi (previews, navigation)
  hm.primary = {
    home.packages = with pkgs; [
      ueberzugpp # Image preview support (X11/Wayland)
      chafa # Fallback terminal graphics
      ffmpegthumbnailer # Video thumbnails
      imagemagick # Image decoding/manipulation
      poppler-utils # PDF previews
      unar # Archive previews
      jq # JSON previews
      fd # Fast file search
      ripgrep # Code search
      zoxide # Smart directory jumping
    ];
  };
}
