{ ... }:
{
  # Grill has enough RAM to keep /tmp in memory. This is host-local so other
  # machines keep their existing persistent /tmp behaviour.
  boot.tmp.useTmpfs = true;

  # Keep Grill available even when idle or a desktop shortcut requests sleep.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };
}
