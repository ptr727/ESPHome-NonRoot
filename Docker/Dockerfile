# Description: ESPHome docker container that supports non-root operation.
# Based on: python:slim
# Platforms: linux/amd64, linux/arm64
# Tag: ptr727/esphome-nonroot:latest

# Docker build debugging:
# --progress=plain
# --no-cache

# Test image in shell:
# docker run -it --rm --pull always --name Testing python:slim /bin/bash
# docker run -it --rm --pull always --name Testing ptr727/esphome-nonroot:latest /bin/bash
# export DEBIAN_FRONTEND=noninteractive
# apt upate && apt upgrade -y

# Build Dockerfile
# docker buildx create --name "esphome" --use
# docker buildx build --platform linux/amd64,linux/arm64 --tag testing:latest ./Docker

# Test linux/amd64 target
# docker buildx build --load --platform linux/amd64 --tag testing:latest ./Docker
# docker run -it --rm --name Testing testing:latest /bin/bash
# docker run -it --rm --name Testing --publish 6052:6052 testing:latest
# docker exec -it Testing /bin/bash

# Builder
FROM python:slim AS builder

# Environment
ENV \
    # No python bytecode generation
    PYTHONDONTWRITEBYTECODE=1 \
    # Don't buffer python stream output
    PYTHONUNBUFFERED=1 \
    # Prevent EULA and confirmation prompts in installers
    DEBIAN_FRONTEND=noninteractive

# Install
RUN \
    # Update repos and upgrade
    apt update && apt-get upgrade -y \
    # Install dependencies
    && apt install -y --no-install-recommends \
        build-essential \
        curl \
        git \
        python3-dev \
        wget \
    # Cleanup
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Builder
WORKDIR /builder

# Build wheel archives
RUN \
    pip install --no-cache --upgrade pip \
    && pip wheel --no-cache-dir --progress-bar off --wheel-dir /builder/wheels esphome[displays]

# Final
FROM python:slim

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
    # Prevent EULA and confirmation prompts in installers
    DEBIAN_FRONTEND=noninteractive \
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
    apt-get update && apt-get upgrade -y \
    # Install dependencies
    && apt-get install -y --no-install-recommends \
        curl \
        git \
        locales \
        locales-all \
        tzdata \
    # Generate locale
    && locale-gen --no-purge en_US en_US.UTF-8 \
    # Avoid git error when directory owners don't match
    && git config --system --add safe.directory '*' \
    # Cleanup
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Environment
ENV \
    # Set locale to en_US.UTF-8, C.UTF-8 is in theory ASCII only
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Copy wheels from builder
COPY --from=builder /builder/wheels /wheels

# Install all packages from wheels archives
RUN pip install --no-cache --upgrade pip \
    && pip install --no-cache --no-index --find-links /wheels /wheels/* \
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
ENTRYPOINT ["/entrypoint/entrypoint.sh"]
CMD ["entrypoint"]
