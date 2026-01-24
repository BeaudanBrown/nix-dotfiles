{ ... }:
{
  # Force all builds to be remote
  nix.settings.max-jobs = 0;
}
