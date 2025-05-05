{ lib, ... }:
{
  enable = true;

  imports =
    [
      ./opts.nix
      ./keybinds.nix
    ]
    ++ lib.custom.importRecursive ./plugins;

  # Use tabs for go files
  files = {
    "ftplugin/go.lua" = {
      opts = {
        expandtab = false;
      };
    };
  };

  clipboard.register = [
    "unnamed"
    "unnamedplus"
  ];

  colorschemes.kanagawa = {
    enable = true;
    settings.theme = "dragon";
  };

  globals = {
    mapleader = " ";
    maplocalleader = ",";
    highlightedyank_highlight_duration = 200;
  };

  autoGroups = {
    cursor_pos = {
      clear = true;
    };
  };

  autoCmd = [
    {
      event = [
        "TermOpen"
        "WinEnter"
      ];
      pattern = "term://*";
      command = "startinsert";
    }
  ];

  highlightOverride = {
    GitGutterAdd.bold = true;
    GitGutterChange.bold = true;
    GitGutterDelete.bold = true;
    CursorLine = {
      ctermfg = "NONE";
      ctermbg = "NONE";
    };
    LineNr = {
      ctermbg = "NONE";
    };
    SignColumn = {
      ctermfg = "NONE";
      ctermbg = "NONE";
    };
    IncSearch.bold = true;
  };

  extraConfigVim = ''
    function s:CloseBuffer(kwbdStage)
      if(a:kwbdStage == 1)
        if(&modified)
          let answer = confirm("This buffer has been modified.  Are you sure you want to delete it?", "&Yes\n&No", 2)
          if(answer != 1)
            return
          endif
        endif
        if(!buflisted(winbufnr(0)))
      bd!
          return
        endif
        let s:kwbdBufNum = bufnr("%")
        let s:kwbdWinNum = winnr()
        windo call s:CloseBuffer(2)
        execute s:kwbdWinNum . 'wincmd w'
        let s:buflistedLeft = 0
        let s:bufFinalJump = 0
        let l:nBufs = bufnr("$")
        let l:i = 1
        while(l:i <= l:nBufs)
          if(l:i != s:kwbdBufNum)
            if(buflisted(l:i))
              let s:buflistedLeft = s:buflistedLeft + 1
            else
              if(bufexists(l:i) && !strlen(bufname(l:i)) && !s:bufFinalJump)
                let s:bufFinalJump = l:i
              endif
            endif
          endif
          let l:i = l:i + 1
        endwhile
        if(!s:buflistedLeft)
          if(s:bufFinalJump)
            windo if(buflisted(winbufnr(0))) | execute "b! " . s:bufFinalJump | endif
          else
            enew
            let l:newBuf = bufnr("%")
            windo if(buflisted(winbufnr(0))) | execute "b! " . l:newBuf | endif
          endif
          execute s:kwbdWinNum . 'wincmd w'
        endif
        if(buflisted(s:kwbdBufNum) || s:kwbdBufNum == bufnr("%"))
          execute "bd! " . s:kwbdBufNum
        endif
        if(!s:buflistedLeft)
          set buflisted
          set bufhidden=delete
          set buftype=
          setlocal noswapfile
        endif
      else
        if(bufnr("%") == s:kwbdBufNum)
          let prevbufvar = bufnr("#")
          if(prevbufvar > 0 && buflisted(prevbufvar) && prevbufvar != s:kwbdBufNum)
            b #
          else
            bn
          endif
        endif
      endif
    endfunction

    command! CloseBuffer call s:CloseBuffer(1)
    nnoremap <silent> <Plug>CloseBuffer :<C-u>CloseBuffer<CR>
    '';

  extraConfigLua = ''
    local find_root = function()
      local gitRoot = vim.fn.system('git rev-parse --show-toplevel 2> /dev/null')
      if gitRoot ~= "" then
        gitRoot = vim.fn.trim(gitRoot)
        if vim.fn.filereadable(gitRoot .. '/.git') == 1 then
          -- We are in a git folder
          return gitRoot
        end
      end
      -- We are in a non-git folder or in the root of the git folder
      if #vim.fn.argv() > 0 then
        return vim.fn.fnamemodify(vim.fn.argv()[0], ':p:h')
      end
      return vim.fn.getcwd()
    end
    local root = find_root()
    vim.api.nvim_create_user_command('ProjectFiles', function() vim.cmd('FzfLua files ' .. root) end, {})
    '';
}
