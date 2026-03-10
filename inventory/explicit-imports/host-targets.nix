{
  agent = {
    roots = [
      "minimal"
      "common"
      "network"
    ];
    includeHostStem = true;
    resolveGraph = false;
  };

  bottom = {
    roots = [
      "minimal"
      "common"
      "network"
    ];
    includeHostStem = true;
    resolveGraph = false;
  };

  brick = {
    roots = [
      "minimal"
      "common"
      "network"
      "server"
    ];
    includeHostStem = true;
    resolveGraph = false;
  };

  grill = {
    roots = [ "gaming" ];
    includeHostStem = true;
  };

  iso = {
    roots = [ "minimal" ];
    includeHostStem = true;
    resolveGraph = false;
  };

  laptop = {
    roots = [
      "minimal"
      "common"
      "network"
      "main"
      "work"
    ];
    includeHostStem = true;
    resolveGraph = false;
  };

  nas = {
    roots = [
      "minimal"
      "common"
      "network"
      "main"
      "server"
    ];
    includeHostStem = true;
    resolveGraph = false;
  };

  pi4 = {
    roots = [
      "minimal"
      "common"
      "network"
      "client"
    ];
    includeHostStem = true;
    resolveGraph = false;
  };

  t480 = {
    roots = [ "gaming" ];
    includeHostStem = true;
  };
}
