# Kindle SSH persistence research

## Question

What is the maintained path for SSH access to a jailbroken Kindle that is persistent across reboots but does not keep the Kindle awake?

## Findings

- Jobman offers convenient on-demand USB and Wi-Fi SSH, but its Wi-Fi SSH toggle is not a boot-persistent service interface.
- The dedicated `dropbear-ssh` KPM package is also on-demand. It keeps its server alive after the app closes, but its documented flow does not start it automatically after a reboot.
- Its **“Keep reachable while Kindle sleeps”** option prevents normal Wi-Fi/CPU suspension. That consumes more battery; leaving it disabled preserves normal sleep but makes the device unreachable while asleep.
- A custom Upstart-managed Dropbear daemon could provide boot persistence, but would duplicate package lifecycle/configuration and require a separate password/key and firewall policy.
- The Kindle's persistent `tailscaled` Upstart job already supplies the desired lifecycle. **Tailscale SSH** is the preferred solution: it starts with `tailscaled`, is reachable only through the tailnet, becomes unavailable during normal Wi-Fi sleep, and is authorized centrally by the Headscale policy.

## Recommended design

1. Keep `tailscaled` persistent with state at `/nix/var/lib/tailscale/tailscaled.state`.
2. Enable the integrated server on the Kindle:

   ```sh
   tailscale --socket=/var/run/tailscale/tailscaled.sock set --ssh
   ```

3. Declare an explicit Headscale `ssh` policy in the NixOS configuration.
4. Verify `ssh root@100.64.0.24` after a Kindle reboot and Wi-Fi reconnect.
5. Remove/leave stopped the unneeded Jobman and `dropbear-ssh` servers after validation.

## Sources

- Jobman repository: <https://github.com/KindleTweaks/jobman>
- Kindle Modding documentation, “Jailbreaking Manager”: <https://kindlemodding.org/jailbreaking/whats-next/jailbreaking-manager/>
- `dropbear-ssh` package README: <https://github.com/akshaylahudkar/dropbear-ssh/blob/main/README.md>
- Tailscale SSH documentation: <https://tailscale.com/docs/features/tailscale-ssh>
- Headscale policy documentation: <https://headscale.net/development/ref/policy/>
