{
  bash,
  coreutils,
  fetchFromGitHub,
  findutils,
  gawk,
  git,
  gnugrep,
  gnused,
  jq,
  ripgrep,
  writeShellApplication,
}:
let
  src = fetchFromGitHub {
    owner = "wedow";
    repo = "ticket";
    rev = "v0.3.2";
    sha256 = "1pc3vp3wnmgm8zfv3sy7zg4vyrk0cgkk6gg2gg3y4bs1081nmg52";
  };
in
writeShellApplication {
  name = "tk";

  runtimeInputs = [
    coreutils
    findutils
    gawk
    git
    gnugrep
    gnused
    jq
    ripgrep
  ];

  text = ''
    exec ${bash}/bin/bash ${src}/ticket "$@"
  '';
}
