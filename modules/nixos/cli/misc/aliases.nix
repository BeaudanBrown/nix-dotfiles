{
  pkgs,
  ...
}:
{
  sudo = "sudo ";
  nc = "vim ~/documents/nix-dotfiles";
  nr = "sudo ${pkgs.nh}/bin/nh os switch";
  ls = "${pkgs.eza}/bin/eza -lh --group-directories-first";
  cat = "${pkgs.bat}/bin/bat";
  shutup = "sudo shutdown now";
}
