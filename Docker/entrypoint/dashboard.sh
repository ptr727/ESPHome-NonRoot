#!/bin/bash
set -e

# Device Builder's version history feature auto-commits every YAML change under
# /config to git: unsigned, authored "ESPHome Device Builder
# <device-builder@esphome.io>", hooks skipped. Upstream defaults it on and
# offers no env override, and /config is usually a bind mount that may be the
# user's own git repository. Seed the preference before the dashboard starts.
# Upstream: https://github.com/esphome/device-builder/issues/2193
python3 - "/config/.device-builder-preferences.json" "${ESPHOME_VERSION_HISTORY:-false}" <<'PYTHON' || echo "Warning: could not seed version_history_enabled"
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
    with open(tmp, "w") as handle:
        json.dump(prefs, handle, indent=2)
    os.chmod(tmp, 0o600)
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
