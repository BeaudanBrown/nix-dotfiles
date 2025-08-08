{ pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
    codex
  ];
  environment.shellAliases = {
    apply_patch = "patch";
  };

  home-manager.users.${config.hostSpec.username} = {
    home.file."codexConfig" = {
      source = (pkgs.formats.yaml { }).generate "config" {
        model = "gemini-2.5-flash";
        provider = "litellm";
        providers = {
          litellm = {
            name = "LiteLLM";
            baseURL = "https://litellm.bepis.lol";
            envKey = "LITELLM_TOKEN";
          };
        };
      };
      target = ".codex/config.yaml";
    };
    programs.zsh.envExtra = # bash
      ''
        export LITELLM_TOKEN="$(cat ${config.sops.secrets.litellm_api.path})"
      '';
  };
}
