{ ... }:
{
  hm.programs.watson = {
    enable = true;
  };

  syncedState = [
    {
      source = ".config/watson/frames";
      target = "watson/frames";
    }
    {
      source = ".config/watson/state";
      target = "watson/state";
    }
  ];
}
