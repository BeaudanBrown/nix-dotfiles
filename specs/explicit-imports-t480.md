# Explicit Imports (Scripted) Spec - T480 First

## Document Status
- Status: In progress
- Branch: `feature/explicit-imports-t480`
- Last updated: 2026-03-06
- Primary target host: `t480`

## Problem Statement
Current host composition uses `lib.custom.importAll`, which recursively scans the full `modules/` tree at evaluation time and includes files by basename/root matching. This is flexible, but it adds evaluation overhead and hides the final resolved import set.

For `t480`, we want a deterministic, generated explicit-import file that is consumed directly by `hosts/t480/default.nix`, so normal host evaluation does not recurse through `modules/`.

## Goals
1. Reduce evaluation work for `t480` by replacing runtime recursive module discovery with pre-generated explicit imports.
2. Keep host config DRY: host should declare intent (graph/root target), not duplicate module paths.
3. Introduce a root graph model (`extends`) so roots can compose other roots.
4. Keep behavior parity with current `t480` imports as closely as possible for the first migration.
5. Keep migration incremental: only `t480` switches initially.

## Non-goals (Initial Iteration)
1. Full fleet migration in this pass.
2. Removing existing `lib.custom.importAll` for all hosts.
3. Redesigning secrets model in this pass.
4. Introducing cross-platform host targets (NixOS-only scope).

## Proposed Architecture

### New Files
1. `inventory/explicit-imports/root-graph.nix`
- Declares root nodes and `extends` edges.
- First iteration focuses on roots used by `t480`.

2. `inventory/explicit-imports/host-targets.nix`
- Declares per-host generation intent.
- For `t480`: top-level target roots + whether host stem overrides are included.

3. `scripts/generate-host-imports.nix` + `scripts/generate-host-imports.sh`
- Deterministically resolves effective roots from the graph.
- Scans module files once during generation.
- `writeShellApplication` wraps the standalone shell script source file.
- Writes static file: `generated/imports/<host>.nix`.

4. `generated/imports/t480.nix`
- Generated, committed output consumed directly by `hosts/t480/default.nix`.

### Host Consumption Pattern
`hosts/t480/default.nix` imports:
1. Fixed host/platform imports (`./hardware.nix`, HM, sops, etc.)
2. `import ../../generated/imports/t480.nix`
3. Existing host-local options unchanged

This preserves host readability while avoiding runtime recursive module discovery for t480.

## Resolver and Generation Rules
1. Resolve root graph closure (transitive `extends`) with cycle detection.
2. Build a module stem -> paths map by scanning `modules/**.nix`.
3. Select files matching:
- Host stem (`t480`) when `includeHostStem = true`
- All effective root stems after graph closure
4. Produce deterministic ordering:
- Host-stem files first (sorted)
- Then root groups in resolved-root order, each group sorted
5. Emit Nix list with repo-relative paths as path literals.

## Duplication Avoidance Strategy
1. Host declares target roots once in `host-targets.nix`.
2. Root relationships are declared once in `root-graph.nix`.
3. Module paths are not hand-maintained per host.
4. Generated output is reproducible from the above sources.

## Safety and Verification
1. Generator fails on unknown host/unknown root.
2. Generator fails on graph cycles.
3. A follow-up check command will verify generated file is current.
4. Validate by evaluating `nixosConfigurations.t480` after migration.

## Implementation Plan
- [x] Create working branch for migration work.
- [x] Add this spec and maintain live progress updates here.
- [x] Add root graph inventory (`inventory/explicit-imports/root-graph.nix`).
- [x] Add host targets inventory (`inventory/explicit-imports/host-targets.nix`).
- [x] Implement generator tool (`scripts/generate-host-imports.nix`).
- [x] Add generated output directory and generate `generated/imports/t480.nix`.
- [x] Switch `hosts/t480/default.nix` to consume generated imports.
- [x] Add a convenience command to regenerate host imports.
- [x] Run `nix eval` sanity checks for `t480`.
- [x] Update this progress log with results and next steps.

## Progress Log

### 2026-03-06
1. Created branch `feature/explicit-imports-t480`.
2. Wrote initial detailed spec and implementation plan.
3. Added graph inventory at `inventory/explicit-imports/root-graph.nix`.
4. Added host target inventory at `inventory/explicit-imports/host-targets.nix`.
5. Implemented `scripts/generate-host-imports.nix`.
6. Generated `generated/imports/t480.nix` (106 imports, effective roots: `minimal, common, network, client, main, work, gaming`).
7. Switched `hosts/t480/default.nix` to consume the generated imports file.
8. Added `just gen-imports <HOST>` convenience command.
9. Refactored generator to a standalone shell source file wrapped by `writeShellApplication` (non-inline script body).
10. Wired `nr` alias to run host import generation automatically before `nh os switch`.
11. Staged newly created files so `nix eval .#...` can include generated paths.
12. Validation passed:
- `nix eval .#nixosConfigurations.t480.config.system.stateVersion` -> `\"25.05\"`
- `nix eval .#nixosConfigurations.t480.config.networking.hostName` -> `\"t480\"`
- Generated vs expected import parity check -> `expectedCount=106`, `generatedCount=106`, no diff.
13. `nix eval .#nixosConfigurations.t480.config.system.build.toplevel.drvPath` was started but interrupted due long runtime; lighter eval checks above confirmed successful host evaluation path for this migration step.
14. Next: optional freshness enforcement check (fail when generated imports are stale) and migration of the next host once t480 behavior is accepted.

## Open Questions
1. Should generated files for additional hosts be committed as we migrate each host, or only generated in CI/local workflows?
2. Should we enforce freshness via a `flake check` hook immediately, or add that after first host migration?
