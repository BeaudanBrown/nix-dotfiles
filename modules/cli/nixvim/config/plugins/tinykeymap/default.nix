{ pkgs, ... }:
{
  extraPlugins = [
    {
      plugin = pkgs.vimUtils.buildVimPlugin {
        name = "tinykeymap";
        src = pkgs.fetchFromGitHub {
          owner = "tomtom";
          repo = "tinykeymap_vim";
          rev = "7217ce656069d82cd71872ede09152b232ecaf1b";
          hash = "sha256-HKCSJAhBJD8MsFAkn0lVy4135WkiBVJycWEKQFa1Gvg=";
        };
      };
    }
  ];

  extraConfigLua = ''
    vim.g['tinykeymap#timeout'] = 0
    vim.g['tinykeymaps_default'] = {}

    local tinykeymap_enter_map = vim.fn['tinykeymap#EnterMap'];
    local tinykeymap_map = vim.fn['tinykeymap#Map'];

    tinykeymap_enter_map(
      'git',
      '<Leader>gj',
      {
        start = 'GitGutterNextHunk | GitGutterPreviewHunk',
        stop = 'do CursorMoved'
      }
    );
    tinykeymap_enter_map(
      'git',
      '<Leader>gk',
      {
        start = 'GitGutterPrevHunk | GitGutterPreviewHunk',
        stop = 'do CursorMoved'
      }
    );

    tinykeymap_map(
      'git',
      'j',
      'GitGutterNextHunk | GitGutterPreviewHunk',
      { desc = 'Go to next hunk' }
    );
    tinykeymap_map(
      'git',
      'k',
      'GitGutterPrevHunk | GitGutterPreviewHunk',
      { desc = 'Go to previous hunk' }
    );
  '';
}
