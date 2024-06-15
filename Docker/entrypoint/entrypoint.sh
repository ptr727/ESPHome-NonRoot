#!/bin/bash
set -e

# Default command from Dockerfile is entrypoint
if [ "$1" = 'entrypoint' ]; then

    # Create cache subdirectories
    source ${BASH_SOURCE%/*}/cache.sh

    # Launch dashboard
    source ${BASH_SOURCE%/*}/dashboard.sh

else
    # Run passed command
    exec "$@"
fi
