{
  pkgs,
  config,
}:
let
  generateHostImports = pkgs.callPackage ../../../scripts/generate-host-imports.nix { };
in
pkgs.writeShellApplication {
  name = "nr";
  text = ''
    repo="${config.hostSpec.dotfiles}"
    host="${config.hostSpec.hostName}"

    if [ "$host" = "oneplus" ]; then
      cd "$repo"
      ${generateHostImports}/bin/generate-host-imports oneplus --repo .

      new_system="$(${pkgs.nix}/bin/nix build --no-link --print-out-paths --extra-experimental-features 'fetch-closure' .#nixosConfigurations.oneplus.config.system.build.toplevel)"
      sudo /run/current-system/sw/bin/systemd-run --wait --collect --unit=oneplus-set-boot /run/current-system/sw/bin/sh -lc "exec >/var/log/oneplus-set-boot.log 2>&1; /run/current-system/sw/bin/nix-env -p /nix/var/nix/profiles/system --set '$new_system'; STC_DEBUG=1 '$new_system/bin/switch-to-configuration' boot"
    else
      ${generateHostImports}/bin/generate-host-imports "$host" --repo "$repo"
      ${pkgs.nh}/bin/nh os switch "$repo" --accept-flake-config
    fi
  '';
}
