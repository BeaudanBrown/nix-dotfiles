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
        rev = "c56ebe0f8445e251673981c40ac2d74659ecd6ed";
        hash = "sha256-FywUL3mV2+kfu+rO6uUFyUv80EflbdgSkYuSnW965UE=";
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

  hm.primary.home.file.".Rprofile" =
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
