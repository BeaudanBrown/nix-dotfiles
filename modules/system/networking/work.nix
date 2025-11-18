{ pkgs, config, ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      networkmanager-openconnect = prev.networkmanager-openconnect.overrideAttrs (oldAttrs: {
        src = prev.fetchFromGitHub {
          owner = "BeaudanBrown";
          repo = "NetworkManager-openconnect";
          rev = "97236002b74035d22631eff858b314923e417447";
          hash = "sha256-96JOGxm2tEEpo26nsPnWJ93lIPNeLd4IZSnUIIBmnyo=";
        };
        nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ prev.autoreconfHook ];
      });
    })
  ];

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
              route-metric = "50";
            };
            ipv6 = {
              method = "disabled";
            };
            proxy = { };
            vpn = {
              authtype = "password";
              autoconnect-flags = "0";
              certsigs-flags = "0";
              cookie-flags = "2";
              disable_udp = "no";
              enable_csd_trojan = "yes";
              csd_wrapper = "${./hipreport.sh}";
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
