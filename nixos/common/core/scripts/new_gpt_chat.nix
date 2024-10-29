{ pkgs, ... }:
let
  new_gpt_chat = pkgs.writeShellApplication {
    name = "new_gpt_chat";
    text = ''
    title="default"

# Parse command line options
    while getopts "n:" opt; do
      case $opt in
        n)
          title=$OPTARG
          ;;
        *)
          echo "Usage: $0 [-n <title>]"
          exit 1
          ;;
      esac
    done

    timestamp=$(date +%Y_%m_%d-%I_%M_%S_%p)
    source_file="$HOME/.local/share/gpt/$title.aichat"
    destination_file="$HOME/.local/share/gpt/$timestamp.aichat"

# Check if the source file exists
    if [[ ! -f "$source_file" ]]; then
      echo "Source file '$source_file' does not exist."
      exit 1
    fi

# Copy the file
    cp "$source_file" "$destination_file"

# Set permissions
    chmod 755 "$destination_file"

# Open file with nvim
    nvim -c 'normal G' -c 'startinsert!' "$destination_file"
    '';
  };
in
{
  environment.systemPackages = [
    new_gpt_chat
  ];
}

