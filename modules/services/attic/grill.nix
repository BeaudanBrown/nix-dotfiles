{ ... }:
{
  # Grill is not a default remote builder right now, so do not upload its local
  # builds automatically. Re-enable this if grill becomes a builder again.
  custom.atticCache.upload.enable = false;
}
