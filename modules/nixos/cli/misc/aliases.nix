{
  pkgs,
  ...
}:
{
  sudo = "sudo ";
  nc = "vim ~/documents/nix-dotfiles";
  nr = "sudo nixos-rebuild switch";
  ls = "${pkgs.eza}/bin/eza -lh --group-directories-first";
  cat = "${pkgs.bat}/bin/bat";
}
