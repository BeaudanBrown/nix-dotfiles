{ ... }:
{
  services.deskflow = {
    enable = true;
    role = "client";
    serverAddress = "grill.lan:24800";
  };
}
