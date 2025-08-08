{ lib, config, ... }:
{
  home-manager.users.${config.hostSpec.username}.home.file =
    (
      builtins.readDir ./.
      |> lib.attrsets.filterAttrs (
        name: type: (type == "regular") && (lib.strings.hasSuffix ".aichat" name)
      )
      |> builtins.mapAttrs (
        name: _: {
          source = ./${name};
          target = ".local/share/gpt/${name}";
        }
      )
    )
    // {
      "default.aichat" = {
        source = ./o4-mini.aichat;
        target = ".local/share/gpt/default.aichat";
      };
    };
}
