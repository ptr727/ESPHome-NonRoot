#!/bin/bash
set -e

# TODO: Keep in sync with Dockerfile
# Create /cache subdirectories
# /cache/pio for $PLATFORMIO_CORE_DIR
# /cache/build for $ESPHOME_BUILD_PATH
# /cache/data for $ESPHOME_DATA_DIR
# /cache/pip for $PIP_CACHE_DIR
# /cache/home for $HOME
# /cache/tmp for $TMPDIR
mkdir -p /cache/pio /cache/build /cache/data /cache/pip /cache/home /cache/tmp

# Clear temporary files
rm -rf /tmp
rm -rf /cache/tmp/{*,.*}

# Prune PIO files
pio system prune --force
