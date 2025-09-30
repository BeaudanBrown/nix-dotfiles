{ pkgs, config, ... }:
let
  script = # bash
    ''
      # User variables
      target_hostname=""
      target_ip=""
      target_user=${config.hostSpec.username}
      ssh_port=22
      ssh_key="${config.hostSpec.home}/.ssh/id_ed25519"
      persist_dir=""
      luks_passphrase="passphrase"
      luks_secondary_drive_labels=""
      dotfiles_dir="${config.hostSpec.dotfiles}"

      ### UX helpers

      function _print_color_message() {
        local color_code="$1"
        local prefix="$2"
        local message1="$3"

        echo -e "\x1B[''${color_code}''${prefix} ''${message1} \x1B[0m"
      }

      function red() {
        _print_color_message "31m" "[!]" "$1" "''${2-}"
      }

      function green() {
        _print_color_message "32m" "[+]" "$1" "''${2-}"
      }

      function blue() {
        _print_color_message "34m" "[*]" "$1" "''${2-}"
      }

      function yellow() {
        _print_color_message "33m" "[*]" "$1" "''${2-}"
      }

      function _ask_yes_no() {
        local prompt_message="$1"
        local default_answer="$2"
        local yn
        local default_display

        if [[ "$default_answer" == "y" ]]; then
          default_display="y"
        else
          default_display="n"
        fi

        echo -en "\x1B[34m[?] ''${prompt_message} [y/n] (default: ''${default_display}): \x1B[0m"
        while true; do
          read -rp "" yn
          yn=''${yn:-$default_answer} # Set to default if input is empty
          case $yn in
          [Yy]*) return 0 ;;
          [Nn]*) return 1 ;;
          esac
        done
      }

      # Ask yes or no, with yes being the default
      function yes_or_no() {
        _ask_yes_no "$*" "y"
      }

      # Ask yes or no, with no being the default
      function no_or_yes() {
        _ask_yes_no "$*" "n"
      }

      ### SOPS helpers

      function sops_add_age_key() {
        local keyname="$1"
        local key="$2"
        local sops_file="''${3:-.sops.yaml}"

        if [[ -n $(yq ".keys[] | select(anchor == \"$keyname\")" "''${sops_file}") ]]; then
          green "Updating existing ''${keyname} key"
          yq -i "(.keys[] | select(anchor == \"$keyname\")) = \"$key\"" "$sops_file"
        else
          green "Adding new ''${keyname} key"
          yq -i ".keys += [\"$key\"]
            | .keys[-1] anchor = \"$keyname\"
            | .creation_rules[].key_groups[].age += [\"''${keyname}\"]
            | .creation_rules[].key_groups[].age[-1] alias |= ." "$sops_file"
        fi
        repo_dirty=1
      }

      # Generate a user age key, update the .sops.yaml entries, and return the key in age_secret_key
      # args: user, hostname
      function sops_generate_user_age_key() {
        local target_user="$1"
        local target_hostname="$2"
        # local yaml_file="''${3:-secrets.yaml}"
        local key_name="''${target_user}_''${target_hostname}"

        green "Age key does not exist. Generating."
        age-keygen > "$temp"/user_age_key
        readarray -t entries < "$temp/user_age_key"
        public_key=$(echo "''${entries[1]}" | awk '{print $NF}')
        # age_secret_key=''${entries[2]}

        # sops decrypt $yaml_file > $yaml_file
        # yq -i '.ssh.$target_hostname.pub = "$public_key\" | .ssh.$target_hostname.priv = "$age_secret_key" | .ssh.$target_hostname.priv style="literal"' {}
        # sops encrypt $yaml_file > $yaml_file

        green "Generated age key for ''${key_name}"
        sops_add_age_key "$key_name" "$public_key" "$dotfiles_dir/.sops.yaml"
        sync "$target_user" "$temp/user_age_key" "/home/$target_user/.config/sops/age/keys.txt"
      }

      function sops_generate_host_age_key() {
        green "Generating an age key based on the new ssh_host_ed25519_key"

        # Get the SSH key
        target_key=$(ssh-keyscan -p "$ssh_port" -t ssh-ed25519 "$target_ip" 2>&1 | grep ssh-ed25519 | cut -f2- -d" ") || {
          red "Failed to get ssh key. Host down or maybe SSH port now changed?"
          exit 1
        }

        host_age_key=$(echo "$target_key" | ssh-to-age)

        if grep -qv '^age1' <<<"$host_age_key"; then
          red "The result from generated age key does not match the expected format."
          yellow "Result: $host_age_key"
          yellow "Expected format: age10000000000000000000000000000000000000000000000000000000000"
          exit 1
        fi

        green "Updating secrets/.sops.yaml"
        sops_add_age_key "$target_hostname" "$host_age_key" "$dotfiles_dir/.sops.yaml"
      }

      # Create a temp directory for generated host keys
      temp=$(mktemp -d)

      # Cleanup temporary directory on exit
      function cleanup() {
        rm -rf "$temp"
      }
      trap cleanup exit

      # Copy data to the target machine
      function sync() {
        local user="$1"
        local source="$2"
        local destination="''${3:-$dotfiles_dir}"
        rsync -av --mkpath --filter=':- .gitignore' -e "ssh -oControlMaster=no -l $user -oport=$ssh_port" "$source" "$user@$target_ip:$destination"
      }

      # Usage function
      function help_and_exit() {
        echo
        echo "Remotely installs NixOS on a target machine using this nix-dotfiles."
        echo
        echo "USAGE: $0 -n <target_hostname> -d <target_ip> -k <ssh_key> [OPTIONS]"
        echo
        echo "ARGS:"
        echo "  -n <target_hostname>                    specify target_hostname of the target host to deploy the nixos config on."
        echo "  -d <target_ip>                 specify ip or domain to the target host."
        echo "  -k <ssh_key>                            specify the full path to the ssh_key you'll use for remote access to the"
        echo "                                          target during install process."
        echo "                                          Example: -k ${config.hostSpec.home}/.ssh/my_ssh_key"
        echo
        echo "OPTIONS:"
        echo "  -u <target_user>                        specify target_user with sudo access. nix-dotfiles will be cloned to their home."
        echo "                                          Default='${config.hostSpec.username}'."
        echo "  --port <ssh_port>                       specify the ssh port to use for remote access. Default=$ssh_port."
        echo '  --luks-secondary-drive-labels <drives>  specify the luks device names (as declared with "disko.devices.disk.*.content.luks.name" in host/common/disks/*.nix) separated by commas.'
        echo '                                          Example: --luks-secondary-drive-labels "cryptprimary,cryptextra"'
        echo "  --impermanence                          Use this flag if the target machine has impermanence enabled. WARNING: Assumes /persist path."
        echo "  --debug                                 Enable debug mode."
        echo "  -h | --help                             Print this help."
        exit 0
      }

      # Handle command-line arguments
      while [[ $# -gt 0 ]]; do
        case "$1" in
        -n)
          shift
          target_hostname=$1
          ;;
        -d)
          shift
          target_ip=$1
          ;;
        -u)
          shift
          target_user=$1
          ;;
        -k)
          shift
          ssh_key=$1
          ;;
        --luks-secondary-drive-labels)
          shift
          luks_secondary_drive_labels=$1
          ;;
        --port)
          shift
          ssh_port=$1
          ;;
        --temp-override)
          shift
          temp=$1
          ;;
        --impermanence)
          persist_dir="/persist"
          ;;
        --debug)
          set -x
          ;;
        -h | --help) help_and_exit ;;
        *)
          red "ERROR: Invalid option detected."
          help_and_exit
          ;;
        esac
        shift
      done

      if [ -z "$target_hostname" ] || [ -z "$target_ip" ] || [ -z "$ssh_key" ]; then
        red "ERROR: -n, -d, and -k are all required"
        echo
        help_and_exit
      fi

      # SSH commands
      ssh_cmd="ssh \
              -oControlPath=none \
              -oport=$ssh_port \
              -oForwardAgent=yes \
              -oStrictHostKeyChecking=no \
              -oUserKnownHostsFile=/dev/null \
              -i $ssh_key \
              -t $target_user@$target_ip"
      # shellcheck disable=SC2001
      ssh_root_cmd=$(echo "$ssh_cmd" | sed "s|$target_user@|root@|") # uses @ in the sed switch to avoid it triggering on the $ssh_key value
      scp_cmd="scp -oControlPath=none -oport=$ssh_port -oStrictHostKeyChecking=no -i $ssh_key"

      # Setup minimal environment for nixos-anywhere and run it
      repo_dirty=0
      function nixos_anywhere() {
        # Clear the known keys, since they should be newly generated for the iso
        green "Wiping known_hosts of $target_ip"
        sed -i "/$target_hostname/d; /$target_ip/d" ~/.ssh/known_hosts

        green "Installing NixOS on remote host $target_hostname at $target_ip"

        ###
        # nixos-anywhere extra-files generation
        ###
        green "Preparing a new ssh_host_ed25519_key pair for $target_hostname."
        # Create the directory where sshd expects to find the host keys
        install -d -m755 "$temp/$persist_dir/etc/ssh"

        # Generate host ssh key pair without a passphrase
        ssh-keygen -t ed25519 -f "$temp/$persist_dir/etc/ssh/ssh_host_ed25519_key" -C "$target_user"@"$target_hostname" -N ""

        # Set the correct permissions so sshd will accept the key
        chmod 600 "$temp/$persist_dir/etc/ssh/ssh_host_ed25519_key"

        green "Adding ssh host fingerprint at $target_ip to ~/.ssh/known_hosts"
        # This will fail if we already know the host, but that's fine
        ssh-keyscan -p "$ssh_port" "$target_ip" | grep -v '^#' >>~/.ssh/known_hosts || true

        ###
        # nixos-anywhere installation
        ###
        cd nixos-installer
        # when using luks, disko expects a passphrase on /tmp/disko-password, so we set it for now and will update the passphrase later
        if no_or_yes "Manually set luks encryption passphrase? (Default: \"$luks_passphrase\")"; then
          blue "Enter your luks encryption passphrase:"
          read -rs luks_passphrase
          $ssh_root_cmd "/bin/sh -c 'echo $luks_passphrase > /tmp/disko-password'"
        else
          green "Using '$luks_passphrase' as the luks encryption passphrase. Change after installation."
          $ssh_root_cmd "/bin/sh -c 'echo $luks_passphrase > /tmp/disko-password'"
        fi
        # this will run if luks_secondary_drive_labels cli argument was set, regardless of whether the luks_passphrase is default or not
        if [ -n "$luks_secondary_drive_labels" ]; then
          luks_setup_secondary_drive_decryption
        fi

        # If you are rebuilding a machine without any hardware changes, this is likely unneeded or even possibly disruptive
        if no_or_yes "Generate a new hardware config for this host? Yes if your nix-dotfiles doesn't have an entry for this host."; then
          green "Generating hardware-configuration.nix on $target_hostname and adding it to the local nix-dotfiles."
          $ssh_root_cmd "nixos-generate-config --no-filesystems --root /mnt"
          $scp_cmd "$target_user"@"$target_ip":/mnt/etc/nixos/hardware-configuration.nix \
            ''${dotfiles_dir}/hosts/"$target_hostname"/hardware.nix
          git add "$dotfiles_dir/hosts/$target_hostname/hardware.nix"
          repo_dirty=1
        fi

        # --extra-files here picks up the ssh host key we generated earlier and puts it onto the target machine
        nixos-anywhere \
          --ssh-port "$ssh_port" \
          --post-kexec-ssh-port "$ssh_port" \
          --extra-files "$temp" \
          --flake .#"$target_hostname" \
          root@"$target_ip"

        if ! yes_or_no "Has your system restarted and are you ready to continue? (no exits)"; then
          exit 0
        fi

        green "Adding $target_ip's ssh host fingerprint to ~/.ssh/known_hosts"
        ssh-keyscan -p "$ssh_port" "$target_ip" | grep -v '^#' >>~/.ssh/known_hosts || true

        if [ -n "$persist_dir" ]; then
          $ssh_root_cmd "cp /etc/machine-id $persist_dir/etc/machine-id || true"
          $ssh_root_cmd "cp -R /etc/ssh/ $persist_dir/etc/ssh/ || true"
        fi
        cd - >/dev/null
      }

      function luks_setup_secondary_drive_decryption() {
        green "Generating /luks-secondary-unlock.key"
        local key=$persist_dir/luks-secondary-unlock.key
        $ssh_root_cmd "dd bs=512 count=4 if=/dev/random of=$key iflag=fullblock && chmod 400 $key"

        green "Cryptsetup luksAddKey will now be used to add /luks-secondary-unlock.key for the specified secondary drive names."
        readarray -td, drivenames <<<"$luks_secondary_drive_labels"
        for name in "''${drivenames[@]}"; do
          device_path=$($ssh_root_cmd -q "cryptsetup status \"$name\" | awk \'/device:/ {print \$2}\'")
          $ssh_root_cmd "echo \"$luks_passphrase\" | cryptsetup luksAddKey $device_path /luks-secondary-unlock.key"
        done
      }

      # Validate required options
      # FIXME(bootstrap): The ssh key and destination aren't required if only rekeying, so could be moved into specific sections?
      if [ -z "$target_hostname" ] || [ -z "$target_ip" ] || [ -z "$ssh_key" ]; then
        red "ERROR: -n, -d, and -k are all required"
        echo
        help_and_exit
      fi

      if yes_or_no "Run nixos-anywhere installation?"; then
        nixos_anywhere
      fi

      updated_age_keys=0
      if yes_or_no "Generate host (ssh-based) age key?"; then
        sops_generate_host_age_key
        updated_age_keys=1
      fi

      if yes_or_no "Generate user age key?"; then
        sops_generate_user_age_key "$target_user" "$target_hostname"
        updated_age_keys=1
      fi

      if [[ $updated_age_keys == 1 ]]; then
        cd $dotfiles_dir
        sops updatekeys $dotfiles_dir/secrets.yaml
        repo_dirty=1
        cd -
      fi

      if yes_or_no "Do you want to copy your full nix-dotfiles and nix-secrets to $target_hostname?"; then
        green "Adding ssh host fingerprint at $target_ip to ~/.ssh/known_hosts"
        ssh-keyscan -p "$ssh_port" "$target_ip" 2>/dev/null | grep -v '^#' >>~/.ssh/known_hosts || true
        green "Copying full nix-dotfiles to $target_hostname"
        sync "$target_user" "$dotfiles_dir/"

        # FIXME(bootstrap): Add some sort of key access from the target to download the config (if it's a cloud system)
        if yes_or_no "Do you want to rebuild immediately?"; then
          green "Rebuilding nix-dotfiles on $target_hostname"
          # FIXME(bootstrap): This should probably only happen on devices that require it
          $ssh_cmd "cd $dotfiles_dir && nix-prefetch-url --name displaylink-610.zip https://www.synaptics.com/sites/default/files/exe_files/2024-10/DisplayLink%20USB%20Graphics%20Software%20for%20Ubuntu6.1-EXE.zip"
          $ssh_cmd "cd $dotfiles_dir && nix-prefetch-url --name linuxx64-25.05.0.44.tar.gz https://send.bepis.lol/api/shares/citrix/files/a11fbff3-4c9b-4d28-a0e9-2307a71d0899"
          $ssh_cmd "cd $dotfiles_dir && sudo nixos-rebuild --impure --show-trace --flake .#$target_hostname switch"
        fi
      else
        echo
        green "NixOS was successfully installed!"
        echo "Post-install config build instructions:"
        echo "To copy nix-dotfiles from this machine to the $target_hostname, run the following command"
        echo "just sync $target_user $target_ip"
        echo "To rebuild, sign into $target_hostname and run the following command"
        echo "cd nix-dotfiles"
        echo "sudo nixos-rebuild --show-trace --flake .#$target_hostname switch"
        echo
      fi

      if [[ $repo_dirty == 1 ]]; then
        if yes_or_no "Do you want to commit and push the generated hardware.nix for $target_hostname to nix-dotfiles?"; then
          (pre-commit run --all-files 2>/dev/null || true) &&
            git add "$dotfiles_dir/secrets.yaml" &&
            git add "$dotfiles_dir/.sops.yaml" &&
            (git commit -m "feat: init for $target_hostname" || true) &&
            git push
        fi
      fi

      green "Success!"
    '';
in
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "bootstrap_nixos";
      text = script;
      runtimeInputs = with pkgs; [
        gawk
        rsync
        git
        just
        yq-go
        age
        ssh-to-age
        nixos-anywhere
      ];
    })
  ];
}
