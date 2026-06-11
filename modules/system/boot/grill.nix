{ ... }:
{
  # Grill has enough RAM to keep /tmp in memory. This is host-local so other
  # machines keep their existing persistent /tmp behaviour.
  boot.tmp.useTmpfs = true;
}
