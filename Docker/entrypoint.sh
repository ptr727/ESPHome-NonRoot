#!/bin/bash
set -e

# Default command is esphome
if [ "$1" = 'esphome' ]; then

    # Create /cache subdirectories
    # TODO: pip and home should not get used if all settings are correct and honored
    # /cache/pio for $PLATFORMIO_CORE_DIR
    # /cache/build for $ESPHOME_BUILD_PATH
    # /cache/data for $ESPHOME_DATA_DIR
    # /cache/pip for $PIP_CACHE_DIR
    # /cache/home for $HOME
    mkdir -p /cache/pio /cache/build /cache/data /cache/pip /cache/home

    # Run with verbose logging if ESPHOME_VERBOSE is set
    if [[ -v ESPHOME_VERBOSE ]]; then
        exec esphome --verbose dashboard /config
    else
        exec esphome dashboard /config
    fi

fi

# Run passed command
exec "$@"
