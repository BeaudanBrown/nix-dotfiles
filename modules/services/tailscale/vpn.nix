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
    useRoutingFeatures = "client";
    extraUpFlags = [
      "--login-server=https://hs.bepis.lol"
      "--accept-dns=true"
      "--accept-routes=true"
    ];
  };
  sops.secrets."headscale/pre_auth" = { };
}
