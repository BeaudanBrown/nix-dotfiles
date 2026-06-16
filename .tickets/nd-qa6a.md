---
id: nd-qa6a
status: open
deps: [nd-6g7r]
links: []
created: 2026-06-16T00:57:56Z
type: task
priority: 2
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, kernel, nix, tooling]
---
# Provide patchable OnePlus kernel experiment flow

Make it possible to opt into a patchable SDM845/OnePlus kernel for focused hardware experiments while leaving the default host on the known-good pinned kernel closure.

## Design

Add an explicit option/package/overlay/documented path that builds from the pinned sdm845 source input or a local checkout and can carry small diagnostic patches. Normal agents must not accidentally switch the default stable host away from the pinned closure.

## Acceptance Criteria

A maintainer can opt into a patchable OnePlus kernel for one boot generation and apply a trivial trace patch; default OnePlus configuration remains on the pinned known-good kernel unless explicitly changed.
