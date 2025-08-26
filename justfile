# default recipe to display help information
default:
  @just --list

# Update the flake
update:
  nix flake update

# Generate a new age key
age-key:
  nix-shell -p age --run "age-keygen"

iso:
  rm -rf result
  nix build --impure .#nixosConfigurations.iso.config.system.build.isoImage && ln -sf result/iso/*.iso latest.iso

# Install the latest iso to a flash drive
iso-install DRIVE: iso
  sudo dd if=$(ls --sort time result/iso/*.iso | tail -n1) of={{DRIVE}} bs=4M status=progress oflag=sync

# Copy all the config files to the remote host
sync USER HOST PATH:
	rsync -av --filter=':- .gitignore' -e "ssh -l {{USER}} -oport=22" . {{USER}}@{{HOST}}:{{PATH}}/nix-config

update-sops:
  sops updatekeys -y secrets.yaml

test-iso:
  qemu-system-x86_64 \
      -m 4096M \
      --drive media=cdrom,file=latest.iso,format=raw,readonly=on \
      --smp cores=4,sockets=1,threads=1 \

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
