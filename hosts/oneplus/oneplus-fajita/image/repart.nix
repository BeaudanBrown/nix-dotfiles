{ modulesPath, pkgs, config, lib, ... }:
let
  efiArch = pkgs.stdenv.hostPlatform.efiArch;
in
{
  imports = [ "${modulesPath}/image/repart.nix" ];
  boot.loader.grub.enable = false;

#  system.build.x = config.system.build.image.overrideAttrs {
#    postPatch = ''
#      export SYSTEMD_REPART_MKFS_OPTIONS_VFAT="-S 4096"
#    '';
#  };

  # Probably necessary for root resize
  systemd.repart.enable = true;
  systemd.repart.partitions."03-root".Type = "root";
  boot.initrd.systemd.enable = true;
#  boot.initrd.systemd.root = "gpt-auto";
  boot.initrd.supportedFilesystems.ext4 = true;

  fileSystems."/".device = lib.mkForce "/dev/disk/by-label/nixos";
  fileSystems."/".fsType = lib.mkForce "ext4";
  fileSystems."/boot".device = lib.mkForce "/dev/disk/by-label/ESP";
  fileSystems."/boot".fsType = lib.mkForce "vfat";
  image.repart = {
    sectorSize = 4096;
    name = "image";
    compression.enable = true;
    partitions = {
      "00-padding" = {
        repartConfig = {
          Type = "linux-generic";
          SizeMinBytes = "15M";
          SizeMaxBytes = "15M";
          GrowFileSystem = false;
        };
      };
      "10-esp" = {
        contents = {
          "/EFI/EDK2-UEFI-SHELL/SHELL.EFI".source = "${pkgs.edk2-uefi-shell.overrideAttrs { env.NIX_CFLAGS_COMPILE = "-Wno-error=maybe-uninitialized"; }}/shell.efi";
          "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source = "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
          "/EFI/Linux/${config.system.boot.loader.ukiFile}".source = "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
          "/loader/loader.conf".source = pkgs.writeText "loader.conf" ''
            timeout 5
            console-mode keep
          '';
          "/loader/entries/shell.conf".source = pkgs.writeText "shell.conf" ''
            title  EDK2 UEFI Shell
            efi    /EFI/EDK2-UEFI-SHELL/SHELL.EFI
          '';
        };
        repartConfig = {
          FileSystemSectorSize = 4096;
          Type = "esp";
          Format = "vfat";
          Label = "ESP";
          SizeMinBytes = "50M";
          GrowFileSystem = true;
        };
      };
      "20-root" = {
        storePaths = [ config.system.build.toplevel ];
        contents."/boot".source = pkgs.runCommand "boot" { } "mkdir $out";
        repartConfig = {
          FileSystemSectorSize = 4096;
          Type = "root";
          Format = "ext4";
          Label = "nixos";
          Minimize = "guess";
          GrowFileSystem = true;
        };
      };
    };
  };
}
