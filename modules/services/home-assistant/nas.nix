{ config, ... }:
{
  services.home-assistant = {
    enable = true;
    config = {
      homeassistant = {
        name = "Home";
        # latitude = "!secret latitude";
        # longitude = "!secret longitude";
        # elevation = "!secret elevation";
        unit_system = "metric";
        # time_zone = "UTC";
      };
      http = { };
    };
  };
}
