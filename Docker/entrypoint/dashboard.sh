#!/bin/bash
set -e

# Version history auto-commits /config YAML to git, unsigned and under a foreign identity, and the default is on.
# The store is RAM-canonical with a debounced write, so the setting must be seeded before the dashboard starts.
# https://github.com/esphome/device-builder/blob/main/README.md#version-history
python3 - "/config/.device-builder-preferences.json" "${ESPHOME_VERSION_HISTORY:-false}" <<'PYTHON' || echo "Warning: could not run the seeding script, version_history_enabled in /config/.device-builder-preferences.json stays at the upstream default" >&2
import json
import os
import sys

path = sys.argv[1]
want = sys.argv[2].strip().lower() in ("1", "true", "yes", "on")


def warn(message):
    print(f"Warning: {message}", file=sys.stderr)


try:
    with open(path) as handle:
        prefs = json.load(handle)
    if not isinstance(prefs, dict):
        raise ValueError("preferences payload is not a JSON object")
except FileNotFoundError:
    prefs = {}
except Exception as error:
    warn(f"leaving {path} untouched, version history stays at the upstream default: {error}")
    raise SystemExit(0)

if prefs.get("version_history_enabled") is want:
    raise SystemExit(0)

prefs["version_history_enabled"] = want
tmp = f"{path}.entrypoint.tmp"
try:
    # Create at 0600 rather than chmod after the fact: the file is never briefly
    # world-readable, and a filesystem that cannot honor the mode still gets the
    # setting applied instead of failing the whole write.
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as handle:
        json.dump(prefs, handle, indent=2)
    os.replace(tmp, path)
except Exception as error:
    warn(f"could not write {path}, version history stays at the upstream default: {error}")
    try:
        os.remove(tmp)
    except OSError:
        pass
    raise SystemExit(0)
print(f"Set version_history_enabled={want} in {path}")
PYTHON

echo "Launching device-builder dashboard..."
exec esphome-device-builder /config
