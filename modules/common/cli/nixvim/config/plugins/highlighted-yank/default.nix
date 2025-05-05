{ pkgs, ... }:
{
  extraPlugins = [
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "highlighted-yank";
        src = pkgs.fetchFromGitHub {
          owner = "machakann";
          repo = "vim-highlightedyank";
          rev = "afb0f262b490706c23e94012c2ab9fa67c0481ce";
          hash = "sha256-WcSxpXYErKyr/9LaAmFw6WfpcKq2YlbLag6HVVhwyFQ=";
        };
      };
    }
  ];
}
