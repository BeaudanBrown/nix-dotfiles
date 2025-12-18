{ ... }:
{
  hostedServices = [
    {
      domain = "lights.bepis.lol";
      upstreamHost = "100.64.0.8";
      upstreamPort = "5000";
    }
  ];
}
