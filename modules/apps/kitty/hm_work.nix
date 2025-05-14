{ ... }:
{
  programs.kitty = {
    enable = true;
    settings = {
      confirm_os_window_close = 0;
      enable_audio_bell = false;
      cursor_trail = 50;
      cursor_trail_decay = "0.2 0.4";
      cursor_trail_start_threshold = 10;
    };
  };
}
