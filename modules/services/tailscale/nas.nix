{ ... }:
{
  services.tailscale = {
    useRoutingFeatures = "server";
    extraUpFlags = [
      "--accept-dns=false"
      "--advertise-exit-node"
    ];
  };
}
