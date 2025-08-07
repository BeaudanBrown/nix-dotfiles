{ ... }:
{
  plugins.mini = {
    enable = true;
    mockDevIcons = true;
    modules = {
      icons = { };
      animate = {
        cursor = {
          enable = false;
        };
        resize = {
          enable = true;
          timing.__raw = "require('mini.animate').gen_timing.linear({ duration = 30, unit = 'total' })";
        };
        close = {
          enable = true;
          timing.__raw = "require('mini.animate').gen_timing.linear({ duration = 30, unit = 'total' })";
        };
        open = {
          enable = true;
          timing.__raw = "require('mini.animate').gen_timing.linear({ duration = 30, unit = 'total' })";
        };
        scroll = {
          enable = false;
          timing.__raw = "require('mini.animate').gen_timing.linear({ duration = 30, unit = 'total' })";
        };
      };
    };
  };
}
