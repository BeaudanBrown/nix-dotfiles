# Only public locked inputs. Don't load the fleet flake (or its secrets) in tests.
let
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  locked = name: lock.nodes.${lock.nodes.root.inputs.${name}}.locked;
  source = name: builtins.fetchTree (locked name);
  numtide = locked "nix-ai-tools";
in
{
  nixpkgs = source "nixpkgs";
  agent-workshop = builtins.getFlake "github:${(locked "agent-workshop").owner}/${(locked "agent-workshop").repo}/${(locked "agent-workshop").rev}";
  home-manager = source "home-manager";
  agent-tools-nixpkgs.legacyPackages.x86_64-linux = import (source "agent-tools-nixpkgs") {
    system = "x86_64-linux";
  };
  nix-ai-tools = builtins.getFlake "github:${numtide.owner}/${numtide.repo}/${numtide.rev}";
}
