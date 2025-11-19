{
  ...
}:
{
  hostedServices = [
    {
      domain = "lights.bepis.lol";
      upstreamHost = "100.64.0.8"; # Pi Zero Tailscale IP
      upstreamPort = "5000";
    }
  ];
}
