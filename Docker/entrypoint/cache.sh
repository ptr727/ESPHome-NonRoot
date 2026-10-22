#!/bin/bash
# Resets the container's scratch state before a start: it creates the /cache subdirectories, empties /tmp, and prunes the PlatformIO cache.
# It runs on every start because a reused /cache volume can predate a subdirectory a later image added.
set -Eeuo pipefail

usage() {
    cat <<'EOF'
Usage: cache.sh [-h | --help]

Create the /cache subdirectories the image environment points at, clear /tmp, and prune the PlatformIO cache.
entrypoint.sh runs it before the dashboard. Run it first when a command passed to the image runs in place of the dashboard.

  -h, --help  Print this help and exit.
EOF
}

if (($# > 0)); then
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "cache.sh: unknown argument '$1', see cache.sh --help" >&2
        exit 2
        ;;
    esac
fi

# TODO: Keep in sync with Dockerfile

# Create /cache subdirectories
# /cache/pio for $PLATFORMIO_CORE_DIR
# /cache/build for $ESPHOME_BUILD_PATH
# /cache/data for $ESPHOME_DATA_DIR
# /cache/pip for $PIP_CACHE_DIR
# /cache/home for $HOME
# /tmp for $TMPDIR
echo "Creating cache directories..."
mkdir -p /cache/pio /cache/build /cache/data /cache/pip /cache/home

# Clear temporary files
echo "Clearing temporary files..."
mkdir -p /tmp
find /tmp -mindepth 1 -delete

# Prune PIO cache files only, preserve downloaded packages
echo "Pruning PIO cache..."
pio system prune --cache --force
