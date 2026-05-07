{
  lib,
  buildLinux,
  fetchFromGitLab,
  fetchFromGitHub,
  ...
}@args:
let
  src = args.src;
  kernelVersion = rec {
    # Fully constructed string, example: "5.10.0-rc5".
    string = "${
      version + "." + patchlevel + "." + sublevel + (lib.optionalString (extraversion != "") extraversion)
    }";
    file = "${src}/Makefile";
    version = toString (builtins.match ".+VERSION = ([0-9]+).+" (builtins.readFile file));
    patchlevel = toString (builtins.match ".+PATCHLEVEL = ([0-9]+).+" (builtins.readFile file));
    sublevel = toString (builtins.match ".+SUBLEVEL = ([0-9]+).+" (builtins.readFile file));
    # rc, next, etc.
    extraversion = toString (builtins.match ".+EXTRAVERSION = ([a-z0-9-]+).+" (builtins.readFile file));
  };
  modDirVersion = "${kernelVersion.string}";
in
(buildLinux (
  args
  // {
    inherit src;
    modDirVersion = "7.0.0-next-20260414-sdm845";
    enableCommonConfig = true;
    preferBuiltIn = true;
    ignoreConfigErrors = true;
    defconfig = "defconfig sdm845.config";
    autoModules = true;
    version = "${modDirVersion}";
    extraMeta = {
      platforms = [ "aarch64-linux" ];
      hydraPlatforms = [ "" ];
    };
  }
  // (args.argsOverride or { })
)).overrideAttrs
  (old: {
    postUnpack = ''
      cp ${../assets/arch-arm64-boot-dts-sdm845-Makefile} source/arch/arm64/boot/dts/qcom/Makefile
    '';
    NIX_CFLAGS_COMPILE = "-Wno-error=return-type -Wno-error=implicit-function-declaration -Wno-error=int-conversion";
  })
