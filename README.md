# ESPHome-NonRoot

[ESPHome][esphome-link] docker container that supports non-root operation.

## License

Licensed under the [MIT License][license-link]  
![GitHub License][license-shield]

## Build

Code and Pipeline is on [GitHub][github-link].  
Docker image is published on [Docker Hub][docker-link].  
Image is rebuilt weekly, or when a new ESPHome version is released, picking up the latest ESPHome release and upstream container updates.

## Status

[![Last Commit][last-commit-shield]][commit-link]  
[![Workflow Status][workflow-status-shield]][actions-link]  
[![Last Build][last-build-shield]][actions-link]  
[![Docker Latest][docker-latest-version-shield]][docker-link]

## Release Notes

- Version 1.5:
  - Using Python 3.13 base image.
- Version 1.4:
  - Removed custom handling for `ESPHOME_VERBOSE` enabling `--verbose`, [PR](https://github.com/esphome/esphome/pull/6987) merged.
- Version 1.3:
  - Added Dev Container [Workspace](./.devcontainer/devcontainer.code-workspace) that maps `config` and `cache` volumes.
  - ~~Converted Docker base image from `python:slim` based on Debian to `python:alpine` based on Alpine, uncompressed image size reduced from \~650MB to \~280MB.~~
    - Reverted, see [Issue #29](https://github.com/ptr727/ESPHome-NonRoot/issues/29).
- Version 1.2:
  - Delete temp directory contents and prune PIO cached content on startup.
  - Added [Dev Container](https://code.visualstudio.com/docs/devcontainers/containers) that can be used for [ESPHome](https://code.visualstudio.com/docs/python/debugging) or [PlatformIO](https://docs.platformio.org/en/latest/plus/debugging.html) debugging.
- Version 1.1:
  - Added daily actions job to trigger a build if the ESPHome version changed.
- Version 1.0:
  - Initial public release.

## Usage

### Configuration

- `volumes` :
  - `/config` : Volume mapping to project files, e.g. `/data/esphome/config:/config`.
  - `/cache` : Volume mapping to runtime generated content, e.g. `/data/esphome/cache:/cache`.
- `user` (Optional) : Run the container under the specified user account.
  - Use the `uid:gid` notation, e.g. `user: 1001:100`.
    - Get the `uid` : `sudo id -u nonroot`.
    - Get the `gid` : `sudo id -g nonroot`.
  - Use an existing user or create a system account on the host.
    - `adduser --no-create-home --disabled-password --system --group users nonroot`.
  - Omitting the `user` option will run under default `root` account.
  - Make sure the container user has permissions to the mapped `/config` and `/cache` volumes.
    - `sudo chown -R nonroot:users /data/esphome`
    - `sudo chmod -R ug=rwx,o=rx /data/esphome`
- `environment` :
  - `ESPHOME_VERBOSE` (Optional) : Enables [verbose](https://esphome.io/guides/cli.html#cmdoption-v-verbose) log output, e.g. `ESPHOME_VERBOSE=true`.
  - `ESPHOME_DASHBOARD_USE_PING` (Optional) : Use [`ping` instead of `mDNS`](https://github.com/esphome/issues/issues/641#issuecomment-534156628) to test if nodes are up, e.g. `ESPHOME_DASHBOARD_USE_PING=true`.
  - `TZ` (Optional) : Sets the [timezone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones), e.g. `TZ=America/Los_Angeles`, default is `Etc/UTC`.

### Examples

#### Docker Compose Dashboard

```yaml
services:
  esphome:
    image: docker.io/ptr727/esphome-nonroot:latest
    container_name: esphome-test
    restart: unless-stopped
    user: 1001:100
    environment:
      - TZ=America/Los_Angeles
      - ESPHOME_VERBOSE=true
      - ESPHOME_DASHBOARD_USE_PING=true
    network_mode: bridge
    ports:
      - 6052:6052
    volumes:
      - /data/esphome/config:/config
      - /data/esphome/cache:/cache
```

```shell
# Create nonroot user
adduser --no-create-home --disabled-password --system --group users nonroot
id nonroot
# uid=1001(nonroot) gid=100(users) groups=100(users)

# Prepare directories for use by nonroot:users
mkdir -p /data/esphome/config /data/esphome/cache
sudo chown -R nonroot:users /data/esphome
sudo chmod -R ug=rwx,o=rx /data/esphome

# Launch stack
docker compose --file ./Docker/Compose.yml up --detach

# Open browser: http://localhost:6052
# Attach shell: docker exec -it --user 1001:100 esphome-test /bin/bash

# Destroy stack
docker compose --file ./Docker/Compose.yml down --volumes
```

### Docker Run Command

```shell
# esphome version
docker run --rm --pull always --name esphome-test -v /data/esphome/config:/config -v /data/esphome/cache:/cache ptr727/esphome-nonroot:latest esphome version
```

```console
latest: Pulling from ptr727/esphome-nonroot
Digest: sha256:8f32848551446d0420390477fccb8c833d879b640b95533f443cb623882e9688
Status: Image is up to date for ptr727/esphome-nonroot:latest
Version: 2024.5.5
```

### Docker Run Interactive Shell

```shell
# /bin/bash
docker run --rm --user 1001:100 -it --pull always --name esphome-test -v /data/esphome/config:/config -v /data/esphome/cache:/cache ptr727/esphome-nonroot:latest /bin/bash
```

```console
latest: Pulling from ptr727/esphome-nonroot
Digest: sha256:8f32848551446d0420390477fccb8c833d879b640b95533f443cb623882e9688
Status: Image is up to date for ptr727/esphome-nonroot:latest
I have no name!@012d4b62d376:/config$ id
uid=1001 gid=100(users) groups=100(users)
I have no name!@012d4b62d376:/config$
```

## Use Case

- Running containers as non-privileged and as non-root is a docker best practice.
- The official ESPHome [docker container][esphome-docker-link] does not support running as a non-root user.
  - [Issue #3558 : Docker requires root](https://github.com/esphome/issues/issues/3558).
  - [Issue #2752 : Docker image does not allow running rootless](https://github.com/esphome/issues/issues/2752).
  - [Issue #3929 : Not possible to run docker esphome/esphome container - problem with platformio](https://github.com/esphome/issues/issues/3929).
  - [HA Community : Is there a way to run ESPhome in docker with custom UID and GID](https://community.home-assistant.io/t/is-there-a-way-to-run-esphome-in-docker-with-custom-uid-and-gid/668256).
  - Etc.
- Issue analysis based on ESPHome `2024.5.5` (current version as of writing) [`Dockerfile`](https://github.com/esphome/esphome/blob/2024.5.5/docker/Dockerfile):
  - [`PLATFORMIO_GLOBALLIB_DIR=/piolibs`](https://github.com/esphome/esphome/blob/2024.5.5/docker/Dockerfile#L67) sets the PlatformIO [`globallib_dir`](https://docs.platformio.org/en/latest/envvars.html#envvar-PLATFORMIO_GLOBALLIB_DIR) option to `/piolibs`.
    - `/piolibs` is not mapped to an external volume.
    - `/piolibs` has default permissions and requires `root` write permissions at runtime.
    - The [`globallib_dir`](https://docs.platformio.org/en/latest/projectconf/sections/platformio/options/directory/globallib_dir.html#projectconf-pio-globallib-dir) option has been deprecated.
      - `This option is DEPRECATED. We do not recommend using global libraries for new projects. Please use a declarative approach for the safety-critical embedded development and declare project dependencies using the lib_deps option.`
  - [`platformio_install_deps.py`](https://github.com/esphome/esphome/blob/2024.5.5/docker/Dockerfile#L101) installs global libraries using [`pio pkg install -g`](https://github.com/esphome/esphome/blob/2024.5.5/script/platformio_install_deps.py#L58), the [`-g`](https://docs.platformio.org/en/stable/core/userguide/pkg/cmd_install.html#cmdoption-pio-pkg-install-g) option has been deprecated.
    - `We DO NOT recommend installing libraries in the global storage. Please use the lib_deps option and declare library dependencies per project.`
  - The [presence](https://github.com/esphome/esphome/blob/2024.5.5/docker/docker_entrypoint.sh#L6) of a `/cache` directory changes `pio_cache_base` to `/cache/platformio`, the default is `/config/.esphome/platformio`
    - `PLATFORMIO_PLATFORMS_DIR="${pio_cache_base}/platforms"`, `PLATFORMIO_PACKAGES_DIR="${pio_cache_base}/packages"`, and `PLATFORMIO_CACHE_DIR="${pio_cache_base}/cache"` is explicitly set as child directories of `pio_cache_base`.
    - It is simpler to set `PLATFORMIO_CORE_DIR` PlatformIO [`core_dir`](https://docs.platformio.org/en/latest/envvars.html#envvar-PLATFORMIO_CORE_DIR) option, and not setting `PLATFORMIO_PLATFORMS_DIR` [`platforms_dir`](https://docs.platformio.org/en/latest/projectconf/sections/platformio/options/directory/platforms_dir.html#projectconf-pio-platforms-dir), `PLATFORMIO_PACKAGES_DIR` [`packages_dir`](https://docs.platformio.org/en/latest/projectconf/sections/platformio/options/directory/packages_dir.html#projectconf-pio-packages-dir), and `PLATFORMIO_CACHE_DIR` [`cache_dir`](https://docs.platformio.org/en/latest/projectconf/sections/platformio/options/directory/cache_dir.html#projectconf-pio-cache-dir) options, that are by default child directories of `core_dir`.
  - The [presence](https://github.com/esphome/esphome/blob/2024.5.5/docker/docker_entrypoint.sh#L26) of a `/build` directory sets the `ESPHOME_BUILD_PATH` environment variable, that [sets](https://github.com/esphome/esphome/blob/2024.5.5/esphome/core/config.py#L204) the `CONF_BUILD_PATH` ESPHome [`build_path`](https://esphome.io/components/esphome.html) option, the default is `/config/.esphome/build`.
    - The directory presence detection could override an explicitly set `ESPHOME_BUILD_PATH` option.
  - `ESPHOME_DATA_DIR` can be used to set the ESPHome [`data_dir`](https://github.com/esphome/esphome/blob/2024.5.5/esphome/core/__init__.py#L595) intermediate build output directory, the [default](https://github.com/esphome/esphome/blob/2024.5.5/esphome/core/__init__.py#L599) is `/config/.esphome`, or hardcoded to `/data` for the HA addon image.
  - [`PLATFORMIO_CORE_DIR`](https://docs.platformio.org/en/latest/envvars.html#envvar-PLATFORMIO_CORE_DIR) PlatformIO [`core_dir`](https://docs.platformio.org/en/latest/projectconf/sections/platformio/options/directory/core_dir.html#projectconf-pio-core-dir) option is not set and defaults to `~/.platformio`.
  - [`PIP_CACHE_DIR`](https://pip.pypa.io/en/stable/topics/caching/#pip-cache-dir) is not set and defaults to `~/.cache/pip`.
  - `HOME` (`~`) is not set and defaults to e.g. `/home/[username]` or `/` or `/nonexistent` that either does not exists or the executing user does not have write permissions.

## Project Design

- Use [Python](https://hub.docker.com/_/python) docker base image simplifying use for Python in a container environment.
- Use a multi-stage build minimizing size and layer complexity of the final stage.
- Build [`wheel`](https://pip.pypa.io/en/stable/cli/pip_wheel/) archives for the platform in the builder stage, and install the platform specific generated wheel packages in the final stage.
- Set appropriate PlatformIO and ESPHome environment variables to store projects in `/config` and dynamic and temporary content in `/cache` volumes.
- Refer to [`Dockerfile`](./Docker/Dockerfile) for container details.
- Refer to [`BuildDockerPush.yml`](./.github/workflows/BuildDockerPush.yml) and for pipeline details.

## Debugging

The [included](./.devcontainer/devcontainer.json) [Dev Container](https://code.visualstudio.com/docs/devcontainers/containers) can be used for [ESPHome Python](https://code.visualstudio.com/docs/python/debugging) or [PlatformIO C++](https://docs.platformio.org/en/latest/plus/debugging.html) debugging in VSCode.

Detailed debug setup details are beyond the scope of this project, refer to my [ESPHome-Config](https://github.com/ptr727/ESPHome-Config) project for slightly more complete debugging setup instructions.

## Notes

- ESPHome's [`Dockerfile`][esphome-dockerfile-link] installs `LIB_DEPS` and `BUILD_DEPS`, that should not be required when installing using `wheel`, right?
- Using unversioned base Python docker images will use the current released version of Python, and may [not](https://github.com/esphome/issues/issues/6321) always be compatible with ESPHome.
- Alpine uses `musl` not `glibc`, `gcompat` is [required](https://github.com/platformio/platformio-core/issues/4996) for PIO and tools that do not have native `musl` support.
- Track open [PR](https://github.com/esphome/esphome/pull/7604) for a general `LOG_LEVEL` configuration vs. using `ESPHOME_VERBOSE`.
- Chance of a version mismatch when tagging the docker image with the current ESPHome version vs. the version actually installed when building the image.

[actions-link]: https://github.com/ptr727/ESPHome-NonRoot/actions
[commit-link]: https://github.com/ptr727/ESPHome-NonRoot/commits/main
[docker-latest-version-shield]: https://img.shields.io/docker/v/ptr727/esphome-nonroot/latest?label=Docker%20Latest&logo=docker
[docker-link]: https://hub.docker.com/r/ptr727/esphome-nonroot
[workflow-status-shield]: https://img.shields.io/github/actions/workflow/status/ptr727/ESPHome-NonRoot/BuildDockerPush.yml?logo=github&label=Workflow%20Status
[github-link]: https://github.com/ptr727/ESPHome-NonRoot
[last-build-shield]: https://byob.yarr.is/ptr727/ESPHome-NonRoot/lastbuild
[last-commit-shield]: https://img.shields.io/github/last-commit/ptr727/ESPHome-NonRoot?logo=github&label=Last%20Commit
[license-link]: ./LICENSE
[license-shield]: https://img.shields.io/github/license/ptr727/ESPHome-NonRoot?label=License
[esphome-link]: https://esphome.io
[esphome-docker-link]: https://hub.docker.com/r/esphome/esphome
[esphome-dockerfile-link]: https://github.com/esphome/esphome/blob/dev/docker/Dockerfile
