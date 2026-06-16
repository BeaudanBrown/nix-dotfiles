---
id: nd-vnpn
status: open
deps: [nd-zthm]
links: []
created: 2026-06-16T12:20:03Z
type: task
priority: 3
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, audio, mic, ucm, vendor, userspace, current]
---
# Compare OnePlus UCM and vendor mic routes

Compare current OnePlus UCM and runtime route with vendor mixer path data to derive minimal non-kernel mic route experiments.

## Design

Inspect current UCM files, repo vendor mixer_paths_tavil.xml/audio_platform_info.xml, and postmarketOS-style route names if available locally. Map bottom/handset/voice-rec/dmic route names to exposed ALSA controls. Try only small temporary UCM or runtime route experiments.

## Acceptance Criteria

A route mapping and candidate experiment list is recorded; any small UCM/runtime route fix is implemented and validated, otherwise the unresolved route mismatch is documented.
