{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    (writeShellApplication {
      name = "fl";
      text = ''
        export FL_R_FLAKE="${./r/flake.nix}"
        export FL_R_ENVRC="${./r/envrc}"
        export FL_R_LINTR="${./r/lintr}"
        export FL_R_GITIGNORE="${./r/gitignore}"
        export FL_GO_FLAKE="${./go/flake.nix}"
        export FL_GO_ENVRC="${./go/envrc}"
        export FL_GO_GITIGNORE="${./go/gitignore}"
        export FL_PY_FLAKE="${./python/flake.nix}"
        export FL_PY_ENVRC="${./python/envrc}"
        export FL_PY_GITIGNORE="${./python/gitignore}"
        ${builtins.readFile ./fl.sh}
      '';
    })
  ];
}
