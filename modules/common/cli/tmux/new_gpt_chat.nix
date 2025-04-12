{ pkgs, ... }:
let
  script = ''
    # Create today's date folder
    date_folder="$HOME/.local/share/gpt/$(date +%Y-%m-%d)"
    mkdir -p "$date_folder"

    # Copy the default AI chat files to the date folder if they don't exist yet
    if [ ! -f "$date_folder/default.aichat" ]; then
      cp "$HOME/.local/share/gpt/default.aichat" "$date_folder/default.aichat"
      chmod 755 "$date_folder/default.aichat"
    fi

    if [ ! -f "$date_folder/o3-mini.aichat" ]; then
      cp "$HOME/.local/share/gpt/o3-mini.aichat" "$date_folder/o3-mini.aichat"
      chmod 755 "$date_folder/o3-mini.aichat"
    fi

    # Change to the date directory
    cd "$date_folder"

    # Open default chat with vim
    nvim \
      -c "autocmd BufLeave <buffer> silent! write" \
      -c 'normal G' \
      -c 'startinsert!' -O default.aichat
  '';

in
pkgs.writeShellApplication {
  name = "new_gpt_chat";
  text = script;
}
