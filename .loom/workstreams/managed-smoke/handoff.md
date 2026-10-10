# Isolated candidate testing / cumulative review

Operator subsequently authorized proceeding through offline review, candidate
package verification and isolated smoke testing without rebuilding/activating a
host. Still no push, production credentials/traffic, shared-service restart or
existing-room migration. #120's publication/fleet-lock boundary remains open.

Standalone candidate: import the real tmux_project.nix using public nixpkgs from
the harness input, NOT the fleet flake or private SOPS inputs. Full Nix package
build/check now passed66 tests, zero skips, output
/nix/store/kw69i1nrnxabs8g9qnwkc7ahxl71n204-tmux_project-0.1.0.
Harness artifacts:
- .pi/tmp/workers/2026-10-10T05-55-41-968Z-picker-candidate-complete-checks-6458070bcc7e/
- .pi/tmp/workers/2026-10-10T05-57-30-498Z-managed-smoke-installed-picker-c3228cff3432/

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
~205–314ms, materially slower than direct-binary tests; do not reuse earlier
35ms figures as packaged performance. This used a private fake public-host socket,
NOT real Matrix or the full relay/account path. No full-system evaluation is claimed.

Cumulative review must cover harness8b768ca..current and dotfilesc2a1ab8..current,
including this fix. Dedicated test owner/bot accounts have not been provisioned.
Production identity metadata is not permission to use production credentials.
After offline work, require test-only credential provisioning and exact identities
before any real Matrix smoke traffic. Harness plan: docs/managed-live-workspaces-staging.md.
