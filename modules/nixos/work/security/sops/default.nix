{
  pkgs,
  config,
  ...
}:
{
  environment = {
    systemPackages = [ pkgs.sops ];
  };
  sops = {
    # Which secrets to use, get stored by default in /run/secrets/<name>
    secrets = {
      litellm_api = {
        path = "/home/${config.hostSpec.username}/.config/openai.token";
        owner = config.hostSpec.username;
        inherit (config.users.users.${config.hostSpec.username}) group;
      };
    };
  };
}
