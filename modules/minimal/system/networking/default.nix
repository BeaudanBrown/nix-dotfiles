{ config, ... }:
{
  users.users.${config.hostSpec.username}.extraGroups = [ "networkmanager" ];
  # TODO: get keys into the iso
  # sops.secrets."wireless.env" = { };

  networking = {
    wireless.enable = false;
    hostName = config.hostSpec.hostName;
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];

    networkmanager = {
      enable = true;
      # ensureProfiles = {
      #   environmentFiles = [ config.sops.secrets."wireless.env".path ];
      #   profiles = {
      #     home-wifi = {
      #       connection.id = "home-wifi";
      #       connection.type = "wifi";
      #       wifi.ssid = "$HOME_WIFI_SSID";
      #       wifi-security = {
      #         auth-alg = "open";
      #         key-mgmt = "wpa-psk";
      #         psk = "$HOME_WIFI_PASSWORD";
      #       };
      #     };
      #   };
      # };
    };
  };
}
