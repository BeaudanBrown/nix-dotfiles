{
  deviceName,
  secondDeviceName,
  swapSize,
  ...
}:
{
  disk = {
    main = {
      type = "disk";
      device = deviceName;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            name = "ESP";
            start = "1M";
            end = "550M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "/rootfs" = {
                  mountpoint = "/";
                };
                "/nix" = {
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                  mountpoint = "/nix";
                };
                "/swap" = {
                  mountpoint = "/.swapvol";
                  swap.swapfile.size = swapSize;
                };
              };
            };
          };
        };
      };
    };

    secondary = {
      type = "disk";
      device = secondDeviceName;
      content = {
        type = "gpt";
        partitions = {
          data = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "/home" = {
                  mountpoint = "/home";
                  mountOptions = [ "compress=zstd" ];
                };
                "/var_lib" = {
                  mountpoint = "/var/lib";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
              };
            };
          };
        };
      };
    };
  };
}
