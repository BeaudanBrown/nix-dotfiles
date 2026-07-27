{ buildGoModule }:
buildGoModule {
  pname = "fleet-installer";
  version = "0.1.0";
  src = ./.;
  vendorHash = null;

  meta.mainProgram = "fleet-installer";
}
