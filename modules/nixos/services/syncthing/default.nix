{
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.services.syncthing;

  inherit (lib) mkEnableOption mkIf;
in
{
  options.${namespace}.services.syncthing = {
    enable = mkEnableOption "Syncthing";
  };

  config = mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      openDefaultPorts = true;
      user = config.${namespace}.user.name;
      dataDir = "/home/${config.${namespace}.user.name}";
      settings = {
        options = {
          urAccepted = -1;
        };
        devices = {
          "server" = {
            id = "YZLDZHW-7MYKYEM-5PTTWLU-TBPEQJX-CJEFVBS-UYIOQJM-OKCQ723-25HTDAT";
            autoAcceptFolder = true;
          };
          "nix-laptop" = {
            id = "T2YY6AY-XQNZQQW-RRI52RN-EARJZHR-6GPNA2A-2QBRMFD-TOHY5SH-MXFKVAC";
            autoAcceptFolder = true;
          };
          "grill" = {
            id = "B4SXNGB-I6QC6RM-GCPSPXR-JSCTBNJ-RTFDNVW-OPVO3TB-BQ7EDSO-ODJV4AC";
            autoAcceptFolder = true;
          };
        };
        folders = {
          "documents" = {
            id = "txxit-w9cwz";
            path = "~/documents";
            devices = [ "server" "grill" "nix-laptop" ];
          };
          "monash" = {
            id = "twjfr-ekoqc";
            path = "~/monash";
            devices = [ "server" "grill" "nix-laptop" ];
          };
          "collab" = {
            id = "vccfp-s5yfe";
            path = "~/collab";
            devices = [ "server" "grill" "nix-laptop" ];
          };
        };
      };
    };
  };
}
