# Operations

How this repo is run: what verifying a change requires before it is pushed, how to build and run the image locally, and where the repo-specific tooling is configured.

## Local Verification

Verifying a change here means running the gates, then running by hand the parts of the contract the pull request pipeline never reaches.

The gates are the hub's `validate-task.yml` lint block, `markdownlint-cli2`, `cspell` (scoped to `README.md` and `HISTORY.md`), `actionlint`, `editorconfig-checker`, and shellcheck and shfmt over `Docker/entrypoint/*.sh`, plus its repo gate, which checks action pins, line-ending coverage, and the composite-action hooks under `.github/actions/`. CI runs all of them, so run all of them before every push rather than the ones that look relevant. From a hub checkout, `python3 scripts/docker_lint.py --root <this repo>` runs the linters through Docker with no local toolchain, and `python3 scripts/repo_gate.py --root <this repo>` runs the repo gate. The hub task's prose gate runs on every pull request. Run it locally from this repo's root with `python3 <hub checkout>/scripts/prose_lint.py --diff <base>`, since it diffs the repository it runs in. A change to `Docker/` is also smoke-built locally with the `docker buildx build` command in the runbook below before it is pushed, the same amd64 build CI runs.

The local commit hook runs the diff-scoped prose gate and the line-ending check on every commit. A violation then fails the commit, before a push rather than on the pull request. Install the tool once per machine with `uv tool install pre-commit`, and enable the hook once per clone with `pre-commit install` from the repo root. The ESPHome devcontainer carries neither `pre-commit` nor `uv`, so once the hook is enabled, commit from the host. The VS Code `Lint: Prose` and `Lint: EOL` tasks run the same gates over the whole tree.

**What pull request CI structurally cannot exercise:**

- **The arm64 image.** The pull request smoke build and every `develop` publish build `linux/amd64` only. Only a full `main` publish builds `linux/amd64,linux/arm64`, so an arm64-only break first surfaces on `main`.
- **The firmware compile test, unless the change touches the image.** On a pull request run of `test-pull-request.yml`, the `validate` hook compiles only on a change to the image, to what is compiled in it, or to the hub pin. A change outside those paths merges without anything compiling firmware in the image.
- **The bumped release task, on a hub pin bump.** A workflow-only pull request skips the smoke build, so a bump touching only workflow files never runs the bumped `build-release-task.yml` on its own pull request. A dispatch of `test-pull-request.yml` on the branch the bump merged into always smoke-builds under it. Its check also lands on any open pull request headed by that branch. Whichever run finishes last decides that pull request's required check, and only the pull request's own run checks prose.
- **A running dashboard.** No workflow starts the container and talks to the dashboard. A change that can affect the entrypoint, the dashboard, or file permissions is verified by building and running the image locally, per the runbook below.

Two traps make a headless test of the running container pass while proving nothing:

- **Device Builder only scans the filesystem while a WebSocket client is subscribed.** The background poll that detects external YAML edits is gated on `SubscriberPresence` (`device_builder.py`), so with no client attached it parks and never runs. A headless test that edits a file, waits, and sees no commit has observed a scanner that was never running. Attach a subscriber first: `ws_connect` to `/ws`, then send `{"command": "subscribe_events", "message_id": "1", "args": {}}`. Run the enabled-case control before the disabled case, and require it to produce the unwanted behavior. If the control is silent, the harness is broken rather than the feature being off.
- **`docker cp` into a path backed by `tmpfs` writes underneath the mount.** The compose stack mounts `tmpfs` at `/tmp`, so a helper script copied there is absent at runtime and anything depending on it silently does nothing while still reporting success. Stage helper files through a bind-mounted volume (`/cache` or `/config`) instead.

## Runbooks

### Build and Run the Image Locally

[`Docker/Compose.yml`](./Docker/Compose.yml) carries the commands in its header:

```sh
docker buildx build --load --platform linux/amd64 --tag esphome:testing --file ./Docker/Dockerfile ./Docker
docker compose --file ./Docker/Compose.yml up --detach
```

The dashboard is then at `http://localhost:6052`. `docker exec -it --user 1001:100 esphome-test /bin/bash` attaches a shell as the non-root user, and `docker compose --file ./Docker/Compose.yml down --volumes` destroys the stack and its test volumes.

Only a `main` publish builds arm64, so exercise an arm64 change locally with a multi-platform build. The platform that is not the host's own runs under emulation. Docker Desktop ships it, and a Linux Docker Engine host lacks it until the `binfmt` step installs it. Run the `binfmt` step once per boot, unless the host registers QEMU at boot, and `docker buildx create` once per machine. The build leaves its result in the build cache rather than loading an image to run:

```sh
docker run --privileged --rm tonistiigi/binfmt --install all
docker buildx create --name esphome-multiarch
docker buildx build --builder esphome-multiarch --platform linux/amd64,linux/arm64 --file ./Docker/Dockerfile ./Docker
```

### Compile a Test Configuration in the Image

