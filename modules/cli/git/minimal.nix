{
  config,
  ...
}:
{
  programs.git = {
    enable = true;
    config = {
      user = {
        name = config.hostSpec.userFullName;
        email = config.hostSpec.email;
        defaultBranch = "main";
      };
      alias = {
        lg = "log --all --graph --decorate --oneline";
      };
    };
  };

  sops.secrets."gh-hosts" = {
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    mode = "0600";
    path = "${config.hostSpec.home}/.config/gh/hosts.yml";
  };

  systemd.tmpfiles.rules = [
    "d ${config.hostSpec.home}/.config/gh 0700 ${config.hostSpec.username} users - -"
  ];

  hm.programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "vim";
    };
  };
}
