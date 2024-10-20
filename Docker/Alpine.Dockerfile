# Description: ESPHome docker container that supports non-root operation.
# Based on: python:3.12-alpine
# Platforms: linux/amd64, linux/arm64
# Tag: ptr727/esphome-nonroot:latest

# TODO: ESPHome install fails on Python 3.13, pin to 3.12

# Get compressed image size from manifest:
# docker manifest inspect -v ptr727/esphome-nonroot:latest | jq '.[] | select(.Descriptor.platform.architecture=="amd64") | [.OCIManifest.layers[].size] | add' | numfmt --to=iec
# Get uncompressed size, requires downloading:
# docker pull ptr727/esphome-nonroot:latest
# docker image inspect --format json ptr727/esphome-nonroot:latest | jq '.[] | select(.Architecture=="amd64") | [.Size] | add' | numfmt --to=iec

# Docker build debugging:
# --progress=plain
# --no-cache

# Test image in shell:
# docker run -it --rm --pull always --name Testing python:3.12-alpine /bin/sh
# docker run -it --rm --pull always --name Testing ptr727/esphome-nonroot:latest /bin/bash

# Build Dockerfile
# docker buildx create --name "esphome" --use
# docker buildx build --platform linux/amd64,linux/arm64 --tag testing:latest --file ./Docker/Alpine.Dockerfile ./Docker

# Test linux/amd64 target
# docker buildx build --load --platform linux/amd64 --tag testing:latest --file ./Docker/Alpine.Dockerfile ./Docker
# docker run -it --rm --name Testing testing:latest /bin/bash
# docker run -it --rm --name Testing --publish 6052:6052 testing:latest
# docker exec -it Testing /bin/bash

# Cleanup unused Docker resources:
# docker image prune --all --force
# docker volume prune --all --force
# docker network prune --force

# Builder
FROM python:3.12-alpine AS builder

# Environment
ENV \
    # No python bytecode generation
    PYTHONDONTWRITEBYTECODE=1 \
    # Don't buffer python stream output
    PYTHONUNBUFFERED=1

# Install
RUN \
    # Update repos and upgrade
    apk update && apk upgrade \
    # Install dependencies
    && apk add --no-cache \
        build-base \
        gcompat \
        python3-dev

# Builder
WORKDIR /builder

# Build wheel archives for setuptools and esphome with optional display components
RUN pip wheel --no-cache-dir --progress-bar off --wheel-dir /builder/wheels setuptools esphome[displays]

# Final
FROM python:3.12-alpine

# Label
ARG \
    LABEL_VERSION="1.0.0.0" \
    ESPHOME_VERSION="1.0.0.0"
LABEL name="ESPHome" \
    version=${LABEL_VERSION} \
    esphome_version=${ESPHOME_VERSION} \
    description="ESPHome docker container that supports non-root operation" \
    maintainer="Pieter Viljoen <ptr727@users.noreply.github.com>"

# TODO: Keep in sync with cache.sh
# Environment
ENV \
    # No python bytecode generation
    PYTHONDONTWRITEBYTECODE=1 \
    # Don't buffer python stream output
    PYTHONUNBUFFERED=1 \
    # Set default timezone to UTC
    TZ=Etc/UTC \
    # PlatformIO disable progress bars, default is "false"
    PLATFORMIO_DISABLE_PROGRESSBAR=true \
    # PlatformIO "core_dir" option, default is "~/.platformio"
    PLATFORMIO_CORE_DIR=/cache/pio \
    # ESPHome "build_path" option, default is "/config/.esphome/build/[project]"
    ESPHOME_BUILD_PATH=/cache/build \
    # ESPHome "data_dir" option, default is "/config/.esphome"
    ESPHOME_DATA_DIR=/cache/data \
    # Set pip cache directory, default is "~/.cache/pip"
    PIP_CACHE_DIR=/cache/pip \
    # Set shell home / ~ directory, default is "/home/[username]"
    HOME=/cache/home \
    # Set temp directory, default is "/tmp"
    TMPDIR=/cache/tmp \
    TEMP=/cache/tmp \
    TMP=/cache/tmp

# Install
RUN \
    # Update repos and upgrade
    apk update && apk upgrade \
    # Install dependencies
    && apk add --no-cache \
        bash \
        build-base \
        curl \
        gcompat \
        git \
    # Avoid git error when directory owners don't match
    && git config --system --add safe.directory '*'

# Environment
ENV \
    # Set locale to en_US.UTF-8, C.UTF-8 is in theory ASCII only
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Copy wheels from builder
COPY --from=builder /builder/wheels /wheels

# Install all packages from wheels archives
RUN pip install --no-cache --no-index --find-links /wheels /wheels/* \
    # Cleanup
    && rm -rf /home \
    && rm -rf /root \
    && rm -rf /tmp \
    && rm -rf /wheels

# Dashboard runs on TCP port 6052
EXPOSE 6052

# Config volume for project files
VOLUME /config

# Cache volume, subdirectories are created in entrypoint.sh
VOLUME /cache

# Healthcheck ping the dashboard
HEALTHCHECK CMD curl --fail http://localhost:6052/version -A "HealthCheck" || exit 1

# Default entrypoint command will run dashboard
WORKDIR /config
COPY ./entrypoint /entrypoint
RUN chmod +x /entrypoint/*.sh
ENTRYPOINT ["/entrypoint/entrypoint.sh"]
CMD ["entrypoint"]