The [`validate`](./.github/actions/validate/action.yml) hook, which the hub's `validate-task.yml` runs for pull request CI and the publisher alike, works inside the built image as a non-root user. It first checks that each entrypoint script answers `--help` and refuses an unknown argument. It then runs `/entrypoint/cache.sh`, then `esphome config` and `esphome compile` for each fixture in [`.github/compile-test/`](./.github/compile-test/). Reproduce the compile against a locally built image by bind-mounting the fixtures and running `esphome config` and `esphome compile` for the fixture in question. [`WORKFLOW.md`](./WORKFLOW.md) "The Image Compile Test" states what each fixture covers.

### Check Whether `develop` Is Missing a `main`-Only Fix

A fix that lands on `main` outside the feature -> `develop` -> `main` flow, such as a reconciliation fix for a promotion conflict or a security PR, leaves `develop` behind on that content, and forward-only `develop` never back-merges to catch up. Before basing new work on `develop`, or diagnosing a defect from it, compare content rather than commit history. Run `git diff origin/main origin/develop` and inspect its `-` lines, the `main` side of each difference. A deletion-only hunk (`-` lines with no `+` lines) is content on `main` that `develop` lacks entirely, so the defect may already be fixed on `main`, and the fix is mirrored to `develop` through a follow-up PR targeting `develop`. A commit-log check such as `git log origin/develop..origin/main` is noisy here, because it also lists routine promotion merges and the `main`-direct bot commits whose content `develop` already carries through its own parallel bot PRs.

## Backup and Recovery

There is no state to back up. The repository is the record and GitHub holds it. Every published image is rebuilt from the committed `Docker/Dockerfile` and the pins in `upstream-version.json`, so recovering a published image means re-running the publisher against the commit that carries that pin, not restoring anything. A local compose stack is disposable, and `down --volumes` deletes it outright.

## Logs and Debugging

Workflow runs are the log for anything that happened in CI or in a publish. `gh run list --branch <branch>` and `gh run view <id> --log-failed` reach them. A lint failure reproduces locally, because CI runs the same tools against the same committed configuration.

A failure that appears only in the running image needs a container. Bring the stack up per the runbook above, read `docker logs esphome-test`, and attach a shell as the non-root user. The compose stack and the devcontainer both set `ESPHOME_VERBOSE=true`, so their logs are already verbose.

## Tool Usage

- **Nerdbank.GitVersioning** computes the build version from `version.json` and git height. The hub's `get-version-task.yml`, which the release task calls, runs it through `dotnet/nbgv@master`, the fleet's one documented unpinned action.
- **The upstream-version tracker** resolves the latest `esphome` and `esphome-device-builder` versions from PyPI and opens rolling bump PRs on `upstream-version-main` and `upstream-version-develop`. It is the only writer of `upstream-version.json`, so that file is never hand-edited.
- **The upstream-dependency watcher** snapshots the apt package list ESPHome's own base image installs into `upstream-dependency.json` and opens a PR when it moves. Whether a package upstream adds belongs in this image is a human decision, so that PR is deliberately not auto-merged.

## Configuration Layout

- [`ESPHome-NonRoot.code-workspace`](./ESPHome-NonRoot.code-workspace) is this repo's workspace file. Open it in VS Code rather than the folder so its settings and recommended extensions apply.
- [`cspell.json`](./cspell.json) is the single source of truth for the spell-check dictionary and ignore paths, shared by the editor and CI. A new project word belongs in its `words` list, not in a parallel word list in a `.code-workspace` file.
- [`.markdownlint-cli2.jsonc`](./.markdownlint-cli2.jsonc) configures markdownlint, and [`.editorconfig-checker.json`](./.editorconfig-checker.json) scopes the line-ending and whitespace check.
- [`.vscode/tasks.json`](./.vscode/tasks.json) and [`.vscode/launch.json`](./.vscode/launch.json) hold the editor tasks.
- [`.github/actions/`](./.github/actions/) holds this repo's hooks into the hub's reusable workflow tasks: `docker-prepare` for the upstream pins and image tags, `validate` for the compile test, and `resolve-upstream` for the tracker's PyPI lookup. [`WORKFLOW.md`](./WORKFLOW.md) section 7 states what each does.
- Repository settings, branch rulesets, and the secret inventory are hub-hosted. The hub's `repo-config/configure.sh` applies and checks them against this repo, and the hub's `spec/secrets.json` names the secrets each mechanism needs, here the Docker Hub pair and the codegen App pair, each in the Actions and Dependabot stores.
- [`version.json`](./version.json) is the Nerdbank.GitVersioning input, and [`upstream-version.json`](./upstream-version.json) the shipped upstream pins.
- [`host-tools.json`](./host-tools.json) declares the host tooling this repo needs beyond the fleet declaration, which is nothing today.
- Release notes keep a short summary in [`README.md`](./README.md) and the full history in [`HISTORY.md`](./HISTORY.md), and both are updated when a release is cut.
