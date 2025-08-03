{ pkgs, ... }:
{
  extraPlugins = [
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "r-nvim";
        src = pkgs.fetchFromGitHub {
          owner = "R-nvim";
          repo = "r.nvim";
          rev = "382858fcf23aabbf47ff06279baf69d52260b939";
          hash = "sha256-j2rXXO7246Nh8U6XyX43nNTbrire9ta9Ono9Yr+Eh9M=";
        };
        nvimSkipModules = [
          "r.pdf.sumatra"
          "r.roxygen"
          "r.format"
        ];
      };
    }
  ];
  extraConfigLua = ''
    require("r").setup {
      rconsole_width = 66,
      rconsole_height = 0
    }
  '';
}
