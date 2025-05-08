{ pkgs, config, ... }:
let
  nvimcom = pkgs.rPackages.buildRPackage {
    name = "nvimcom";
    src =
      pkgs.fetchFromGitHub {
        owner = "R-nvim";
        repo = "R.nvim";
        rev = "70a3f8dc1b7bd5713fea0f787a4cc322ff11ad0e";
        hash = "sha256-07VXMPcVgRS/T+WwmQUu0GvM1ZVETtiGKmntge/cOpk=";
      }
      + "/nvimcom/";
  };
  my-r = pkgs.rWrapper.override {
    packages = with pkgs.rPackages; [
      languageserver
      nvimcom
    ];
  };
in
{
  environment = {
    shellAliases.vim = "nvim";
    variables = {
      EDITOR = "nvim";
      R_LIBS_USER = "/home/${config.hostSpec.username}/.config/Rlib";
    };
    systemPackages = [
      my-r
    ];
  };

  programs.nixvim = (import ./config/nixvim.nix);
}
