{
  pkgs,
  config,
  ...
}:
let
  get = pkgs.writeShellApplication {
    name = "get";
    text = builtins.readFile ./get.sh;
  };
in
{
  environment.shellAliases = {
    sudo = "sudo ";
    nc = "vim ~/documents/nix-dotfiles";
    nr = ''${pkgs.nix-fast-build}/bin/nix-fast-build --flake "${config.hostSpec.dotfiles}#nixosConfigurations.${config.hostSpec.hostName}.config.system.build.toplevel" && ${pkgs.nh}/bin/nh os switch "${config.hostSpec.dotfiles}"'';
    ls = "${pkgs.eza}/bin/eza -lh --group-directories-first";
    cat = "${pkgs.bat}/bin/bat";
    shutup = "sudo shutdown now";
    nixos-rebuild = "nixos-rebuild --flake ${config.hostSpec.home}/documents/nix-dotfiles";
    df = "${pkgs.dysk}/bin/dysk";
    du = "du -h -d 1";
    get = "${get}/bin/get";
  };
}
