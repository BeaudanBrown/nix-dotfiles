{ pkgs, config, ... }:
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "bootstrap_nixos";
      text = ''
        export BOOTSTRAP_USERNAME="${config.hostSpec.username}"
        export BOOTSTRAP_HOME="${config.hostSpec.home}"
        export BOOTSTRAP_DOTFILES="${config.hostSpec.dotfiles}"
        ${builtins.readFile ./bootstrap_nixos.sh}
      '';
      runtimeInputs = with pkgs; [
        gawk
        rsync
        git
        just
        yq-go
        age
        ssh-to-age
        nixos-anywhere
      ];
    })
  ];
}
