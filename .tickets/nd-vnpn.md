---
id: nd-vnpn
status: closed
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

## Notes

**2026-06-16T12:45:16Z**

HANDOFF: compared current speaker-only OnePlus UCM with Oxygen vendor mixer/audio_platform routes and ran bounded temporary ALSA route trials; docs/oneplus-audio-readings.md now records route map, low non-zero trial evidence, candidate experiments, and why no persistent route was made; verification: arecord/amixer runtime trials restored ALSA state plus rg doc check; next touchpoint is nd-296h service/module ordering using vendor TX0/DEC0/ADC4 first.
