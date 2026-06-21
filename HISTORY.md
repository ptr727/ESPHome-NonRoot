# ESPHome-NonRoot

## Release History

- Version 1.7:
  - Migrated the dashboard to ESPHome's new [`esphome-device-builder`](https://github.com/esphome/device-builder) package ([#60](https://github.com/ptr727/ESPHome-NonRoot/issues/60)).
  - Switched the image build to a `uv` virtual environment copied into the slim final stage.
  - Pin and auto-track the `esphome-device-builder` version alongside `esphome`.
  - Removed the no-op `ESPHOME_DASHBOARD_USE_PING` setting; device-builder always uses mDNS with a ping fallback.
- Version 1.6:
  - Support `tmpfs` for optional `/tmp` volume, use `/tmp` instead of `/cache/tmp` for temp files.
  - Make `/cache` volume mount optional.
  - Replace `locales-all` package with `locales` to reduce image size.
- Version 1.5:
  - Using Python 3.13 base image.
- Version 1.4:
  - Removed custom handling for `ESPHOME_VERBOSE` enabling `--verbose`, [PR](https://github.com/esphome/esphome/pull/6987) merged.
- Version 1.3:
  - Added Dev Container [Workspace](./.devcontainer/devcontainer.code-workspace) that maps `config` and `cache` volumes.
- Version 1.2:
  - Delete temp directory contents and prune PIO cached content on startup.
  - Added [Dev Container](https://code.visualstudio.com/docs/devcontainers/containers) that can be used for [ESPHome](https://code.visualstudio.com/docs/python/debugging) or [PlatformIO](https://docs.platformio.org/en/latest/plus/debugging.html) debugging.
- Version 1.1:
  - Added daily actions job to trigger a build if the ESPHome version changed.
- Version 1.0:
  - Initial public release.
