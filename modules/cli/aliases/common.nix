{
  pkgs,
  config,
  ...
}:
let
  get = pkgs.writeShellScriptBin "get" (builtins.readFile ./get.sh);
in
{
  environment.shellAliases = {
    sudo = "sudo ";
    nc = "vim ~/documents/nix-dotfiles";
    nr = ''${pkgs.nh}/bin/nh os switch "${config.hostSpec.dotfiles}"'';
    ls = "${pkgs.eza}/bin/eza -lh --group-directories-first";
    cat = "${pkgs.bat}/bin/bat";
    shutup = "sudo shutdown now";
    nixos-rebuild = "nixos-rebuild --flake ${config.hostSpec.home}/documents/nix-dotfiles";
    df = "${pkgs.dysk}/bin/dysk";
    du = "du -h -d 1";
    get = "${get}/bin/get";
  };
}
