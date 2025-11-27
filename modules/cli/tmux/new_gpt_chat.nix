{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "LLM";
  text = builtins.readFile ./new_gpt_chat.sh;
}
