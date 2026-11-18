# LiteLLM access and catalog review — 2026-11-18

## Scope and evidence

Read `modules/services/litellm/nas.nix`, its consumer references, and current
first-party provider documentation. No credentials, private secrets repository,
ChatGPT token files, or database/key records were read. No authenticated model
inference requests were made during the review. Deployment was not changed.

Implementation follow-up: the two 6.2 subscription routes below have now been
added to the NAS Nix catalog and shared Pi configuration, preserving existing
models/defaults. Focused Nix evaluations verified both aliases and Pi Responses
metadata. They remain undeployed and have not been authenticated against the
upstream subscription. Pi uses conservative 272K context / 16K output limits.

Cleanup follow-up: removed `gpt-5-mini`, `gpt-5.3-codex`,
`gemini-2.5-flash-image`, `gemini-3-pro-image-preview`, `sub-gpt-6.1-sol`,
and `sub-gpt-6-astra`. Added the paid `gpt-6.1-terra` replacement for voice/thought
capture; updated both Python fallback defaults and the STT helper. The Neovim
AI plugin and its templates were subsequently removed rather than migrated. Image routes are now `gemini-3.1-flash-lite-image` and
`gemini-3-pro-image`; Open WebUI's declarative image default uses the former.
Open WebUI database-persisted settings may override that environment default and
must be checked after deployment. Client configuration and virtual-key allowlists
must migrate from the removed aliases (particularly the friend's 6.1 Sol) before
use. These replacements are configuration changes, not live inference results.
The inventory below records the pre-cleanup review.

`https://litellm.bepis.lol/v1/models` returned HTTP 401 without a key, confirming
that the public ingress is reachable and rejects this unauthenticated request.
The Nix registration intentionally has `tailnet = false`; the friend does not
need Tailscale for this endpoint. This does not prove upstream model availability.

A read-only attempt to obtain the running LiteLLM package version through NAS's
container required sudo authentication and was not performed. The configured
image is pinned by digest; compatibility with current subscription-provider
features still needs verification against the running version.

## Friend's client configuration

- OpenAI-compatible base URL: `https://litellm.bepis.lol/v1`.
- API key: the friend's dedicated LiteLLM virtual key, not a provider key or
  LiteLLM master key. Do not paste it into issue bodies or repository files.
- Model: an exact allowed **public alias** such as `sub-gpt-5.5`, not the internal
  upstream name `chatgpt/gpt-5.5`. The key's allowed-model list was not inspected.
- Prefer the OpenAI **Responses API**. All configured `sub-*` entries have
  `model_info.mode = responses`. Chat-Completions-only applications need a
  compatibility test; do not promise arbitrary apps work with this route.
- First list models visible to the key with authenticated `GET /v1/models`, then
  make a tiny streaming `POST /v1/responses` request to an allowed alias.

The existing proxy configuration persists server-side ChatGPT OAuth credentials
under `/var/lib/litellm/chatgpt-auth`. Thus these aliases are intended to use the
operator's subscription authentication, not the friend's own ChatGPT login.
They share upstream subscription limits; a virtual key does not create an
independent OpenAI entitlement. Review subscription terms before offering access
to another person or unrelated applications. For broad third-party compatibility,
a separately budgeted paid API route is the more conventional integration.

LiteLLM's current Codex subscription tutorial describes a *different* mode:
client-owned ChatGPT login, `requires_openai_auth = true` and a separate
`x-litellm-api-key` header. Do not copy that setup blindly into this server-owned
OAuth deployment. Current source still contains server-authenticator fallback,
but the installed image version was not verified.

Sources:
- https://docs.litellm.ai/docs/tutorials/openai_codex_byok
- https://github.com/BerriAI/litellm/blob/main/litellm/llms/chatgpt/responses/transformation.py

## Key restrictions and privacy

Recommended: exact allowed aliases, expiry, sensible RPM/TPM and concurrency
limits, and a separate virtual key per person/application. Monetary budgets alone
may not accurately limit subscription usage, especially for new aliases without
pricing metadata. Avoid permitting paid-provider routes unintentionally.

`general_settings.store_prompts_in_spend_logs = true` is configured. Tell the
friend their prompts may be retained by the operator's gateway. Change this
policy deliberately if prompt retention is unwanted. `drop_params = true` can
silently discard unsupported app parameters; test tool use and reasoning options,
not just a one-line response.

## OpenAI additions

Current official catalog/release documentation identifies the newly released
models as **GPT-6.2 Astra** and **GPT-6.2 Sol**. Candidate subscription entries:

| Public alias | Internal route | Metadata |
| --- | --- | --- |
| `sub-gpt-6.2-astra` | `chatgpt/gpt-6.2-astra` | `mode = responses` |
| `sub-gpt-6.2-sol` | `chatgpt/gpt-6.2-sol` | `mode = responses` |

These entries are now configured, but are not verified account entitlements. API catalog
availability does not establish availability through this account's ChatGPT
subscription or the installed LiteLLM adapter. Validate a small request before
moving defaults or granting these aliases to the friend's key.

Sources:
- https://openai.com/research/index/release/
- https://developers.openai.com/api/docs/models/all
- https://developers.openai.com/api/docs/models/gpt-6.2-astra
- https://developers.openai.com/api/docs/models/gpt-6.2-sol

## Catalog audit

Distinguish retired models, announced deprecations, merely older models, and
unverified provider IDs. Do not delete working aliases purely because newer
models exist.

| Configured entry | Finding / recommendation |
| --- | --- |
| `gpt-5-mini` | Official API deprecation; shutdown scheduled **2026-12-11**. Migrate consumers before removal. Official replacement: `gpt-6.1-terra`. |
| `gpt-5.3-codex` | Official API deprecation; shutdown scheduled **2027-04-01**. Plan migration; not already shut down. Official listed replacement is `gpt-6-sol`; evaluate newer Sol for a fresh default. |
| `gpt-5.5` | Older than GPT-6 family, but not listed as deprecated in the inspected catalog. Keep if used as a paid API fallback. |
| `sub-gpt-6-astra`, `sub-gpt-6.1-sol` | Valid older generations in the public API catalog. Replace defaults with tested 6.2 equivalents, retaining aliases temporarily for clients. Subscription availability remains separate. |
| `sub-gpt-6.1-terra` | Still a current model family entry; retain. |
| `sub-gpt-6.1-luna` | Suspect upstream ID: official catalog lists **`gpt-6-luna`**, not `gpt-6.1-luna`. Verify the account-specific list; likely correct the route and migrate the public alias. |
| `sub-gpt-5.5-mini` | Not found in the public model directory; it lists `gpt-5.4-mini`. Verify whether this is an account-only subscription alias before replacing it. |
| `sub-gpt-5.5`, `sub-gpt-5.4`, `sub-gpt-5.4-pro` | Older optional compatibility/fallback entries; no basis here to label them retired. Prune only after usage review. |
| `sub-gpt-5.3-codex-spark` | Subscription-specific route; public API deprecation of `gpt-5.3-codex` does not prove this route's retirement. Verify independently. |
| `claude-opus-4-5` | Older than configured Opus 4.8; a consolidation candidate, not established as retired. Normalize upstream provider prefix to `anthropic/` if retained. |
| `claude-opus-4-8` | Retain as configured newer Opus. Normalize provider prefix to `anthropic/` for consistency. |
| `claude-sonnet-4-6`, `claude-haiku-4-5` | Still listed as active in official documentation search results. Keep unless there is a specific replacement/price-performance goal. |
| `gemini-3-pro-image-preview` | Official shutdown date **2026-06-25** has passed. Replace with `gemini-3-pro-image`. |
| `gemini-2.5-flash-image` | Old; current deprecation page gives shutdown **2027-03-15**, replacement `gemini-3.1-flash-lite-image`. Not already shut down. |
| `gemini-3-flash-preview` | No shutdown date announced on the inspected page; recommended replacement is stable `gemini-3.6-flash`. |
| `gemini-3.1-pro-preview` | No shutdown date announced on the inspected page. Do not remove solely because its name says preview. |
| `glm-5`, `glm-4.7-flash` | Old for the Coding Plan endpoint. Z.AI now documents `GLM-5.3` and `GLM-5.3-Flash` for that plan. Validate exact routed IDs/entitlements before migrating. |
| `m3` | Local GLM-5 GGUF backend, not a cloud lifecycle alias. Keep if the server is useful/reachable; no inference availability test performed. |
| `kimi-k2.5` | Older than the configured coding-oriented K2.7 Code; not proven retired. Potentially useful general-purpose fallback. |
| `kimi-k2.7-code` | Retain pending account/model test; official Moonshot model card confirms this model family. Review manually declared pricing when changing it. |
| `kimi-k2.5-no-think` | Likely incorrect internal route. Keep this *public alias*, but route to `moonshot/kimi-k2.5` with `thinking.type = disabled`. Official model card describes thinking/instant as modes of the same model. |

Sources:
- OpenAI model status and exact API shutdown dates:
  https://developers.openai.com/api/docs/models/all and
  https://developers.openai.com/api/docs/deprecations
- Anthropic:
  https://platform.claude.com/docs/en/models/overview and
  https://platform.claude.com/docs/en/about-claude/model-deprecations
  (direct fetch returned 403; these claims use search results from official pages).
- Google:
  https://ai.google.dev/gemini-api/docs/deprecations
  (direct page retrieval confirmed dates; an initial search summary had conflated
  the 2.5 image model with a different shutdown schedule, so it was not used).
- Z.AI:
  https://docs.z.ai/devpack/latest-model.md and
  https://docs.z.ai/devpack/overview.md
- Moonshot-owned model cards:
  https://huggingface.co/moonshotai/Kimi-K2.5 and
  https://huggingface.co/moonshotai/Kimi-K2.7-Code

## Dependencies to migrate together

Repository search found explicit consumers outside the central catalog:

- `modules/cli/pi-harness/network.nix` lists `sub-gpt-5.5`,
  `sub-gpt-5.5-mini`, `sub-gpt-5.3-codex-spark` with Responses overrides and
  manually declared context/output metadata.
- `modules/scripts/stt-assist/work.nix` defaults to `gpt-5-mini`.
- `modules/services/thought-capture/grill.nix` selects `gpt-5-mini`.
- Virtual-key model permissions and external apps may also reference aliases;
  these database/client settings were not inspected.

Model definitions are deliberately config-owned (`store_model_in_db = false`).
Update the Nix catalog, consumers and key permissions together; do not rely on
adding model entries in the dashboard. Avoid wildcard routes granting a friend's
key access to every present/future model.

Recommended order: add/test 6.2 subscription routes; verify suspect IDs; fix the
retired image route; migrate imminent `gpt-5-mini` consumers; then remove unused
older entries based on usage metadata without reading prompt contents.
