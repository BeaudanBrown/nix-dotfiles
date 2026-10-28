# Isolated candidate testing / cumulative review

**Current runtime:** `2c62151b5b5126e8ebb87425a1dcfdb85db1b5ed` repairs offline-only
activity finalization. Exact reported envelope error and blocked answer reproduced
in isolation; deterministic disconnect regression and five affected tests pass.
All 12 gates pass (626 managed tests, zero skips); paired review addressed.
Production recovery is still unconfirmed: stuck old closing state blocks automatic
refresh and requires explicitly agreed exact-session restart after deployment.

**Earlier reconnect runtime:** `36e286cecd8eededfb7299778d03804d014ff045` adds bounded
reconnect warnings: real missing-socket red/green tests for both adapter roles,
UI-enabled shutdown/session-switch race coverage, and all 12 canonical gates
(625 managed tests without skips). Retry timing is unchanged. Loaded adapters
need normal idle refresh/restart; no host build, restart or state mutation by agent.

**Earlier production repair:** harness pin was `9c79abe84b3bb244ade5b1d75b5c5950f64075f9`.
The operator's GRILL rebuild uncovered a production-baseline compatibility gap
not exercised by the earlier isolated smoke. Restored production commits passed
all 12 canonical gates (623 managed tests, zero skips), standalone packages and
read-only parsing of the real registry without writes. Post-rebuild live health
remains operator-owned. No agent host builds, service changes or migration.
See `specs/managed-live-workspaces.md`; the following sections are historical.

**2026-10-27 update:** operator authorized publication and actual harness pin/lock
resolution only (steps 1–2, no host builds). Feature branches are published and
the dotfiles lock now selects harness 692426351a318a56422f7a38b78ce2ea3c80af7f;
only that lock node changed. Element X functional tests passed, desktop testing
is deferred, and prose approval wording passed review/canonical checks. Host
build/evaluation, activation and migration remain outstanding. The sections below
preserve the historical offline authorization/results, not current lock status.

Operator subsequently authorized proceeding through offline review, candidate
package verification and isolated smoke testing without rebuilding/activating a
host. Still no push, production credentials/traffic, shared-service restart or
existing-room migration. #120's publication/fleet-lock boundary remains open.

Standalone candidate: import the real tmux_project.nix using public nixpkgs from
the harness input, NOT the fleet flake or private SOPS inputs. Full Nix package
build/check now passed 66 tests, zero skips, final output
/nix/store/vhdwssijypi581g24vgm94m2fsfjd2k3-tmux_project-0.1.0.
Harness artifacts:
- .pi/tmp/workers/2026-10-10T05-55-41-968Z-picker-candidate-complete-checks-6458070bcc7e/
- .pi/tmp/workers/2026-10-10T05-57-30-498Z-managed-smoke-installed-picker-c3228cff3432/
- .pi/tmp/workers/2026-10-10T06-22-56-273Z-managed-smoke-controlled-shell-candidate-5d0488e6b53c/

Build exposed a real service-context bug: with no UTF-8 locale and absent TMUX
variable, tmux replaces tab separators/Unicode with underscores. Setting TMUX to
empty is insufficient for reproducing it (presence alone is a UTF-8 hint). A real
production tmuxAt regression failed as ascii_exact__ before the fix; -u now pins
machine-format encoding in common transport and progressive inventory. Disposable
fixtures use the same encoding. Generated test pi/direnv scripts also needed the
actual sh store path rather than /usr/bin/env, which is absent in Nix sandboxes.
All original checks remained enabled; verbose package checks make skips visible.

The installed package wrapper also passed real private-tmux/fzf/PTY reload,
selection, cache and cancellation smoke. Its actual keypress UI timings were
initially ~205–314ms, then ~174–224ms with the hardened environment fixture,
materially slower than direct-binary tests; do not reuse earlier 35ms figures as
packaged performance. A clean-environment attempt exposed dependence on tmux's
host login-shell fallback. The fixture now supplies a controlled POSIX shell and
an explicit environment allowlist with private HOME/XDG paths: no inherited
credentials, agent settings, startup hooks or managed roots. This used a private fake public-host socket,
NOT real Matrix or the full relay/account path. No full-system evaluation is claimed.

Cumulative review covered harness 8b768ca..7580563 and dotfiles c2a1ab8..6a7b294.
One high finding (production dispatcher dropped expectedGenerationId) was fixed
in harness 99f5941 with a red/green production IPC regression; both follow-up
review axes cleared it. The requested harness source pin is now 4415c7c (including the subsequent room-v12 fix), still
unpublished and deliberately NOT resolved in flake.lock. Seven source checks,
six syntax parses, 46 schema fixtures and the final harness canonical/package
gate passed. The fixture-only isolation follow-up passed another full candidate
build and installed-wrapper smoke. At that offline checkpoint, dedicated test
accounts were not yet provisioned; the later live result below supersedes it.
Final verification AFTER the fixture change and follow-up review passed:
.pi/tmp/workers/2026-10-10T06-27-38-103Z-managed-staging-final-post-isolation-gate-703ae4139d45/.
All 66 Go race tests, 46 production schema fixtures, source7/parse6, canonical12
and harness production packages passed. No test skips in the full packaged runs.
The final follow-up review reported no source defects; an outdated harness
smoke-evidence paragraph was corrected with the newer store path/timings and this
separate post-fixture gate. Only evidence prose changed after that final gate.

Production identity metadata is not permission to use production credentials.
Subsequently the operator provisioned separate test accounts and authorized live
smoke. It exposed room-v12 ID validation, creator authority and opaque-ID routing
incompatibility. Harness 4415c7c fixes these with shared bounded contracts and
regressions; the SAME original test host Space was recovered, not recreated.
Actual native coordinator/project launch, exact open and stale-fence refusal,
five-room hierarchy/owner autojoin, and durable account-ready ACKs after restart
passed. Processes stopped; five test rooms/state retained. No production accounts,
model calls, existing-room migration or host activation. Broader client acceptance
remains pending. See harness docs/managed-room-v12-evidence.md. Harness plan: docs/managed-live-workspaces-staging.md.
