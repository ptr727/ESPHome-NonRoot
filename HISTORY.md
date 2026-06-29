# ESPHome-NonRoot

## Release History

- Version 1.8:
  - Reworked the CI/CD pipeline to a branch-scoped, one-branch-per-run model: a weekly scheduled run and a path-scoped push on a tracked-upstream-version change publish `main` (stable, Docker `latest`), a manual dispatch publishes the branch it is started from, and the daily upstream-version tracker keeps `upstream-version.json` current; ordinary merges no longer publish.
  - Version-tagged the container: images also publish a `:SemVer2` tag (`X.Y.<height>`) alongside the moving `latest` / `develop` and pinned `:<esphome-version>` tags, and each version gets a GitHub release.
  - Added `WORKFLOW.md` (the canonical CI/CD specification) and `repo-config/` (rulesets and repository settings as code).
- Version 1.7:
  - Migrated the dashboard to ESPHome's new [`esphome-device-builder`][device-builder-link] package ([#60][issue-60-link]).
  - Switched the image build to a `uv` virtual environment copied into the slim final stage.
  - Pinned and auto-tracked the `esphome-device-builder` version alongside `esphome`.
  - Removed the no-op `ESPHOME_DASHBOARD_USE_PING` setting; device-builder always uses mDNS with a ping fallback.
- Version 1.6:
  - Support `tmpfs` for optional `/tmp` volume, use `/tmp` instead of `/cache/tmp` for temp files.
  - Make `/cache` volume mount optional.
  - Replace `locales-all` package with `locales` to reduce image size.
- Version 1.5:
  - Using Python 3.13 base image.
- Version 1.4:
  - Removed custom handling for `ESPHOME_VERBOSE` enabling `--verbose`, [PR][esphome-pr-6987-link] merged.
- Version 1.3:
  - Added Dev Container [Workspace](./.devcontainer/devcontainer.code-workspace) that maps `config` and `cache` volumes.
- Version 1.2:
  - Delete temp directory contents and prune PIO cached content on startup.
  - Added [Dev Container][devcontainer-link] that can be used for [ESPHome][vscode-python-debug-link] or [PlatformIO][pio-debug-link] debugging.
- Version 1.1:
  - Added daily actions job to trigger a build if the ESPHome version changed.
- Version 1.0:
  - Initial public release.

[devcontainer-link]: https://code.visualstudio.com/docs/devcontainers/containers
[device-builder-link]: https://github.com/esphome/device-builder
[esphome-pr-6987-link]: https://github.com/esphome/esphome/pull/6987
[issue-60-link]: https://github.com/ptr727/ESPHome-NonRoot/issues/60
[pio-debug-link]: https://docs.platformio.org/en/latest/plus/debugging.html
[vscode-python-debug-link]: https://code.visualstudio.com/docs/python/debugging
