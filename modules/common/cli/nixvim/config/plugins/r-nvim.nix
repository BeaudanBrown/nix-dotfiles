{ pkgs, ... }:
{
  extraPlugins = [
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "r-nvim";
        src = pkgs.fetchFromGitHub {
          owner = "R-nvim";
          repo = "r.nvim";
          rev = "70a3f8dc1b7bd5713fea0f787a4cc322ff11ad0e";
          hash = "sha256-07VXMPcVgRS/T+WwmQUu0GvM1ZVETtiGKmntge/cOpk=";
        };
        nvimSkipModules = [
          "r.pdf.sumatra"
          "r.roxygen"
          "r.format"
        ];
      };
    }
  ];
}
