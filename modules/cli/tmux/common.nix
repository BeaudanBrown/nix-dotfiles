{ pkgs, ... }:
let
  llm = import ./new_gpt_chat.nix { inherit pkgs; };
  tmux_toggle_popup = import ./tmux_toggle_popup.nix { inherit pkgs; };
in
{
  environment.systemPackages = [
    llm
    tmux_toggle_popup
  ];
}
