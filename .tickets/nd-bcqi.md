---
id: nd-bcqi
status: closed
deps: [nd-qo2o]
links: []
created: 2026-06-15T13:54:54Z
type: bug
priority: 2
assignee: Beaudan Brown
parent: nd-8dw3
tags: [oneplus, wifi, ath10k, hardware]
---
# Investigate Wi-Fi random MAC and key-install warnings

ath10k_snoc reports invalid MAC address/random MAC and key install/remove timeouts.

## Design

Evidence: invalid MAC address choosing random; failed to install key -110; failed to remove key -110. Determine whether Wi-Fi is functionally stable, where persistent MAC should come from, and whether calibration/NVRAM/firmware data is missing. If resolution requires kernel rebuild, flag and move on.

## Acceptance Criteria

Functional Wi-Fi impact is documented. Persistent MAC source is identified or follow-up ticket created. Any key-install warning impact is categorized as harmless/noisy or actionable.

## Notes

**2026-06-15T14:14:39Z**

Investigation evidence: current host is oneplus; wlan0 is connected to SSID via NetworkManager with IPv4 route; ping -c3 192.168.68.1 returned 0% loss. Current wlan0 addr_assign_type is 3 (NET_ADDR_RANDOM), confirming Linux is using a random MAC. The OnePlus DT only enables &wifi supplies/quirk and has no MAC/calibration nvmem binding. Persist partition contains /wlan_mac.bin with Intf0MacAddress/Intf1/2/3 entries, identifying the persistent MAC source; current random wlan0 address does not match Intf0. Current boot and retained kernel journal search found no ath10k key install/remove timeout lines, so old key warnings are historical/noisy unless they recur with disconnects/rekey failures.

**2026-06-15T14:14:39Z**

HANDOFF: documented Wi-Fi current summary in docs/oneplus-bringup.md; verified functional Wi-Fi and identified persist /wlan_mac.bin as persistent MAC source; tests run: ip/nmcli/cat addr_assign_type, sudo journalctl searches, sudo debugfs metadata check, ping -c3 gateway; remaining risk: stable MAC is not applied by Linux today but no functional impact observed.
