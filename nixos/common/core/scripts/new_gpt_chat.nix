{ pkgs, ... }:
let
  script = ''

timestamp=$(date +%Y_%m_%d-%I_%M_%S_%p)
cp "$HOME"/.local/share/gpt/default.aichat "$HOME"/.local/share/gpt/"$timestamp".aichat
cp "$HOME"/.local/share/gpt/o1-mini.aichat "$HOME"/.local/share/gpt/"$timestamp"-o1.aichat
chmod 755 "$HOME"/.local/share/gpt/"$timestamp".aichat
chmod 755 "$HOME"/.local/share/gpt/"$timestamp"-o1.aichat
nvim -c 'normal G' -c 'startinsert!' -O "$HOME"/.local/share/gpt/"$timestamp".aichat \
  "$HOME"/.local/share/gpt/"$timestamp"-o1.aichat

  '';

  new_gpt_chat = pkgs.writeShellApplication {
    name = "new_gpt_chat";
    text = script;
  };
in
{
  environment.systemPackages = [
    new_gpt_chat
  ];
}

