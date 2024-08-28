{ pkgs, ... }:
let
  new_gpt_chat = pkgs.writeShellApplication {
    name = "new_gpt_chat";
    text = ''
      timestamp=$(date +%Y_%m_%d-%I_%M_%S_%p)
      cp "$HOME"/.local/share/gpt/default.aichat "$HOME"/.local/share/gpt/"$timestamp".aichat
      chmod 755 "$HOME"/.local/share/gpt/"$timestamp".aichat
      nvim -c 'normal G' -c 'startinsert!' "$HOME"/.local/share/gpt/"$timestamp".aichat
    '';
  };
in
{
  environment.systemPackages = [
    new_gpt_chat
  ];
}

