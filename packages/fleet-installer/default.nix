{ buildGoModule }:
buildGoModule {
  pname = "fleet-installer";
  version = "0.1.0";
  src = ./.;
  vendorHash = "sha256-GBccl8V87u26dtrGpHR+rKqRBqX6lq1SBwfsPvj/+44=";

  meta.mainProgram = "fleet-installer";
}
