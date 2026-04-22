# Shared option that exposes the LiteLLM model catalog to other modules.
# The litellm service module (nas.nix) populates this; consumers like
# openclaw and opencode read it to stay in sync automatically.
{ lib, ... }:
{
  options.custom.litellm.models = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Model names available through the LiteLLM proxy.  Populated
      automatically from the litellm service config — do not set manually.
    '';
  };
}
