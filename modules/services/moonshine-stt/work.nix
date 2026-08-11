{ pkgs, ... }:
let
  moonshineStt = pkgs.callPackage ../../../packages/moonshine-stt { };
  modelDir = "${moonshineStt}/share/moonshine-stt/small-streaming-en";
in
{
  environment.systemPackages = [ moonshineStt ];

  hm.primary.systemd.user.services.moonshine-stt = {
    Unit = {
      Description = "Local Moonshine streaming speech-to-text daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${moonshineStt}/bin/moonshine-stt-daemon ${modelDir} %t/moonshine-stt/stt.sock";
      Restart = "on-failure";
      RestartSec = 1;
      RuntimeDirectory = "moonshine-stt";
      RuntimeDirectoryMode = "0700";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = [ "AF_UNIX" ];
      LockPersonality = true;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
