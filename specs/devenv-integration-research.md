# devenv Integration Research

Research snapshot: 2026-11-20. Upstream facts were checked against the official devenv documentation and the source tree for the latest release, [v2.3](https://github.com/cachix/devenv/releases/tag/v2.3), commit [`e0781f7`](https://github.com/cachix/devenv/tree/e0781f7bee573eefcab4a7d2788fd9b455560ca2).

## Current repository state

- `devenv` is already installed through `pkgs.devenv` by `modules/triage/work.nix` and `modules/triage/agent.nix`. The currently locked package evaluates to version 2.1.2 on both `grill` and `agent`, while upstream's latest release is 2.3.
- Home Manager enables direnv, Zsh integration, and nix-direnv in `modules/tools/direnv/common.nix`.
- Direnv currently whitelists broad directory prefixes (`documents`, `monash`, and `collab`; `host` on the agent). This makes activation convenient but removes direnv's normal per-project review boundary for anything under those trees.
- The repository itself uses `.envrc` with `use flake`; its development shell is a conventional `pkgs.mkShell` in `flake.nix`.
- The disabled `fl` project scaffolder contains four flake-based templates. Go alone uses `devenv.lib.mkShell`; Python, R, and TypeScript use `pkgs.mkShell`.
- The tmux managed-project launcher explicitly runs Pi through `direnv exec <cwd> pi`, and Neovim has direnv integration. Direnv is therefore part of the wider workflow, not just interactive shell activation.
- Syncthing already ignores `.direnv`, `.devenv`, and `.devenv*` state directories.

## What current devenv provides

The dedicated CLI uses `devenv.nix` for the environment, `devenv.yaml` for inputs/settings, and `devenv.lock` for resolved inputs. `devenv init` creates the core files; `devenv shell`, `devenv up`, `devenv tasks run`, `devenv test`, and `devenv update` cover shell, process, task, test, and dependency workflows. [Getting Started](https://devenv.sh/getting-started/) [Inputs](https://devenv.sh/inputs/)

Version 2.x adds or emphasizes:

- a native process manager with readiness probes, dependencies, restart policies, file watching, background operation, attach/control support, and automatic port allocation; v2.3 adds optional `.localhost` proxy URLs and per-process HTTPS. [Processes](https://devenv.sh/processes/) [v2.3 release](https://github.com/cachix/devenv/releases/tag/v2.3)
- DAG-based tasks with parallel execution, lifecycle hooks, status checks, file-change checks, cached outputs, and dependencies on processes. [Tasks](https://devenv.sh/tasks/)
- profiles that compose backend/frontend/testing variants and can activate manually or by hostname/user. [Profiles](https://devenv.sh/profiles/)
- built-in git-hooks.nix integration; `devenv test` is the intended CI verification entrypoint and can start and stop declared processes for integration tests. [Git Hooks](https://devenv.sh/git-hooks/) [Tests](https://devenv.sh/tests/)
- native automatic activation through `devenv hook zsh`, with explicit per-project trust through `devenv allow`. Native activation uses a subshell. Direnv remains supported but its integration page is now marked deprecated; it modifies the current shell in place and remains useful for that behavior. [Auto Activation](https://devenv.sh/auto-activation/) [Direnv](https://devenv.sh/integrations/direnv/)
- evaluation caching, hot shell reload, a `devenv.nix` LSP, MCP support, OCI outputs, reusable imports, polyrepo references, and language-aware package outputs. [README](https://github.com/cachix/devenv/blob/v2.3/README.md)

## Dedicated CLI versus flake integration

Upstream recommends the dedicated CLI for most projects. It has less boilerplate, evaluation caching, GC protection, pure evaluation, container support, SecretSpec support, and process-aware tests. Flake integration remains appropriate when downstream flakes must consume the shell or the project already needs flake outputs, but it requires `nix develop --no-pure-eval` unless `devenv.root` is fixed to a non-portable absolute path. Process startup during `devenv test` is not supported in flake mode. [Using devenv with Nix Flakes](https://devenv.sh/guides/using-with-flakes/)

This makes the current Go scaffold's `devenv.lib.mkShell` hybrid a weaker default for ordinary application projects: it gains the module vocabulary but gives up several reasons to adopt devenv. A project that genuinely publishes Nix packages can keep a flake, but its developer workflow does not automatically need to be implemented through that flake.

## Pros for this workflow

- A common declarative interface can replace hand-written `mkShell` differences across Go, Python, R, and TypeScript projects.
- Languages, local databases, app processes, hooks, setup tasks, and integration tests can live in one project-owned module instead of being split among `flake.nix`, Just recipes, shell hooks, and external service setup.
- `devenv up -d`, readiness probes, attach, and process subsets fit tmux-based project work well.
- Automatic port allocation is valuable when several projects or agent worktrees run concurrently.
- Tasks give agents and CI discoverable, named operations with dependency semantics; this is safer and clearer than relying on prose or shell initialization side effects.
- Project lockfiles preserve reproducibility without coupling every project's tools to the NixOS fleet lockfile.
- Shared modules and profiles can reduce duplication without forcing every machine to install every language tool globally.

## Costs and risks

- There is another CLI, lockfile, module layer, and state directory to understand in addition to NixOS, Home Manager, flakes, direnv, and Just.
- The host-installed CLI and project-pinned devenv modules can drift. Upstream includes compatibility handling, but recent release notes show this boundary is real. A deliberate update policy is needed.
- Dedicated CLI projects are less directly consumable by downstream flakes than ordinary flake outputs.
- Native activation's subshell model can surprise shell/tmux navigation. Replacing direnv immediately would also conflict with the existing `direnv exec` launcher path and editor integration.
- Services run as user-level development processes, not durable NixOS services. Production and machine infrastructure should remain in this fleet repository.
- Task caching/status checks can hide work if tasks are modeled incorrectly. Process/task ordering also has a documented caveat: downstream setup tasks are skipped by default under `devenv up`; `--mode all` is currently required for that shape. [Tasks](https://devenv.sh/tasks/#processes-as-tasks)
- `.devenv` and `.direnv` contain generated local state and must stay ignored. Secret values should not be embedded in Nix expressions or committed dotenv files.

## Provisional recommendation

Adopt the **dedicated devenv CLI per application project**, but retain **direnv as the activation layer** for now.

1. Keep host concerns in NixOS/Home Manager: install a deliberately pinned/recent devenv CLI, retain direnv/nix-direnv for mixed repositories, and configure the official devenv binary cache at the system level if desired.
2. For new application projects, use `devenv.nix`, `devenv.yaml`, and `devenv.lock`, plus an `.envrc` based on `eval "$(devenv direnvrc)"; use devenv`. This remains compatible with `direnv exec` in tmux.
3. Keep `just` as a memorable user-facing command layer where useful, but have recipes call canonical devenv tasks rather than duplicate environment setup.
4. Model local dependencies and long-running developer programs as devenv services/processes; model setup, checks, migrations, generation, and CI as tasks. Keep durable host services in NixOS.
5. Pilot one representative project before changing the dotfiles shell or all templates. A full-stack project with a database and tests will exercise more value than this dotfiles repository.
6. After the pilot, standardize a small project template and replace the disabled `fl` scaffolds. Avoid importing modules by absolute path from this dotfiles checkout; use self-contained project files or a separately versioned shared input so collaborators and CI remain portable.
7. Reconsider native `devenv hook zsh` only after tmux and editor workflows no longer depend on direnv. Independently reconsider the broad direnv prefix whitelist because it trusts every `.envrc` under those trees.

## Decisions to make

1. Is the primary target solo projects on these NixOS hosts, collaborative repositories used by non-Nix users, or both?
2. Which real project should be the pilot, and what languages/services does it require?
3. Should `just` remain the visible command interface (`just dev`, `just test`) or should devenv commands be used directly?
4. Should project shells activate silently in place through direnv, or is devenv's explicit subshell behavior desirable?
5. Should shared defaults be copied into each project for independence, or published as a versioned shared devenv module?
6. How aggressively should the CLI and project inputs update: manually per project, on a schedule, or through dependency automation?
