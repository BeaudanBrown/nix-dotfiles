{ lib, ... }:
{
  home.file = builtins.readDir ./. |>
    lib.attrsets.filterAttrs (name: type: (type == "regular") && (lib.strings.hasSuffix ".aichat" name)) |>
    builtins.mapAttrs (name: _: {
      source = ./${name};
      target = ".local/share/gpt/${name}";
    });
}
