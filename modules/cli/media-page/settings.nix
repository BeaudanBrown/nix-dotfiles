# Shared by the primary user's media-page and the DSH agent service, so both
# write to the same place and the page cap never exceeds what the DSH sidebar
# will read (workspace-files.maxFileBytes).
{
  outDir = "/agent/.media-pages";
  maxBytes = 64 * 1024 * 1024;
}
