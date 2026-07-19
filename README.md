# ESPHome-NonRoot

[ESPHome][esphome-link] docker container that supports non-root operation.

## Build

Code and pipeline are on [GitHub][github-link].\
Docker image is published on [Docker Hub][docker-link].\
Image is rebuilt on the weekly schedule and on demand, picking up the latest tracked ESPHome release and upstream container updates.

## Status

[![Last Commit][last-commit-shield]][commit-link]\
[![Workflow Status][workflow-status-shield]][actions-link]\
[![Last Build][last-build-shield]][actions-link]\
[![Docker Latest][docker-latest-version-shield]][docker-link]

## Release Notes

- Version 1.9:
  - Added the `libusb-1.0-0` runtime library that the ESP-IDF `openocd-esp32` tool check requires, fixing ESP-IDF firmware compile failures ([#161][issue-161-link]).
  - Added `ccache`, which ESPHome enables automatically for ESP-IDF builds to speed up repeat compiles.
  - Publishing now compiles real firmware inside the image first, so a missing runtime dependency blocks the release instead of reaching Docker Hub.
  - Added a daily check for dependency changes in the ESPHome base image the container tracks.
  - Disabled Device Builder's version history feature, stopping it from committing `/config` changes to git ([device-builder#2193][device-builder-version-history-link]).

See [Release History](./HISTORY.md) for complete release notes and older versions.

> ⚠️ **Warning:** Device Builder's version history feature commits every YAML change under `/config` to git, using an `ESPHome Device Builder <device-builder@esphome.io>` identity, unsigned, and bypassing hooks. Where `/config` is a bind mount into an existing repository, those commits land in that repository ([device-builder#2193][device-builder-version-history-link]). This container disables the setting at every launch, warning and continuing if `/config` cannot be written; set `ESPHOME_VERSION_HISTORY=true` to keep the upstream behavior.

## Usage

### Configuration

- `volumes` :
  - `/config` : Volume mapping to project files.
  - `/cache` (Optional) : Volume mapping to runtime generated content.
  - `/tmp` (Optional) : Volume mapping for temp files.
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
  - `ESPHOME_VERBOSE` (Optional) : Enables [verbose][esphome-verbose-link] log output, e.g. `ESPHOME_VERBOSE=true`.
  - `ESPHOME_VERSION_HISTORY` (Optional) : Enables Device Builder's git version history auto-commit, e.g. `ESPHOME_VERSION_HISTORY=true`, default is `false`.
  - `TZ` (Optional) : Sets the [timezone][tz-link], e.g. `TZ=America/Los_Angeles`, default is `Etc/UTC`.

### Docker Compose Dashboard

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
    network_mode: bridge
    ports:
      - 6052:6052
    volumes:
      - /data/esphome/config:/config
      - /data/esphome/cache:/cache
    tmpfs:
      - /tmp:size=1g,mode=1777
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

### Docker Compose with Static IP and Traefik

```yaml
  esphome:
    image: docker.io/ptr727/esphome-nonroot:latest
    container_name: esphome
    hostname: esphome
    domainname: ${DOMAIN_NAME}
    restart: unless-stopped
    user: ${USER_NONROOT_ID}:${USERS_GROUP_ID}
    group_add:
      - ${DOCKER_GROUP_ID}
    security_opt: # Use with care
      - seccomp=unconfined
      - apparmor=unconfined
    environment:
      - TZ=${TZ}
      # - ESPHOME_VERBOSE=true
    volumes:
      - ${APPDATA_DIR}/esphome/config:/config
      - ${APPDATA_DIR}/esphome/cache:/cache
    tmpfs:
      - /tmp:size=1g,mode=1777
    networks:
      public_network:
        ipv4_address: ${ESPHOME_IP}
        mac_address: ${ESPHOME_MAC}
      local_network:
      stack_network:
    labels:
      - traefik.enable=true
      - traefik.http.routers.esphome.rule=HostRegexp(`^esphome${DOMAIN_REGEX}$$`)
      - traefik.http.services.esphome.loadbalancer.server.scheme=http
      - traefik.http.services.esphome.loadbalancer.server.port=6052
```

## Use Case

- Running containers as non-privileged and as non-root is a docker best practice.
- The official ESPHome [docker container][esphome-docker-link] does not support running as a non-root user.
  - [Issue #3558 : Docker requires root][issue-3558-link].
  - [Issue #2752 : Docker image does not allow running rootless][issue-2752-link].
  - [Issue #3929 : Not possible to run docker esphome/esphome container - problem with platformio][issue-3929-link].
  - [HA Community : Is there a way to run ESPhome in docker with custom UID and GID][ha-community-link].
  - Etc.
- Issue analysis based on ESPHome `2024.5.5` (the upstream version analyzed when this project was created) [`Dockerfile`][esphome-dockerfile-link]:
  - [`PLATFORMIO_GLOBALLIB_DIR=/piolibs`][esphome-globallib-link] sets the PlatformIO [`globallib_dir`][pio-globallib-env-link] option to `/piolibs`.
    - `/piolibs` is not mapped to an external volume.
    - `/piolibs` has default permissions and requires `root` write permissions at runtime.
    - The [`globallib_dir`][pio-globallib-link] option has been deprecated.
      - `This option is DEPRECATED. We do not recommend using global libraries for new projects. Please use a declarative approach for the safety-critical embedded development and declare project dependencies using the lib_deps option.`
  - [`platformio_install_deps.py`][esphome-installdeps-link] installs global libraries using [`pio pkg install -g`][esphome-pkginstall-link], the [`-g`][pio-pkg-g-link] option has been deprecated.
    - `We DO NOT recommend installing libraries in the global storage. Please use the lib_deps option and declare library dependencies per project.`
  - The [presence][esphome-entrypoint-cache-link] of a `/cache` directory changes `pio_cache_base` to `/cache/platformio`, the default is `/config/.esphome/platformio`
    - `PLATFORMIO_PLATFORMS_DIR="${pio_cache_base}/platforms"`, `PLATFORMIO_PACKAGES_DIR="${pio_cache_base}/packages"`, and `PLATFORMIO_CACHE_DIR="${pio_cache_base}/cache"` is explicitly set as child directories of `pio_cache_base`.
    - It is simpler to set `PLATFORMIO_CORE_DIR` PlatformIO [`core_dir`][pio-coredir-env-link] option, and not setting `PLATFORMIO_PLATFORMS_DIR` [`platforms_dir`][pio-platformsdir-link], `PLATFORMIO_PACKAGES_DIR` [`packages_dir`][pio-packagesdir-link], and `PLATFORMIO_CACHE_DIR` [`cache_dir`][pio-cachedir-link] options, that are by default child directories of `core_dir`.
  - The [presence][esphome-entrypoint-build-link] of a `/build` directory sets the `ESPHOME_BUILD_PATH` environment variable, that [sets][esphome-buildpath-sets-link] the `CONF_BUILD_PATH` ESPHome [`build_path`][esphome-buildpath-link] option, the default is `/config/.esphome/build`.
    - The directory presence detection could override an explicitly set `ESPHOME_BUILD_PATH` option.
  - `ESPHOME_DATA_DIR` can be used to set the ESPHome [`data_dir`][esphome-datadir-link] intermediate build output directory, the [default][esphome-datadir-default-link] is `/config/.esphome`, or hardcoded to `/data` for the HA addon image.
  - [`PLATFORMIO_CORE_DIR`][pio-coredir-env-link] PlatformIO [`core_dir`][pio-coredir-link] option is not set and defaults to `~/.platformio`.
  - [`PIP_CACHE_DIR`][pip-cache-link] is not set and defaults to `~/.cache/pip`.
  - `HOME` (`~`) is not set and defaults to e.g. `/home/[username]` or `/` or `/nonexistent` that either does not exists or the executing user does not have write permissions.

## Project Design

- Use [Python][python-link] docker base image simplifying use for Python in a container environment.
- Use a multi-stage build minimizing size and layer complexity of the final stage.
- Use [`uv`][uv-link] to build a virtual environment in the builder stage, and copy the self-contained environment into the slim final stage.
- Set appropriate PlatformIO and ESPHome environment variables to store projects in `/config` and dynamic and temporary content in `/cache` volumes.
- Refer to [`Dockerfile`](./Docker/Dockerfile) for container details.
- Refer to [`publish-release.yml`](./.github/workflows/publish-release.yml) (the publisher) and [`build-docker-task.yml`](./.github/workflows/build-docker-task.yml) (the image build) for pipeline details.

## Debugging

The [included](./.devcontainer/devcontainer.json) [Dev Container][devcontainer-link] can be used for [ESPHome Python][vscode-python-debug-link] or [PlatformIO C++][pio-debug-link] debugging in VSCode.

Detailed debug setup details are beyond the scope of this project, refer to my [ESPHome-Config][esphome-config-link] project for slightly more complete debugging setup instructions.

## License

Licensed under the [MIT License][license-link]\
![GitHub License][license-shield]

[actions-link]: https://github.com/ptr727/ESPHome-NonRoot/actions
[commit-link]: https://github.com/ptr727/ESPHome-NonRoot/commits/main
[devcontainer-link]: https://code.visualstudio.com/docs/devcontainers/containers
[device-builder-version-history-link]: https://github.com/esphome/device-builder/issues/2193
[docker-latest-version-shield]: https://img.shields.io/docker/v/ptr727/esphome-nonroot/latest?label=Docker%20Latest&logo=docker
[docker-link]: https://hub.docker.com/r/ptr727/esphome-nonroot
[esphome-buildpath-link]: https://esphome.io/components/esphome.html
[esphome-buildpath-sets-link]: https://github.com/esphome/esphome/blob/2024.5.5/esphome/core/config.py#L204
[esphome-config-link]: https://github.com/ptr727/ESPHome-Config
[esphome-datadir-default-link]: https://github.com/esphome/esphome/blob/2024.5.5/esphome/core/__init__.py#L599
[esphome-datadir-link]: https://github.com/esphome/esphome/blob/2024.5.5/esphome/core/__init__.py#L595
[esphome-docker-link]: https://hub.docker.com/r/esphome/esphome
[esphome-dockerfile-link]: https://github.com/esphome/esphome/blob/2024.5.5/docker/Dockerfile
[esphome-entrypoint-build-link]: https://github.com/esphome/esphome/blob/2024.5.5/docker/docker_entrypoint.sh#L26
[esphome-entrypoint-cache-link]: https://github.com/esphome/esphome/blob/2024.5.5/docker/docker_entrypoint.sh#L6
[esphome-globallib-link]: https://github.com/esphome/esphome/blob/2024.5.5/docker/Dockerfile#L67
[esphome-installdeps-link]: https://github.com/esphome/esphome/blob/2024.5.5/docker/Dockerfile#L101
[esphome-link]: https://esphome.io
[esphome-pkginstall-link]: https://github.com/esphome/esphome/blob/2024.5.5/script/platformio_install_deps.py#L58
[esphome-verbose-link]: https://esphome.io/guides/cli.html#cmdoption-v-verbose
[github-link]: https://github.com/ptr727/ESPHome-NonRoot
[ha-community-link]: https://community.home-assistant.io/t/is-there-a-way-to-run-esphome-in-docker-with-custom-uid-and-gid/668256
[issue-2752-link]: https://github.com/esphome/issues/issues/2752
[issue-3558-link]: https://github.com/esphome/issues/issues/3558
[issue-3929-link]: https://github.com/esphome/issues/issues/3929
[issue-161-link]: https://github.com/ptr727/ESPHome-NonRoot/issues/161
[last-build-shield]: https://byob.yarr.is/ptr727/ESPHome-NonRoot/lastbuild
[last-commit-shield]: https://img.shields.io/github/last-commit/ptr727/ESPHome-NonRoot?logo=github&label=Last%20Commit
[license-link]: ./LICENSE
[license-shield]: https://img.shields.io/github/license/ptr727/ESPHome-NonRoot?label=License
[pio-cachedir-link]: https://docs.platformio.org/en/latest/projectconf/sections/platformio/options/directory/cache_dir.html#projectconf-pio-cache-dir
[pio-coredir-env-link]: https://docs.platformio.org/en/latest/envvars.html#envvar-PLATFORMIO_CORE_DIR
[pio-coredir-link]: https://docs.platformio.org/en/latest/projectconf/sections/platformio/options/directory/core_dir.html#projectconf-pio-core-dir
[pio-debug-link]: https://docs.platformio.org/en/latest/plus/debugging.html
[pio-globallib-env-link]: https://docs.platformio.org/en/latest/envvars.html#envvar-PLATFORMIO_GLOBALLIB_DIR
[pio-globallib-link]: https://docs.platformio.org/en/latest/projectconf/sections/platformio/options/directory/globallib_dir.html#projectconf-pio-globallib-dir
[pio-packagesdir-link]: https://docs.platformio.org/en/latest/projectconf/sections/platformio/options/directory/packages_dir.html#projectconf-pio-packages-dir
[pio-pkg-g-link]: https://docs.platformio.org/en/stable/core/userguide/pkg/cmd_install.html#cmdoption-pio-pkg-install-g
[pio-platformsdir-link]: https://docs.platformio.org/en/latest/projectconf/sections/platformio/options/directory/platforms_dir.html#projectconf-pio-platforms-dir
[pip-cache-link]: https://pip.pypa.io/en/stable/topics/caching/#pip-cache-dir
[python-link]: https://hub.docker.com/_/python
[tz-link]: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
[uv-link]: https://docs.astral.sh/uv/
[vscode-python-debug-link]: https://code.visualstudio.com/docs/python/debugging
[workflow-status-shield]: https://img.shields.io/github/actions/workflow/status/ptr727/ESPHome-NonRoot/publish-release.yml?event=schedule&logo=github&label=Workflow%20Status
