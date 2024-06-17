{ lib, pkgs, ... }:
let
  buildTmuxPlugin = pkgs.tmuxPlugins.mkTmuxPlugin;
in
{
  select-pane-no-wrap = buildTmuxPlugin {
    pluginName = "select-pane-no-wrap";
    version = "stable";
    src = pkgs.fetchFromGitHub {
      owner = "dalejung";
      repo = "tmux-select-pane-no-wrap";
      rev = "00add786db1f0e87de23e3f3440e43bcc1f0623f";
      sha256 = "sha256-ot0cHvk1TXvHOw9z+7TLSiHT77jHwvV2PSHcNuhOorQ=";
    };
  };
}
