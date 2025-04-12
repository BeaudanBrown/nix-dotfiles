{
  pkgs,
  ...
}:
{
  environment = {
    systemPackages = [ pkgs.brave ];
    variables.BROWSER = "brave";
  };
}
