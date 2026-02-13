{
  pkgsUnstable,
  ...
}:
{
  environment.systemPackages = [
    pkgsUnstable.freecad
  ];
}
