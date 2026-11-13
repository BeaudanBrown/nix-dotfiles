{ ... }:
{
  networking.hostId = (builtins.substring 0 8 "f3e9ee24");

  # Adopt NAS's existing DHCP Ethernet profile, retaining its UUID and runtime
  # filename rather than creating a competing autoconnect profile. Public DNS must work before
  # Headscale/Tailscale start. More-specific global private routes still win
  # over this link's ~. route; the global lan search suffix remains intact.
  networking.networkmanager.ensureProfiles.profiles."Wired connection 2" = {
    connection = {
      id = "Wired connection 2";
      uuid = "54da3c1f-8edb-3f8d-89e1-87a1ebe1c783";
      type = "ethernet";
      interface-name = "enp7s0";
      autoconnect = true;
    };
    ipv4 = {
      method = "auto";
      dns = "1.1.1.1;9.9.9.9;";
      dns-search = "~.;";
      ignore-auto-dns = true;
    };
    ipv6 = {
      method = "auto";
      ignore-auto-dns = true;
    };
  };
}
