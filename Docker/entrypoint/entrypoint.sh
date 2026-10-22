#!/bin/bash
set -e

# Default command from Dockerfile is entrypoint
if [ "$1" = 'entrypoint' ]; then

    # Create cache subdirectories
    # shellcheck disable=SC1091 # Sourced from beside this script at run time, which a static check cannot follow.
    source "${BASH_SOURCE%/*}/cache.sh"

    # Launch dashboard
    # shellcheck disable=SC1091 # Sourced from beside this script at run time, which a static check cannot follow.
    source "${BASH_SOURCE%/*}/dashboard.sh"

else
    # Run passed command
    exec "$@"
fi
