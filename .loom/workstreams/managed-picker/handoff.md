# Managed picker #118 / progressive discovery #119

Authorized: source implementation, local commits, direct Go and disposable tmux tests. No external Nix evaluation/build, activation, push, live Matrix/relay traffic, or shared-service/tmux restart. Tracker: pi-harness #118/#119. Baseline external commit 1ea4bf7; harness 91585a1.

Operator clarification: managed selection fails closed during relay outages; ordinary sessions/paths remain available. This supersedes #118's offline marked-window switching clause. No private-registry parsing or offline retirement ledger.

## #118 acceptance / crash matrix

- Public bounded CLI inventory: strict used-field validation, 4096 rows / 128 pages, cursor/identity uniqueness, deadline and output bounds; invalid/partial/outage inventory yields no managed rows.
- One conversation row keyed by immutable ID, including coordinator, dormant and starting; display states are observations, not action authority.
- Checkout dedup uses the pinned host/project/canonical-root checkout digest, never title/project equality or relative cwd; keep ordinary windows in mixed sessions.
- Enter validates selected identity from the in-memory rows, captures exact requester name/PID before admission, and calls generation-fenced window-first open once. Backend owns accepted launch/recovery; no cancellation, stop, refresh, delete or automatic replay.
- Revalidate exact returned window/pane/launch and requester before focus. Renumbering is harmless; disappearance/replacement refuses; retained failed startup is only retried by explicit Enter.
- Ordinary navigation must not bypass outage refusal by selecting a managed last window in a mixed session. Select an explicitly unmarked ordinary target instead. A selected raw path is Git-validated before ordinary shell creation.
- No destructive hotkeys; preserve scratch/LLM/local-model entrypoints and shared-session semantics.

## #119 boundary

Start fzf before discovery, one tmux/autojump snapshot, concurrent roots, no pre-display Git subprocess per path. Disposable atomic path cache; malformed cache is a miss. Identity-preserving full reload, query preservation, <=100ms raw-row hold, cancellation drains discovery only. Measure UI, first selectable row and full discovery separately using isolated cold/warm/error fixtures. No live latency claim.

#118 implementation and focused/full Go verification pass: 58 top-level tests, zero skips. Logs in harness `.pi/tmp/workers/2026-10-07T23-55-33-349Z-picker-full-isolated-6c7c024bde4d/`. Public CLI -> selection fixture -> real disposable tmux focus is covered; actual fzf timing remains #119. No individual subjective review claimed; cumulative review remains mandatory. External Nix remains unrun by authorization. #119 implementation now passes 63 top-level tests with race detector, zero skips; paired review and final verification pending. Latest affected log: harness `.pi/tmp/workers/2026-10-08T00-47-11-670Z-picker-final-pre-review-affected-ed224bbf34fd/`.

## #119 crash / acceptance evidence

| Boundary | Implementation and evidence |
| --- | --- |
| UI versus discovery | Actual F12 -> launcher-popup -> fzf/PTY before discovery; one tmux snapshot and autojump read, parallel fd roots, no Git before selection |
| Partial/failed cache | Strict bounded load is a miss; unique private temporary + atomic rename; failed/cancelled scans cannot publish partial scans; concurrent writer, removal/addition fixtures |
| Interrupted UI reload | Full immutable-key reload, not append-only; capture key in fzf queue and restore after result event, revision acknowledgement; missing identity blocks Enter until explicit navigation/query change |
| Cancellation | Context cancels host reads/fd/row assembly; real early Escape drained in ~40ms while host fixture delayed 1.5s; accepted-open context independent, prior retained-process regression |
| Native public transport | Existing host-control-v1 socket only, same owner/mode checks as CLI, 64KiB UTF-8 single-LF/EOF and request-ID matching; malformed/foreign/oversized/lost response refuses, no replay |
| Pending window | Corrected #118 CLI fallback: exit 8 with valid window-created success focuses immediately, tested with strict generation-fenced open |
| Latency | Real fzf0.70/tmux3.6a, private public-protocol fixture and 80 checkout markers; seven cold/warm/error trials, OS cache uncontrolled. Keypress UI medians36–41ms, first66–73ms, managed66–69ms; full79–114ms. Tails can exceed targets. |

Experiments exposed three corrected pitfalls: display-popup does not expand client format like run-shell (fixture now uses real launcher-popup); fzf POST actions require `/` without GET query parameters; load event precedes query results, so restore uses result with a revision fence. Native public transport was justified by the real packaged-CLI baseline (~0.5s for two Node/schema startups), not by private-state shortcuts. The raw hold is 50ms, leaving reload headroom within the100ms budget. External Nix/deployment/live acceptance remain prohibited and unclaimed.
