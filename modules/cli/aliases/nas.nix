{ ... }:
{
  # environment.shellAliases.nr = lib.mkForce ''${pkgs.nix-fast-build}/bin/nix-fast-build \
  #   --eval-workers 6 \
  #   --eval-max-memory-size 3072 \
  #   --flake "${config.hostSpec.dotfiles}#nixosConfigurations.${config.hostSpec.hostName}.config.system.build.toplevel" \
  #   && ${pkgs.nh}/bin/nh os switch "${config.hostSpec.dotfiles}"'';
}
