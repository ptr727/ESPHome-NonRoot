#!/bin/bash
set -e

echo "Launching device-builder dashboard..."
exec esphome-device-builder /config
