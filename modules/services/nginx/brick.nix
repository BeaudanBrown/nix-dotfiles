{ ... }:
{
  services.nginx = {
    enable = true;
    proxyTimeout = "240s";
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };
  security.acme = {
    acceptTerms = true;
    defaults.email = "beaudan.brown@gmail.com";
  };
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
    ];
  };
}
