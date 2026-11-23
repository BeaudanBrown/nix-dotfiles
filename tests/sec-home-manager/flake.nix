{
  description = "Isolated evaluation of main-root sec Home Manager integration";

  inputs.agent-workshop.url = "github:BeaudanBrown/agent-workshop";

  outputs =
    { agent-workshop, ... }:
    {
      result = import ./eval.nix { inherit agent-workshop; };
    };
}
