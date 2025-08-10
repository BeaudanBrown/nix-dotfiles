{ config, ... }:
{
  networking.firewall = {
    checkReversePath = "loose";
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets."headscale/pre_auth".path;
    extraUpFlags = [ "--login-server=https://hs.bepis.lol" ];
  };
  sops.secrets."headscale/pre_auth" = { };
}
