# Shared by the primary user's agent-page and the DSH agent service, so both
# write to the same place and the page cap never exceeds what the DSH sidebar
# will read (workspace-files.maxFileBytes).
{
  outDir = "/agent/.agent-pages";
  maxBytes = 64 * 1024 * 1024;
}
