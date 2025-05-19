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
