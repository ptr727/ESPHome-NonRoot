#!/bin/bash
set -e

echo "Launching dashboard..."
exec esphome dashboard /config
