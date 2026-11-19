{ ... }:
{
  # Adopt the existing DHCP profile so it cannot compete with our WoL profile.
  networking.networkmanager.ensureProfiles.profiles."Wired connection 1" = {
    connection = {
      id = "Wired connection 1";
      uuid = "63077a2b-c51d-32c0-abc2-199f5b4b1159";
      type = "ethernet";
      interface-name = "enp6s0";
      autoconnect = true;
    };
    ethernet.wake-on-lan = 64; # NM_SETTING_WIRED_WAKE_ON_LAN_MAGIC
    ipv4.method = "auto";
    ipv6.method = "auto";
  };
}
