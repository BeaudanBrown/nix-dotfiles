---
id: nd-zu8n
status: closed
deps: []
links: []
created: 2026-06-15T13:54:54Z
type: bug
priority: 2
assignee: Beaudan Brown
parent: nd-8dw3
tags: [oneplus, systemd, bug]
---
# Fix hexagonrpcd unit ConditionPathExists placement

Journal reports hexagonrpcd-adsp-sensorspd.service has Unknown key ConditionPathExists in section [Service].

## Design

Likely seam is hosts/oneplus/oneplus-fajita/hardware/qualcomm-services.nix, where ConditionPathExists is currently inside serviceConfig. Move conditions to the unit section while keeping ExecStart/Restart/User/Group in serviceConfig.

## Acceptance Criteria

ConditionPathExists entries are placed in the correct systemd unit section. Focused Nix validation/evaluation is run or explicitly skipped. Ticket notes say whether the journal warning should disappear after next boot.

## Notes

**2026-06-15T14:01:00Z**

Moved ConditionPathExists for hexagonrpcd-adsp-sensorspd from serviceConfig to unitConfig in hosts/oneplus/oneplus-fajita/hardware/qualcomm-services.nix.

**2026-06-15T14:01:40Z**

Validation: nix eval --extra-experimental-features 'nix-command flakes fetch-closure pipe-operators' .#nixosConfigurations.oneplus.config.systemd.services.hexagonrpcd-adsp-sensorspd.unitConfig.ConditionPathExists returned [ "!/dev/fastrpc-sdsp" "/dev/fastrpc-adsp" ].
