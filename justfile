# default recipe to display help information
default:
  @just --list

sops_repo := "/home/beau/documents/projects/sops-secrets"

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

# Generate .sops.yaml from hostSpecs
gen-sops-yaml:
  ./scripts/gen-sops-yaml.sh {{sops_repo}}
  @git -C {{sops_repo}} add .sops.yaml
  @if ! git -C {{sops_repo}} diff --cached --quiet; then \
    git -C {{sops_repo}} commit -m "Regenerate .sops.yaml"; \
    git -C {{sops_repo}} push; \
    nix flake lock --update-input sopsSecrets; \
  else \
    echo "No .sops.yaml changes to commit"; \
  fi

# Generate explicit import list for a host (inventory/explicit-imports -> generated/imports/<host>.nix)
gen-imports HOST:
  nix run .#generate-host-imports -- {{HOST}} --repo .

update-sops:
  @cd {{sops_repo}} && for file in secrets/*.yaml; do \
    if sops --decrypt "$file" > /dev/null 2>&1; then \
      echo "Updating keys for $file..."; \
      sops updatekeys -y "$file"; \
    else \
      echo "Skipping $file (cannot decrypt)"; \
    fi; \
  done
  @git -C {{sops_repo}} add secrets .sops.yaml
  @if ! git -C {{sops_repo}} diff --cached --quiet; then \
    git -C {{sops_repo}} commit -m "Update SOPS secrets"; \
    git -C {{sops_repo}} push; \
    nix flake lock --update-input sopsSecrets; \
  else \
    echo "No secret changes to commit"; \
  fi

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
