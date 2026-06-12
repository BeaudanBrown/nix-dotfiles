{
  lib,
  config,
  ...
}:
{
  imports = [
    ./hardware/qualcomm-services.nix
    ./hardware/sdm845.nix
    ./image/repart.nix
    ./networking/ssh.nix
    ./networking/wireless.nix
    ./ui/greetd.nix
    ./ui/niri.nix
    # ./ui/phosh.nix
  ];
  boot.loader = {
    efi = {
      efiSysMountPoint = "/boot";
      canTouchEfiVariables = false;
    };

    systemd-boot = {
      enable = true;
      configurationLimit = lib.mkForce 10;
      extraFiles = {
        "EFI/BOOT/BOOTAA64.EFI" = "${config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi";
        "EFI/systemd/systemd-bootaa64.efi" =
          "${config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi";
      };
    };
  };
  # Keep the phone on the known-good boot argument shape. The common desktop
  # boot module adds PC-oriented parameters that are unnecessary here.
  boot.kernelParams = lib.mkForce [
    "console=ttyGS0,115200"
    "clk_ignore_unused"
    "pd_ignore_unused"
    "arm64.nopauth"
    "console=ttyMSM0,115200n8"
    "console=tty0"
    "rd.systemd.default_standard_output=kmsg+console"
    "rd.systemd.default_standard_error=kmsg+console"
    "rd.systemd.journald.forward_to_console=1"
    "rd.systemd.log_target=console"
    "rd.systemd.journald.forward_to_console=1"
    "root=fstab"
    "loglevel=8"
    "lsm=landlock,yama,bpf"

    # Reboot-hang isolation: qcom_q6v5_mss owns 4080000.remoteproc (modem/MSS).
    # SysRq emergency reboot works while orderly reboot hangs, so test whether
    # keeping the modem remoteproc driver unloaded avoids the device shutdown
    # path that blocks normal reboot. Remove this after confirming/denying the
    # culprit and replacing it with a DT/kernel fix.
    "module_blacklist=qcom_q6v5_mss"

    # Temporary high-verbosity shutdown logging for the same investigation.
    "ignore_loglevel"
    "no_console_suspend"
    "printk.time=1"
    "printk.devkmsg=on"
    "sysrq_always_enabled=1"
    "initcall_debug"
    "systemd.log_level=debug"
    "systemd.log_target=kmsg"
  ];
  services = {
    dbus = {
      # Avoid a live dbus -> dbus-broker implementation change on the phone.
      # That change is blocked by NixOS switch inhibitors and should only happen
      # through `nixos-rebuild boot` + reboot if we decide to adopt it later.
      implementation = "dbus";
      packages = [
        config.systemd.package
      ];
    };

    upower.enable = true;
  };

  # The USB gadget serial getty on ttyGS0 holds/contends for /dev/console's
  # flock. That makes `systemd-run --pipe` from a PTY block in the transient
  # service child, which in turn breaks nixos-rebuild-ng. Keep the hardware
  # UART getty on ttyMSM0 for serial rescue, but do not start the USB getty.
  systemd.services."serial-getty@ttyGS0".enable = false;

  nix = {
    buildMachines = lib.mkForce [ ];
    distributedBuilds = lib.mkForce false;
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8192;
    }
  ];

  system.stateVersion = "25.11";
}
