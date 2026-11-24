{
  config,
  lib,
  ...
}:
{
  programs.git = {
    enable = true;
    config = {
      user = {
        name = config.hostSpec.primaryUser.userFullName;
        email = config.hostSpec.primaryUser.email;
        defaultBranch = "main";
      };
      alias = {
        lg = "log --all --graph --decorate --oneline";
      };
    };
  };

  hm.primary.imports = [
    (
      { config, ... }:
      {
        sops.secrets."gh-hosts" = {
          sopsFile = lib.custom.sopsFileForModule __curPos.file;
          mode = "0600";
          path = "${config.home.homeDirectory}/.config/gh/hosts.yml";
        };
      }
    )
  ];

  hm.primary.programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "vim";
    };
  };
}
