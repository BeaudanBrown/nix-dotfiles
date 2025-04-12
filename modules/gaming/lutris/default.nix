{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    (lutris.override {
      extraLibraries = pkgs: [
        wine
      ];
    })
  ];
  programs.cdemu = {
    enable = true;
    gui = true;
  };
}
