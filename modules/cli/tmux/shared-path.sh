# shellcheck shell=bash
# Source in the independent tmux server before exec. systemd's service path
# contains only boot tools; panes and popup commands also need the host profile.
# Keep the pinned boot runtime at the end for plugins that outlive a rebuild.
PATH="/run/wrappers/bin:/etc/profiles/per-user/$(id -un)/bin:/run/current-system/sw/bin:$HOME/.nix-profile/bin:$HOME/.local/state/nix/profile/bin:$PATH"
export PATH
