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
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
    ];
  };
}
