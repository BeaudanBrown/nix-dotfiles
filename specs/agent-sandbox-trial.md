# Opt-in Grill sandbox trial (#13)

Tracked only in BeaudanBrown/agent-sandbox-hs#13. This prepares configuration;
**nothing is enabled, built, activated or provisioned by this change**. Ordinary
Pi, tmux, Matrix and production sessions are unchanged. #12 remains unfinished;
this independent trial does not certify the complete coordinator interface.

## Input and scope

`agent-sandbox` is pinned to local committed revision
`589dc772e3d3119709e1d93f1464bc066f1b0f65`, via an absolute `git+file` URL. Unlike
a mutable `path:` input it excludes subsequent worktree changes. The lock retains
the producer's own nixpkgs pin (no follows override of its tested toolchain).
This is intentionally not portable to NAS/other machines. No push is authorized.
After separate publication approval, replace the URL with
`github:BeaudanBrown/agent-sandbox-hs/589dc772e3d3119709e1d93f1464bc066f1b0f65`,
update only that input and re-evaluate. Do not pretend the commit is remote today.
For another unpublished revision, deliberately update both URL and lock and
record new verification; do not silently follow local HEAD.

The lock addition was generated in an isolated flake containing only this input,
then its two nodes were merged under unique names. Existing lock nodes, including
private inputs, were not fetched or changed. Do not run an unscoped fleet input
update as a verification shortcut.

Grill explicitly imports `modules/services/agent-sandbox/trial.nix`; the option
`local.agentSandboxTrial.enable` defaults false. No other host imports it.
When explicitly enabled:

- Dedicated user/group `agent-sandbox-trial`, UID/GID61950, no supplementary groups.
  Operator is the existing declared `beau.uid`; collisions refuse evaluation.
- Only `/srv/agent-sandbox-trial` is eligible; seed `trial-project` is its
  `project` child. Default and ceiling are read-only, mandatory file exclusion
  `.env`. Managed ACL initialization applies only to this disposable scope.
- Harness `trial-hello` is the existing immutable GNU hello executable, not Pi or
  a new runtime implementation. No coordinator capability, credentials or state.
- The upstream Haskell service and patched Bubblewrap packages are selected from
  the pinned producer. No separate Nix daemon, session manager or permission store.
- Activation does not start the service (`wantedBy = []`). Initialization and
  service start are explicit, distinct steps. The service never repairs storage.

The trial does **not** change operator Nix trusted-users or sudo settings. Safe
upstream sandbox defaults apply; unsafe explicit sandbox/fallback settings and
trusting the dedicated identity refuse. Actual wheel-only sudo wrappers are an
upstream requirement. If Grill does not already satisfy it, opt-in evaluation
must fail until the operator separately reviews that host security change;
this module does not silently set `security.sudo.execWheelOnly`. The isolated
positive fixture supplies that prerequisite, not proof of live Grill readiness.
No sudoers parsing or host daemon provenance attestation is claimed.

## Evaluation (safe, no private inputs or build)

From this repository:

```sh
nix eval --impure --json --file tests/agent-sandbox-trial.nix
git diff --check
```

This evaluates the consumer's locked nixpkgs and the pinned local producer only,
without evaluating the fleet flake or reading/fetching its private secrets input.
It checks disabled absence, enabled assertions, identity/scope/harness, unchanged
operator trust/sudo rules, deferred start and unsafe sudo/host/UID/trust/fallback
negatives. It does not build derivations or inspect the current kernel/ACLs.
Full Grill evaluation/build/activation and actual confined hello are **not run**.
Before deployment the operator must also evaluate the complete host with their
normal authorized access to private inputs, resolve any assertions, review the
system diff, and separately authorize build/activation.

## Explicit operator-only fresh trial procedure (not executed)

These commands are for a separately approved disposable trial, not routine agent
execution. Save work first; do not reuse existing sandbox controls or a real
checkout. If any precondition fails, stop and investigate; never delete/adopt
unknown controls or repair arbitrary ownership to make the test pass.

1. Check UID/GID61950 is unused (`getent passwd 61950`, `getent group 61950` must
   return no entry), and `/srv/agent-sandbox-trial`, `/var/lib/agent-sandbox`,
   `/run/agent-sandbox` and `/etc/agent-sandbox` are absent. Check no existing
   `agent-sandbox.service` deployment. A previous trial requires the recovery/
   rollback handling below, not this fresh procedure. Review actual Nix/sudo
   prerequisites. No production credentials are needed.
2. Add `local.agentSandboxTrial.enable = true;` to Grill's configuration in a
   reviewed local change. Evaluate full Grill and inspect the planned system:
   ```sh
   nix eval .#nixosConfigurations.grill.config.system.build.toplevel.drvPath
   ```
   Only after separate build/activation approval:
   ```sh
   sudo nixos-rebuild switch --flake /home/beau/documents/nix-dotfiles#grill
   ```
   This installs the dedicated identity and declaration, not source ACLs or a
   running service. Verify `systemctl is-active agent-sandbox.service` is inactive.
