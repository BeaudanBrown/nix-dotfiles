{ pkgs, ... }:
{
  environment.shellAliases = {
    vim = "nvim";
    sudo = "sudo ";
    nc = "vim ~/documents/nix-dotfiles/configuration.nix";
    nr = "sudo nixos-rebuild switch";
    ls = "${pkgs.eza}/bin/eza -lh --group-directories-first";
    cat = "${pkgs.bat}/bin/bat";
    sd="sudo mount -t cifs -o credentials=/home/beau/.config/smbcredentials,uid=1000,gid=1000,iocharset=utf8,sec=ntlmssp,_netdev,soft,cache=none //ad.monash.edu/shared /s" ;
  };
}
