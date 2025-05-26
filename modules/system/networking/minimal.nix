{ config, ... }:
{
  users.users.${config.hostSpec.username}.extraGroups = [ "networkmanager" ];
  # TODO: get keys into the iso
  sops.secrets."wifi/home/ssid" = { };
  sops.secrets."wifi/home/psk" = { };

  networking = {
    wireless.enable = false;
    hostName = config.hostSpec.hostName;
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];

    networkmanager = {
      enable = true;
      ensureProfiles = {
        environmentFiles = [
          config.sops.secrets."wifi/home/ssid".path
          config.sops.secrets."wifi/home/psk".path
        ];
        profiles = {
          Monash = {
            connection = {
              autoconnect = "false";
              id = "Monash";
              type = "vpn";
            };
            ipv4 = {
              method = "auto";
            };
            ipv6 = {
              addr-gen-mode = "stable-privacy";
              method = "auto";
            };
            proxy = { };
            vpn = {
              authtype = "password";
              autoconnect-flags = "0";
              certsigs-flags = "0";
              cookie-flags = "2";
              disable_udp = "no";
              enable_csd_trojan = "no";
              gateway = "vpn.gp.monash.edu";
              gateway-flags = "2";
              gwcert-flags = "2";
              lasthost-flags = "0";
              pem_passphrase_fsid = "no";
              prevent_invalid_cert = "no";
              protocol = "gp";
              resolve-flags = "2";
              service-type = "org.freedesktop.NetworkManager.openconnect";
              stoken_source = "totp";
              useragent = "PAN";
              xmlconfig-flags = "0";
            };
            vpn-secrets = {
              "form:main:group_list" = "1 - Staff/HDR/PhD";
              lasthost = "vpn.gp.monash.edu";
              save_passwords = "yes";
            };
          };

          home-network = {
            connection = {
              id = "$HOME_WIFI_SSID";
              type = "wifi";
              autoconnect = "true";
            };
            wifi = {
              mode = "infrastructure";
              ssid = "$HOME_WIFI_SSID";
            };
            wifi-security = {
              auth-alg = "open";
              key-mgmt = "wpa-psk";
              psk = "$HOME_WIFI_PASSWORD";
            };
            ipv4 = {
              method = "auto";
            };
            ipv6 = {
              addr-gen-mode = "default";
              method = "auto";
            };
            proxy = { };
          };
        };
      };
    };
  };
}
