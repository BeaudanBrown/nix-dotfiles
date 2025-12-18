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
        rev = "42b6321c771c902200ecd18791b4ca48e029a62e";
        hash = "sha256-WhN2L5Uv/7HSm/nZHzJiDy3EAnZ2b8cDzG+D7xPvDUk=";
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

  hm.home.file.".Rprofile" =
    let
      profile = ''
        options(browser = "brave")
      '';
    in
    {
      text = profile;
      target = "${config.hostSpec.home}/.config/Rprofile";
    };
}
