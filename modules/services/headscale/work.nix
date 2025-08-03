{ ... }:
{
  # fileSystems."/var/lib/litellm" = {
  #   device = "/pool1/appdata/litellm";
  #   options = [ "bind" ];
  # };
  # systemd.tmpfiles.rules = [
  #   "d /pool1/appdata/litellm/ 0700 vaultwarden vaultwarden - -"
  # ];
  services.tailscale = {
    enable = true;
    authKeyParameters.baseURL = "lan.bepis.lol";
  };
}
