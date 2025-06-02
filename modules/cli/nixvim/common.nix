{
  pkgs,
  config,
  ...
}@specialArgs:
let
  nvimcom = pkgs.rPackages.buildRPackage {
    name = "nvimcom";
    src =
      pkgs.fetchFromGitHub {
        owner = "R-nvim";
        repo = "R.nvim";
        rev = "382858fcf23aabbf47ff06279baf69d52260b939";
        hash = "sha256-j2rXXO7246Nh8U6XyX43nNTbrire9ta9Ono9Yr+Eh9M=";
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
      R_LIBS_USER = "${config.hostSpec.home}/.config/Rlib";
      R_PROFILE = "${config.hostSpec.home}/.config/Rprofile";
    };
    systemPackages = [
      my-r
    ];
  };

  programs.nixvim = (import ./config/nixvim.nix specialArgs);
}
