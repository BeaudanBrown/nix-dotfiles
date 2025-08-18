{ pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
    networkmanager-openconnect
    networkmanagerapplet
    openconnect
  ];
  # TODO: get keys into the iso
  sops.secrets."wifi/home/ssid" = { };
  sops.secrets."wifi/home/psk" = { };
  services.resolved.enable = true;

  networking = {
    networkmanager = {
      dns = "systemd-resolved";
      plugins = [
        pkgs.networkmanager-openconnect
      ];
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
              route-metric = 600;
              never-default = "true";
              ignore-auto-dns = "false";
              # dns-search = [ "~monash.edu" "~ad.monash.edu" ];
            };
            ipv6 = {
              addr-gen-mode = "stable-privacy";
              method = "auto";
              never-default = "true";
              route-metric = 600;
              ignore-auto-dns = "false";
              # dns-search = [ "~monash.edu" "~ad.monash.edu" ];
            };
            proxy = { };
            vpn = {
              authtype = "password";
              autoconnect-flags = "0";
              certsigs-flags = "0";
              cookie-flags = "2";
              disable_udp = "no";
              enable_csd_trojan = "no";
              gateway = "vpn.gp.monash.edu/portal:prelogin-cookie";
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
        };
      };
    };
  };
}
