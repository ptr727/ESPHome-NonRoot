# Operations

How this repo is run: what verifying a change requires before it is pushed, how to build and run the image locally, and where the repo-specific tooling is configured.

## Local Verification

Verifying a change here means running the gates, then running by hand the parts of the contract the pull request pipeline never reaches.

The gates are the document linters, `markdownlint-cli2`, `cspell` (scoped to `README.md` and `HISTORY.md`), `actionlint`, and `editorconfig-checker`. CI runs all four, so run all four before every push rather than the ones that look relevant. The hub-hosted `scripts/docker_lint.py`, run from a hub checkout with `--root` set to this repo, runs them through Docker with no local toolchain. It also runs shellcheck and shfmt over `Docker/entrypoint/*.sh`, which CI does not gate, so pass `--linter` once per gate to reproduce exactly the four CI runs. A change to `Docker/` is also smoke-built locally with the `docker buildx build` command in the runbook below before it is pushed, the same amd64 build CI runs.

**What pull request CI structurally cannot exercise:**

- **The arm64 image.** The pull request smoke build and every `develop` publish build `linux/amd64` only. Only a full `main` publish builds `linux/amd64,linux/arm64`, so an arm64-only break first surfaces on `main`.
- **The firmware compile test, unless the change touches the image.** `test-pull-request.yml` gates the compile test on a change to the image or to what is compiled in it. A change outside those paths merges without anything compiling firmware in the image.
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

### Compile a Test Configuration in the Image

The `compile-test` job in `validate-task.yml`, which push CI and the publisher share, runs `/entrypoint/cache.sh`, then `esphome config` and `esphome compile` for each fixture in [`.github/compile-test/`](./.github/compile-test/), inside the built image as a non-root user. Reproduce it against a locally built image by bind-mounting the fixtures and running the same two commands for the fixture in question. [`WORKFLOW.md`](./WORKFLOW.md) "The image compile test" states what each fixture covers.

### Check Whether `develop` Is Missing a `main`-Only Fix

A fix that lands on `main` outside the feature -> `develop` -> `main` flow, such as a reconciliation fix for a promotion conflict or a security PR, leaves `develop` behind on that content, and forward-only `develop` never back-merges to catch up. Before basing new work on `develop`, or diagnosing a defect from it, compare content rather than commit history. Run `git diff origin/main origin/develop` and inspect its `-` lines, the `main` side of each difference. A deletion-only hunk (`-` lines with no `+` lines) is content on `main` that `develop` lacks entirely, so the defect may already be fixed on `main`, and the fix is mirrored to `develop` through a follow-up PR targeting `develop`. A commit-log check such as `git log origin/develop..origin/main` is noisy here, because it also lists routine promotion merges and the `main`-direct bot commits whose content `develop` already carries through its own parallel bot PRs.

## Backup and Recovery

There is no state to back up. The repository is the record and GitHub holds it. Every published image is rebuilt from the committed `Docker/Dockerfile` and the pins in `upstream-version.json`, so recovering a published image means re-running the publisher against the commit that carries that pin, not restoring anything. A local compose stack is disposable, and `down --volumes` deletes it outright.

## Logs and Debugging

Workflow runs are the log for anything that happened in CI or in a publish. `gh run list --branch <branch>` and `gh run view <id> --log-failed` reach them. A lint failure reproduces locally, because CI runs the same tools against the same committed configuration.

A failure that appears only in the running image needs a container. Bring the stack up per the runbook above, read `docker logs esphome-test`, and attach a shell as the non-root user. The compose stack and the devcontainer both set `ESPHOME_VERBOSE=true`, so their logs are already verbose.

## Tool Usage

- **Nerdbank.GitVersioning** computes the build version from `version.json` and git height. The workflows run it through `dotnet/nbgv@master`, the fleet's one documented unpinned action.
- **The upstream-version tracker** resolves the latest `esphome` and `esphome-device-builder` versions from PyPI and opens rolling bump PRs on `upstream-version-main` and `upstream-version-develop`. It is the only writer of `upstream-version.json`, so that file is never hand-edited.
- **The upstream-dependency watcher** snapshots the apt package list ESPHome's own base image installs into `upstream-dependency.json` and opens a PR when it moves. Whether a package upstream adds belongs in this image is a human decision, so that PR is deliberately not auto-merged.

## Configuration Layout

- [`ESPHome-NonRoot.code-workspace`](./ESPHome-NonRoot.code-workspace) is this repo's workspace file. Open it in VS Code rather than the folder so its settings and recommended extensions apply.
- [`cspell.json`](./cspell.json) is the single source of truth for the spell-check dictionary and ignore paths, shared by the editor and CI. A new project word belongs in its `words` list, not in a parallel word list in a `.code-workspace` file.
- [`.markdownlint-cli2.jsonc`](./.markdownlint-cli2.jsonc) configures markdownlint, and [`.editorconfig-checker.json`](./.editorconfig-checker.json) scopes the line-ending and whitespace check.
- [`.vscode/tasks.json`](./.vscode/tasks.json) and [`.vscode/launch.json`](./.vscode/launch.json) hold the editor tasks.
- [`version.json`](./version.json) is the Nerdbank.GitVersioning input, and [`upstream-version.json`](./upstream-version.json) the shipped upstream pins.
- [`host-tools.json`](./host-tools.json) declares the host tooling this repo needs beyond the fleet declaration, which is nothing today.
- Release notes keep a short summary in [`README.md`](./README.md) and the full history in [`HISTORY.md`](./HISTORY.md), and both are updated when a release is cut.
