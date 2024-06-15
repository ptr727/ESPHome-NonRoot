#!/bin/bash
set -e

# Run with verbose logging if ESPHOME_VERBOSE is set
if [[ -v ESPHOME_VERBOSE ]]; then
    exec esphome --verbose dashboard /config
else
    exec esphome dashboard /config
fi
