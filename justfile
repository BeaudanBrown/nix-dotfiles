# default recipe to display help information
default:
  @just --list

sops_host := "nas"
sops_repo := "/home/beau/sops-secrets"
sops_dotfiles_repo := "/home/beau/documents/nix-dotfiles"

# Update the flake
update:
  nix flake update

# Generate a new age key
age-key:
  nix-shell -p age --run "age-keygen"

# Provision an encrypted, fleet-generic installer USB interactively.
installer-usb:
  nix run .#fleet-installer -- provision-usb

# Fast installer unit and integration tests.
test-installer:
  nix build .#checks.$(nix eval --impure --raw --expr builtins.currentSystem).fleet-installer
  nix build .#fleet-installer
  nix develop -c bash tests/fleet-installer/nas-rekey.sh
  bash tests/fleet-installer/evaluate-hosts.sh

# Provision and cache a pristine encrypted installer USB in rootless QEMU.
test-installer-e2e-provision:
  timeout --signal=TERM --kill-after=30s 30m nix develop -c python tests/installer-e2e/run.py --provision-only

# Iterate on target installation from a snapshot of the cached USB.
test-installer-e2e-install:
  timeout --signal=TERM --kill-after=30s 15m nix develop -c python tests/installer-e2e/install-phase.py

# Full rootless QEMU installer test.
test-installer-e2e:
  ./tests/installer-e2e/run.sh

# Copy all the config files to the remote host
sync USER HOST PATH:
	rsync -av --filter=':- .gitignore' -e "ssh -l {{USER}} -oport=22" . {{USER}}@{{HOST}}:{{PATH}}/nix-config

# Generate .sops.yaml from hostSpecs
gen-sops-yaml:
  @ssh {{sops_host}} 'cd {{sops_dotfiles_repo}} && ./scripts/gen-sops-yaml.sh {{sops_repo}}'
  @ssh {{sops_host}} 'cd {{sops_repo}} && git add .sops.yaml && if ! git diff --cached --quiet; then git commit -m "Regenerate .sops.yaml"; git push; else echo "No .sops.yaml changes to commit"; fi'
  @nix flake lock --update-input sopsSecrets

# Generate explicit import list for a host (inventory/explicit-imports -> generated/imports/<host>.nix)
gen-imports HOST:
  nix run .#generate-host-imports -- {{HOST}} --repo .

update-sops:
  @ssh {{sops_host}} 'cd {{sops_repo}} && for file in secrets/*.yaml; do if sops --decrypt "$file" > /dev/null 2>&1; then echo "Updating keys for $file..."; sops updatekeys -y "$file"; else echo "Skipping $file (cannot decrypt)"; fi; done && git add secrets .sops.yaml && if ! git diff --cached --quiet; then git commit -m "Update SOPS secrets"; git push; else echo "No secret changes to commit"; fi'
  @nix flake lock --update-input sopsSecrets

# Connect to the OnePlus U-Boot USB serial gadget
oneplus-serial DEVICE="/dev/ttyACM0":
  sudo nix shell nixpkgs#picocom -c picocom {{DEVICE}} -b 115200

# ---------- Push-deploy helpers ----------
# Generic: use an SSH config Host alias for {{HOST}}
# Requires the target user to have passwordless sudo for nixos-rebuild.
# Example alias already present: 'pi4' (user beau, host 192.168.1.122, port 8023)

# Build the system closure for a host on this machine (NAS)
build HOST:
  nix build .#nixosConfigurations.{{HOST}}.config.system.build.toplevel

# Dry-activate on the remote without switching (useful for validation)
deploy-test HOST:
  nixos-rebuild test --flake .#{{HOST}} --target-host {{HOST}} --use-remote-sudo

# Switch the remote host to the new configuration (push deploy)
deploy HOST:
  nixos-rebuild switch --flake .#{{HOST}} --target-host {{HOST}} --use-remote-sudo

# Convenience wrappers for Pi 4
build-pi4:
  just build pi4

deploy-test-pi4:
  just deploy-test pi4

deploy-pi4:
  just deploy pi4
