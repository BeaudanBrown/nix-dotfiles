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

  # GitHub CLI secrets for all users
  sops.secrets."gh-hosts" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    mode = "0600";
    path = "${config.hostSpec.home}/.config/gh/hosts.yml";
  };
  # TODO: Uncomment when secrets are set up
  # sops.secrets = lib.custom.sopsSecretForAllUsers config "gh-hosts" {
  #   sopsFile = lib.custom.sopsFileForModule __curPos.file;
  #   mode = "0600";
  # };

  # Create gh config directory for all users
  systemd.tmpfiles.rules = [
    "d ${config.hostSpec.home}/.config/gh 0700 ${config.hostSpec.username} users - -"
  ];

  # systemd.tmpfiles.rules = map (user:
  #   "d ${user.home}/.config/gh 0700 ${user.username} users - -"
  # ) config.hostSpec.users;

  # All users get GitHub CLI
  hm.primary.programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "vim";
    };
  };
}