3. Exclusively create the disposable source as operator `beau` (confirm `id -u`
   matches the declared operator UID). `mkdir` without `-p` intentionally refuses
   a preexisting root. Keep other writers out until initialization completes:
   ```sh
   sudo mkdir -m 0755 /srv/agent-sandbox-trial
   sudo mkdir -m 0700 /srv/agent-sandbox-trial/project
   sudo chown "$(id -u):$(id -g)" /srv/agent-sandbox-trial/project
   printf 'synthetic visible data\n' > /srv/agent-sandbox-trial/project/visible.txt
   printf 'synthetic excluded data\n' > /srv/agent-sandbox-trial/project/.env
   chmod 0600 /srv/agent-sandbox-trial/project/visible.txt /srv/agent-sandbox-trial/project/.env
   sudo agent-sandbox initialize
   ```
   These permission changes are limited to directories just created by this
   procedure. Initialization uses the protected managed ACL ledger, not launch-time
   chmod/chown. An interrupted initialize must retry the same declaration with
   writers stopped. Missing/foreign/unsealed state refuses; never reset the journal.
4. Write this public request to a fresh operator-owned `trial-launch.json`:
   ```json
   {"version":1,"kind":"launch","instanceId":"trial-one","conversationId":"trial-conversation","harnessId":"trial-hello","selection":{"version":1,"kind":"selection","primary":"trial-project","worktree":"/srv/agent-sandbox-trial/project","companions":[],"gitMetadataProject":null},"mode":"managed","arguments":[]}
   ```
   With the service still stopped, prepare, then start and invoke as the operator
   (not sudo for launch):
   ```sh
   sudo agent-sandbox prepare-state trial-launch.json
   sudo systemctl start agent-sandbox.service
   agent-sandbox policy list
   agent-sandbox launch trial-launch.json
   agent-sandbox policy status
   ```
   Expected: registered read-only trial project; confined hello exits normally;
   recorded original status is stopped. Status is history, not current-kernel
   proof. Hello alone is not an exclusion/Nix/devenv compatibility test (#14).
   Any failure is fail-closed; never replace the command with host execution.

## Stop, interruption and rollback

An active launch must be stopped with `agent-sandbox stop EXECUTION_ID` using its
recorded nonsecret ID, not a guessed unit/PID. Unknown units, failed stops or
pending policy work require investigation and exact owned recovery, not reset.
After originals finish and before disabling or changing sources:

```sh
sudo systemctl stop agent-sandbox.service
sudo agent-sandbox check-quiescent
```

Keep serving and writers stopped; the checkpoint is point-in-time, not a future
hold. Do not activate a different system during a physical replacement window.
Remove the opt-in line, then after separate approval activate the previous/off
configuration. This removes the service configuration, **not** durable history or
managed ACL provenance. Retain the dedicated numeric identity reservation, source,
protected journal and historical store paths until explicit reviewed retirement;
never reuse UID61950 while residual ACLs exist. Do not delete the ACL ledger or
recursively chown production trees as rollback. No full permission-erasure
certificate is claimed by disabling the option.

For retry, preserve the same pinned package, Host and originals. Package changes
may require the upstream explicit offline `migrate-manager` workflow; don't
reinitialize over dynamic history or silently adopt a changed Host. An interrupted
preparation keeps admission closed; retry only its exact owned request. Unsafe
unsealed directories require operator investigation. Startup may reconcile known
originals; stale endpoint sockets still refuse, not automatic unlinking.

## Evidence

Focused evaluation `f73cf7bd9b00` passed with consumer nixpkgs and pinned producer.
Earlier test-tooling fixes: `86d557056892` corrected the reconstructed locked Git
URL scheme; `a07409c98878` corrected the expectation that allowed-users must name
the user explicitly (the safe upstream default is `*`). These are evaluation
failures, not confinement/runtime defects. Final evaluation/syntax/whitespace and
existing-lock-node preservation passed in `b8c56b1e082a`.

Cross-repository review `a1f73367cecb` pinned an exact copied bundle of the
nix-dotfiles diff against `b90539a27d43ff798b46c23a0e802e8a4010603d` in the central
tracker checkout (tool scope is that checkout). Standards found no findings;
Spec requested two Low/current-issue test additions: explicit sandbox=false
refusal and exact GNU hello executable equality. Both were added; corrected
focused evaluation and syntax/whitespace passed in `7c093c24a67b`. Owning pre-commit
hooks formatted the Nix files (`86a5a5c853df`); post-format evaluation and syntax/
whitespace passed in `fc2ac95d45d4`. No production semantics changed after review. Bundle packaging is review evidence, not a
shipped duplicate module. Unrelated preexisting research files were untouched.
Full-host evaluation/build/activation, live users/ACLs and confined runtime trial
remain unperformed and require the separate operator procedure above.
