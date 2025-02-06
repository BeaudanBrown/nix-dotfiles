{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.tools.rofi;
  inherit (config.lib.formats.rasi) mkLiteral;
in
{
  options.${namespace}.tools.rofi = with types; {
    enable = mkBoolOpt false "Whether or not to enable rofi.";
  };

  config = mkIf cfg.enable (mkMerge
  [
    (import ./scripts/rofi_launch_dir.nix { inherit pkgs; })
    {
      programs.rofi = {
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
  ]);
}
