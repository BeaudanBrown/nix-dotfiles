{
  # T480-first root graph.
  # Start from `gaming` and inherit the full workstation stack.
  minimal = {
    extends = [ ];
  };

  common = {
    extends = [ "minimal" ];
  };

  network = {
    extends = [ "common" ];
  };

  client = {
    extends = [ "network" ];
  };

  main = {
    extends = [ "client" ];
  };

  work = {
    extends = [ "main" ];
  };

  gaming = {
    extends = [ "work" ];
  };
}
