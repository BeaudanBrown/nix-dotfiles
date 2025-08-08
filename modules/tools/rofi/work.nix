{
  config,
  ...
}:
let
  inherit (config.home-manager.users.${config.hostSpec.username}.lib.formats.rasi) mkLiteral;
in
{
  imports = [ ./scripts/rofi_launch_dir.nix ];

  home-manager.users.${config.hostSpec.username}.programs.rofi = {
    enable = true;
    extraConfig = {
      show-icons = true;
      # Keybinds
      # https://github.com/davatorium/rofi/blob/next/doc/rofi-keys.5.markdown
      kb-remove-to-eol = "";
      kb-accept-entry = "Return,KP_Enter";
      kb-row-up = "Up,Control+k";
      kb-row-down = "Down,Control+j";
    };
    theme = {
      element-icon = {
        size = mkLiteral "1em";
        horizontal-align = mkLiteral "0.5";
      };
    };
  };
}
