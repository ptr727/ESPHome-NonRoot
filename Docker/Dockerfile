# check=skip=CopyIgnoredFile

# Description: ESPHome docker container that supports non-root operation.
# Based on: python:3.13-slim
# Platforms: linux/amd64, linux/arm64
# Tag: ptr727/esphome-nonroot:latest

# ESPHome Dockerfile: https://github.com/esphome/esphome/blob/dev/docker/Dockerfile

# Test image in shell:
# docker run -it --rm --pull always --name Testing python:slim /bin/bash
# docker run -it --rm --pull always --name Testing ptr727/esphome-nonroot:latest /bin/bash

# Build Dockerfile
# docker buildx create --name "esphome" --use
# docker buildx build --platform linux/amd64,linux/arm64 --tag esphome:testing --file ./Docker/Dockerfile ./Docker

# Test linux/amd64 target
# docker buildx build --load --platform linux/amd64 --tag esphome:testing --file ./Docker/Dockerfile ./Docker
# docker run -it --rm --name Testing esphome:testing /bin/bash
# docker run -it --rm --name Testing --publish 6052:6052 esphome:testing
# docker exec -it Testing /bin/bash

# Builder
FROM python:3.13-slim AS builder

# Prevent EULA and confirmation prompts in installers
ARG DEBIAN_FRONTEND=noninteractive

# Environment
ENV \
    # No python bytecode generation
    PYTHONDONTWRITEBYTECODE=1 \
    # Don't buffer python stream output
    PYTHONUNBUFFERED=1

# Install
RUN \
    # Update repos and upgrade
    apt update && apt upgrade -y \
    # Install dependencies
    && apt install -y --no-install-recommends \
        build-essential \
        python3-dev \
    # Cleanup
    && apt autoremove -y \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Builder
WORKDIR /builder

# Optional version pins via build-args; each pins its package independently
# (empty = latest). The pipeline always passes both.
ARG ESPHOME_VERSION=""
ARG DEVICE_BUILDER_VERSION=""

# Build a self-contained virtual environment with uv. The slim final stage
# copies it whole, so build tools never reach the final image. Installs the
# ESPHome compiler (with display components) plus the device-builder dashboard.
RUN pip install --no-cache-dir uv \
    && uv venv /opt/venv \
    && uv pip install --python /opt/venv/bin/python --no-cache \
        setuptools \
        "esphome[displays]${ESPHOME_VERSION:+==$ESPHOME_VERSION}" \
        "esphome-device-builder${DEVICE_BUILDER_VERSION:+==$DEVICE_BUILDER_VERSION}"

# Final
FROM python:3.13-slim

# Label
ARG \
    LABEL_VERSION="1.0.0.0" \
    ESPHOME_VERSION="1.0.0.0" \
    DEVICE_BUILDER_VERSION="1.0.0.0"
LABEL name="ESPHome" \
    version=${LABEL_VERSION} \
    esphome_version=${ESPHOME_VERSION} \
    device_builder_version=${DEVICE_BUILDER_VERSION} \
    description="ESPHome docker container that supports non-root operation" \
    maintainer="Pieter Viljoen <ptr727@users.noreply.github.com>"

# Prevent EULA and confirmation prompts in installers
ARG DEBIAN_FRONTEND=noninteractive

# Environment
ENV \
    # No python bytecode generation
    PYTHONDONTWRITEBYTECODE=1 \
    # Don't buffer python stream output
    PYTHONUNBUFFERED=1 \
    # Set default timezone to UTC
    TZ=Etc/UTC

# Install
RUN \
    # Update repos and upgrade
    apt update && apt upgrade -y \
    # Install dependencies
    && apt install -y --no-install-recommends \
        curl \
        git \
        locales \
        tzdata \
    # Generate locale
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    # Avoid git error when directory owners don't match
    && git config --system --add safe.directory '*' \
    # Cleanup
    && apt autoremove -y \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Environment
ENV \
    # Set locale to en_US.UTF-8, C.UTF-8 is in theory ASCII only
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Copy the virtual environment from the builder and put it on PATH
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Remove default home directories and prepare writable runtime directories
RUN rm -rf /home /root \
    # Make sure there is a /tmp and /cache directory with full access for any user
    && mkdir -p /tmp /cache \
    && chmod 0777 /tmp /cache

# Environment
ENV \
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
    TMPDIR=/tmp \
    TEMP=/tmp \
    TMP=/tmp

# Dashboard runs on TCP port 6052
EXPOSE 6052

# Config volume for project files
VOLUME /config

# Cache volume, subdirectories are created in entrypoint.sh
VOLUME /cache

# Healthcheck ping the dashboard
HEALTHCHECK --start-period=30s CMD curl --fail http://localhost:6052/version -A "HealthCheck" || exit 1

# Default entrypoint command will run dashboard
WORKDIR /config
COPY --chmod=755 ./entrypoint /entrypoint
ENTRYPOINT ["/entrypoint/entrypoint.sh"]
CMD ["entrypoint"]
