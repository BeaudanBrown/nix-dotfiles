# Temporary pin to the kernel/modules currently running on pi4.
# This avoids rebuilding the Raspberry Pi vendor kernel while the newer
# nixos-hardware kernel output is not available from a public cache.
# Remove this file/import once the newer kernel is built and cached.
{ lib, pkgs, ... }:

let
  # Minimal config metadata needed by NixOS' sysctl generation for this pinned
  # Raspberry Pi kernel. The Pi arm64 kernel uses a 39-bit userspace VA range,
  # whose maximum mmap ASLR entropy is 24 bits.
  kernelConfig = pkgs.writeText "linux-config-6.12.47-stable_20250916" ''
    CONFIG_ARCH_MMAP_RND_BITS_MAX=24
    CONFIG_ARCH_MMAP_RND_COMPAT_BITS_MAX=16
  '';

  kconfig = rec {
    isEnabled = name: name == "IP_NF_MATCH_RPFILTER";
    isSet = name: name == "MODULES" || isEnabled name;
    isYes = name: name == "MODULES" || isEnabled name;
  };

  oldKernel = rec {
    type = "derivation";
    name = "linux-rpi-6.12.47-stable_20250916";
    pname = "linux-rpi";
    version = "6.12.47-stable_20250916";
    modDirVersion = "6.12.47";
    system = "aarch64-linux";

    outPath = "/nix/store/80sbai64nvzxc4xa214zbaf1pk4qy3ys-linux-rpi-6.12.47-stable_20250916";
    drvPath = "/nix/store/01712qhl409bv2gd5z83zkwn9zf93gwh-linux-rpi-6.12.47-stable_20250916.drv";
    outputs = [
      "out"
      "modules"
    ];

    out = oldKernel;
    modules = "/nix/store/jjgg3s3zxc1vqs2p5my2wp6lifagiyc2-linux-rpi-6.12.47-stable_20250916-modules";
    configfile = kernelConfig;

    stdenv = pkgs.stdenv;
    config = kconfig;
    features.netfilterRPFilter = true;
    isModular = true;
    isHardened = false;
    commonMakeFlags = [ ];

    kernelOlder = v: lib.versionOlder version v;
    kernelAtLeast = v: lib.versionAtLeast version v;

    override = _: oldKernel;
    overrideAttrs = _: oldKernel;
    passthru = { };
    meta = { };
  };
in
{
  boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor oldKernel);
}
