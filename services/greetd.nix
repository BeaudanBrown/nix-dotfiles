{ pkgs, lib, ... }:
{
  config = {
    environment.systemPackages = with pkgs; [ greetd.tuigreet sx ];
    services.greetd = {
      enable = true;

      restart = true;
      settings = {
        default_session = {
          # command = "${pkgs.greetd.tuigreet}/bin/tuigreet --asterisks --time --time-format '%I:%M %p | %a • %h | %F' --cmd bspwm";
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --asterisks --time --remember --cmd 'sx bspwm'";
          user = "beau";
        };
      };
    };

    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYReset = true;
      TTYHangup = true;
      TTYDisallocate = true;
    };
  };
}
