{ ... }:
{
  services.atuin = {
    enable = true;
    host = "0.0.0.0";
    port = 8888;
    openFirewall = true;
    openRegistration = true;
  };
}
